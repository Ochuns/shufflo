import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';
import 'auth_form_fields.dart';

/// 既存の匿名アカウントを正式アカウントへ変換する画面（仕様7.4）。
/// 同じユーザーIDを維持したまま email/password/username を設定するため、
/// これまでのカード・デッキ等のデータがそのまま引き継がれる。
class WelcomeConvertScreen extends ConsumerStatefulWidget {
  const WelcomeConvertScreen({super.key});

  @override
  ConsumerState<WelcomeConvertScreen> createState() => _WelcomeConvertScreenState();
}

class _WelcomeConvertScreenState extends ConsumerState<WelcomeConvertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  AuthRepository get _auth => ref.read(authRepositoryProvider);

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
      await _auth.convertAnonymous(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        username: _usernameCtrl.text,
      );
      if (mounted) setState(() => _submitted = true);
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('登録に失敗しました。通信環境を確認してください。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      await _auth.refreshSession();
      if (!_auth.isEmailConfirmed) {
        _snack('まだ確認が完了していません。メールのリンクを開いてください。');
      }
      // 確認済みになればルーターが本編へ遷移させる
    } catch (_) {
      _snack('状態の更新に失敗しました。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウントを引き継ぐ')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _submitted ? _buildConfirmView(context) : _buildFormView(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('アカウントを作成しましょう',
              style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            '今の端末で集めたカードやデッキは、そのまま引き継がれます。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
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
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('この内容で登録する'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_unread_outlined, size: 64),
        const SizedBox(height: 16),
        Text('確認メールを送りました',
            style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          '${_emailCtrl.text.trim()} 宛のメール内リンクを開くと、引き継ぎが完了します。',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _loading ? null : _refresh,
          child: _loading
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('確認した（再読込）'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _loading
              ? null
              : () async {
                  try {
                    await _auth.resendConfirmation(_emailCtrl.text);
                    _snack('確認メールを再送しました。');
                  } catch (_) {
                    _snack('再送に失敗しました。');
                  }
                },
          child: const Text('確認メールを再送'),
        ),
      ],
    );
  }
}
