import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'scaffold_with_nav_bar.dart';
import '../models/experience_card_model.dart';
import '../models/deck_model.dart';

import '../features/explore/explore_screen.dart';
import '../features/explore/card_detail_screen.dart';
import '../features/my_cards/my_cards_screen.dart';
import '../features/my_cards/deck_playback_screen.dart';
import '../features/my_cards/create_deck_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/post/post_screen.dart';
import '../features/auth/auth_repository.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/email_confirmation_screen.dart';
import '../features/auth/welcome_convert_screen.dart';
import '../features/auth/account_screen.dart';
import '../features/social/user_search_screen.dart';
import '../features/social/friends_list_screen.dart';
import '../features/social/friend_profile_screen.dart';
import '../features/social/notifications_screen.dart';
import '../features/coupons/coupons_screen.dart';
import '../features/visit/visit_verification_screen.dart';
import '../models/visit_models.dart';

/// 認証状態に応じて許可される公開ルート（未ログインでも到達可能）。
const _publicRoutes = {'/login', '/signup', '/verify-email'};

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _mapNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'map');
final _myCardsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'my_cards');
final _postNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'post');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: '/map',
    navigatorKey: _rootNavigatorKey,
    refreshListenable: refresh,
    // 認証ゲート: 状態に応じて適切な画面へ誘導する。
    // 公開範囲やデータアクセスの最終的な強制はサーバー側(RLS)で行う。
    redirect: (context, state) {
      final status = auth.status;
      final loc = state.matchedLocation;
      switch (status) {
        case AppAuthStatus.unauthenticated:
          return _publicRoutes.contains(loc) ? null : '/login';
        case AppAuthStatus.anonymous:
          return loc == '/welcome' ? null : '/welcome';
        case AppAuthStatus.unconfirmed:
          return loc == '/verify-email' ? null : '/verify-email';
        case AppAuthStatus.authenticated:
          if (_publicRoutes.contains(loc) || loc == '/welcome') return '/map';
          return null;
      }
    },
    routes: [
      // --- 認証系（ボトムナビの外, フルスクリーン） ---
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            EmailConfirmationScreen(email: state.extra as String?),
      ),
      GoRoute(
        path: '/welcome',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WelcomeConvertScreen(),
      ),
      GoRoute(
        path: '/account',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AccountScreen(),
      ),
      // --- 友達・通知（フルスクリーン） ---
      GoRoute(
        path: '/user_search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UserSearchScreen(),
      ),
      GoRoute(
        path: '/friends',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FriendsListScreen(),
      ),
      GoRoute(
        path: '/user',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => FriendProfileScreen(userId: state.extra as String),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/coupons',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CouponsScreen(),
      ),
      // --- 訪問確認フロー ---
      GoRoute(
        path: '/visit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra as Map<String, String>;
          return VisitVerificationScreen(
            storeId: args['storeId']!,
            storeName: args['storeName']!,
          );
        },
      ),
      GoRoute(
        path: '/create_card',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PostScreen(visitContext: state.extra as VisitContext),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _mapNavigatorKey,
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _myCardsNavigatorKey,
            routes: [
              GoRoute(
                path: '/my_cards',
                builder: (context, state) => const MyCardsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _postNavigatorKey,
            routes: [
              GoRoute(
                path: '/post',
                builder: (context, state) => const PostScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Top Level Routes (Full Screen)
      GoRoute(
        path: '/card_detail',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is! ExperienceCardModel) {
            return const NoTransitionPage(
              child: Scaffold(
                body: Center(
                  child: Text('Unable to open card details.'),
                ),
              ),
            );
          }
          return NoTransitionPage(child: CardDetailScreen(model: extra));
        },
      ),
      GoRoute(
        path: '/deck_playback',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! DeckModel) {
            return Scaffold(
              appBar: AppBar(title: const Text('Invalid route')),
              body: const Center(
                child: Text('Unable to open deck playback.'),
              ),
            );
          }
          return DeckPlaybackScreen(deck: extra);
        },
      ),
      GoRoute(
        path: '/create_deck',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateDeckScreen(),
      ),
    ],
  );
});
