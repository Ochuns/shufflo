import 'package:flutter/material.dart';

/// 認証フォームで共通利用する入力フィールド群とバリデータ。

String? validateEmail(String? v) {
  final value = (v ?? '').trim();
  if (value.isEmpty) return 'メールアドレスを入力してください';
  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!re.hasMatch(value)) return 'メールアドレスの形式が正しくありません';
  return null;
}

String? validatePassword(String? v) {
  final value = v ?? '';
  if (value.isEmpty) return 'パスワードを入力してください';
  if (value.length < 8) return 'パスワードは8文字以上にしてください';
  return null;
}

String? validateUsername(String? v) {
  final value = (v ?? '').trim();
  if (value.isEmpty) return 'ユーザー名を入力してください';
  if (value.length < 3) return 'ユーザー名は3文字以上にしてください';
  if (value.length > 20) return 'ユーザー名は20文字以内にしてください';
  if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(value)) {
    return '半角英数字とアンダースコアのみ使用できます';
  }
  return null;
}

class AuthEmailField extends StatelessWidget {
  const AuthEmailField({super.key, required this.controller, this.enabled = true});
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'メールアドレス',
        prefixIcon: Icon(Icons.mail_outline),
        border: OutlineInputBorder(),
      ),
      validator: validateEmail,
    );
  }
}

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.label = 'パスワード',
    this.textInputAction = TextInputAction.done,
  });
  final TextEditingController controller;
  final bool enabled;
  final String label;
  final TextInputAction textInputAction;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: validatePassword,
    );
  }
}

class AuthUsernameField extends StatelessWidget {
  const AuthUsernameField({super.key, required this.controller, this.enabled = true});
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'ユーザー名',
        helperText: '半角英数字と _ / 3〜20文字 / 重複不可',
        prefixIcon: Icon(Icons.person_outline),
        border: OutlineInputBorder(),
      ),
      validator: validateUsername,
    );
  }
}
