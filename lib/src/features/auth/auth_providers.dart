import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

/// 認証状態の変化ストリーム（必要に応じて画面から購読）。
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// GoRouter の refreshListenable に渡す Listenable。
/// Supabase の認証状態が変わるたびに notifyListeners し、ルーターの redirect を再評価させる。
final routerRefreshProvider = Provider<GoRouterRefreshStream>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final notifier = GoRouterRefreshStream(repo.authStateChanges);
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Stream を ChangeNotifier に橋渡しする薄いアダプタ。
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
