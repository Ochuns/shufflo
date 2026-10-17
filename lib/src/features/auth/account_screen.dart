import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

/// アカウント設定画面（ログアウト / 退会）。
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authRepositoryProvider);
    final email = auth.currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('アカウント設定')),
      body: SafeArea(
        child: ListView(
          children: [
            if (email != null)
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('メールアドレス'),
                subtitle: Text(email),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('ログアウト'),
              onTap: () async {
                await auth.signOut();
                // ルーターの redirect がログイン画面へ遷移させる
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('アカウントを削除', style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text('カード・デッキ・友達・クーポン等がすべて削除されます'),
              onTap: () => _showDeleteDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authRepositoryProvider);
    final passwordCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool working = false;
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> confirm() async {
              if (passwordCtrl.text.isEmpty) {
                setState(() => errorText = 'パスワードを入力してください');
                return;
              }
              setState(() {
                working = true;
                errorText = null;
              });
              try {
                await auth.deleteAccount(password: passwordCtrl.text);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                // 退会後は signOut 済み → ルーターがログイン画面へ
              } on AuthException catch (e) {
                setState(() {
                  working = false;
                  errorText = _jpDeleteError(e);
                });
              } catch (_) {
                setState(() {
                  working = false;
                  errorText = '削除に失敗しました。通信環境を確認してください。';
                });
              }
            }

            return AlertDialog(
              title: const Text('本当に削除しますか？'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'この操作は取り消せません。本人確認のためパスワードを入力してください。',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    enabled: !working,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: working ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: working ? null : confirm,
                  child: working
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('削除する'),
                ),
              ],
            );
          },
        );
      },
    );
    passwordCtrl.dispose();
  }
}

String _jpDeleteError(AuthException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('invalid login credentials')) {
    return 'パスワードが正しくありません。';
  }
  return e.message;
}
