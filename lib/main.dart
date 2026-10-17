import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/routing/app_router.dart';
import 'src/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Supabase Init
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 認証ゲートはルーター側で行う（未ログイン→ログイン / 匿名→引き継ぎ / 未確認→確認待ち）。
  // 旧実装の「起動時に無条件で匿名ログイン」は廃止。既存の匿名セッションは保持され、
  // 引き継ぎ画面から同一UIDのまま正式アカウントへ移行できる（仕様7.4）。

  runApp(
    const ProviderScope(
      child: ShuffloApp(),
    ),
  );
}

class ShuffloApp extends ConsumerWidget {
  const ShuffloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Shufflo',
      theme: AppTheme.darkTheme,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
