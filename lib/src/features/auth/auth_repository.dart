import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// アプリの認証状態の分類。
enum AppAuthStatus {
  /// セッションなし（未ログイン）
  unauthenticated,

  /// 匿名セッション（正式アカウントへの変換が必要）
  anonymous,

  /// メール未確認（セッションはあるが確認待ち）
  unconfirmed,

  /// 確認済み（通常利用可能）
  authenticated,
}

/// Supabase Auth をラップした認証サービス層。
///
/// 画面からはこのクラス経由で認証操作を行う。公開範囲やユーザー名の一意性など
/// サーバー側で強制すべき不変条件は Supabase の RLS / 関数 / トリガーに委ねる。
class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;
  String? get currentUserId => currentUser?.id;

  /// 認証状態の変化ストリーム（ルーターの再評価トリガーに使用）。
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// 現在の認証状態を分類して返す。
  AppAuthStatus get status {
    final user = currentUser;
    if (user == null) return AppAuthStatus.unauthenticated;
    if (user.isAnonymous) return AppAuthStatus.anonymous;
    if (user.emailConfirmedAt == null) return AppAuthStatus.unconfirmed;
    return AppAuthStatus.authenticated;
  }

  bool get isEmailConfirmed => currentUser?.emailConfirmedAt != null;

  /// 新規登録。メール確認が必須のため、成功してもセッションは作られない想定。
  /// username はメタデータに載せ、DBトリガー handle_new_user が users 行を作成する。
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final available = await isUsernameAvailable(username);
    if (!available) {
      throw AuthException('このユーザー名は既に使われています');
    }
    await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'username': username.trim()},
    );
  }

  /// ログイン。
  Future<void> signIn({required String email, required String password}) async {
    await _supabase.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// ログアウト。
  Future<void> signOut() => _supabase.auth.signOut();

  /// メール確認の再送。
  Future<void> resendConfirmation(String email) async {
    await _supabase.auth.resend(type: OtpType.signup, email: email.trim());
  }

  /// セッションを再取得し、最新の確認状態を反映する。
  Future<void> refreshSession() async {
    await _supabase.auth.refreshSession();
  }

  /// 匿名アカウントを正式アカウントへ変換する（同じUIDを維持, 仕様7.4）。
  /// email+password を設定するとメール確認がトリガーされ、確認後に is_anonymous が解除される。
  Future<void> convertAnonymous({
    required String email,
    required String password,
    required String username,
  }) async {
    final available = await isUsernameAvailable(username);
    if (!available) {
      throw AuthException('このユーザー名は既に使われています');
    }
    await _supabase.auth.updateUser(
      UserAttributes(email: email.trim(), password: password),
    );
    // 既存 users 行の username を更新（RLSで本人のみ / UNIQUEで一意性担保）
    final uid = currentUserId;
    if (uid != null) {
      await _supabase.from('users').update({'username': username.trim()}).eq('id', uid);
    }
  }

  /// ユーザー名の可用性（大小無視）をサーバーに問い合わせる。
  Future<bool> isUsernameAvailable(String username) async {
    final res = await _supabase.rpc(
      'is_username_available',
      params: {'p_username': username.trim()},
    );
    return res == true;
  }

  /// アカウント削除。本人確認のため再認証し、Edge Function で Auth ユーザーを削除する。
  /// 個人データは users への ON DELETE CASCADE で一括削除される。
  /// NOTE: Edge Function 'delete-account'（service role）は後続チャンクで実装・デプロイ。
  Future<void> deleteAccount({required String password}) async {
    final email = currentUser?.email;
    if (email == null) {
      throw AuthException('メールアカウントではないため削除できません');
    }
    // 再認証（本人確認）
    await _supabase.auth.signInWithPassword(email: email, password: password);
    // service role での Auth ユーザー削除は Edge Function 経由（クライアントに鍵を置かない）
    await _supabase.functions.invoke('delete-account');
    await _supabase.auth.signOut();
  }
}
