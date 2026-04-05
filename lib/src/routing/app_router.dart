import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'scaffold_with_nav_bar.dart';

// Placeholder screens
import '../features/explore/explore_screen.dart';
import '../features/my_cards/my_cards_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/post/post_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _exploreNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'explore');
final _postNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'post');
final _myCardsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'my_cards');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/explore',
    navigatorKey: _rootNavigatorKey,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _exploreNavigatorKey,
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ExploreScreen(),
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
            navigatorKey: _myCardsNavigatorKey,
            routes: [
              GoRoute(
                path: '/my_cards',
                builder: (context, state) => const MyCardsScreen(),
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
    ],
  );
});
