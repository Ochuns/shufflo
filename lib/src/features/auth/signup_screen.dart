import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';
import 'auth_form_fields.dart';

/// 新規登録画面。メールアドレス・パスワード・一意なユーザー名を登録する。
/// 登録後はメール確認待ち画面へ遷移する（メール確認必須, 仕様7.2）。
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            username: _usernameCtrl.text,
          );
      if (!mounted) return;
      context.go('/verify-email', extra: _emailCtrl.text.trim());
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('登録に失敗しました。通信環境を確認してください。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント作成')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthUsernameField(controller: _usernameCtrl, enabled: !_loading),
                    const SizedBox(height: 16),
                    AuthEmailField(controller: _emailCtrl, enabled: !_loading),
                    const SizedBox(height: 16),
                    AuthPasswordField(controller: _passwordCtrl, enabled: !_loading),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('登録する'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'アバターと自己紹介は登録後に設定できます。',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _loading ? null : () => context.go('/login'),
                      child: const Text('すでにアカウントをお持ちの方はこちら'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
