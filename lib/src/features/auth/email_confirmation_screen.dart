import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_repository.dart';

/// メール確認待ち画面（仕様7.2）。
/// 登録直後（セッションなし）と、未確認セッションがある場合の両方を扱う。
class EmailConfirmationScreen extends ConsumerStatefulWidget {
  const EmailConfirmationScreen({super.key, this.email});

  /// 登録フローから渡されるメールアドレス（セッションがない場合の表示用）。
  final String? email;

  @override
  ConsumerState<EmailConfirmationScreen> createState() => _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends ConsumerState<EmailConfirmationScreen> {
  bool _working = false;

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  String? get _email => widget.email ?? _auth.currentUser?.email;

  Future<void> _resend() async {
    final email = _email;
    if (email == null) return;
    setState(() => _working = true);
    try {
      await _auth.resendConfirmation(email);
      _snack('確認メールを再送しました。');
    } catch (_) {
      _snack('再送に失敗しました。しばらくしてからお試しください。');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _working = true);
    try {
      await _auth.refreshSession();
      if (_auth.isEmailConfirmed) {
        // 確認済みになったらルーターが本編へ遷移させる
        _snack('確認できました！');
      } else {
        _snack('まだ確認が完了していません。メールのリンクを開いてください。');
      }
    } catch (_) {
      _snack('状態の更新に失敗しました。');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = _auth.currentSession != null;
    final email = _email;
    return Scaffold(
      appBar: AppBar(title: const Text('メール確認')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_unread_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    '確認メールを送りました',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    email == null
                        ? 'メール内のリンクを開いて、アカウントを有効化してください。'
                        : '$email 宛にメールを送りました。\nメール内のリンクを開いて、アカウントを有効化してください。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (hasSession)
                    FilledButton(
                      onPressed: _working ? null : _refresh,
                      child: _working
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('確認した（再読込）'),
                    )
                  else
                    FilledButton(
                      onPressed: _working ? null : () => context.go('/login'),
                      child: const Text('ログインへ進む'),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _working ? null : _resend,
                    child: const Text('確認メールを再送'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _working
                        ? null
                        : () async {
                            await _auth.signOut();
                            if (context.mounted) context.go('/login');
                          },
                    child: const Text('別のアカウントでやり直す'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
