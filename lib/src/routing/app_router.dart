import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'scaffold_with_nav_bar.dart';
import '../models/experience_card_model.dart';
import '../models/deck_model.dart';

// Screens
import '../features/explore/explore_screen.dart';
import '../features/explore/card_detail_screen.dart';
import '../features/my_cards/my_cards_screen.dart';
import '../features/my_cards/deck_playback_screen.dart';
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
      // Top Level Routes (Full Screen)
      GoRoute(
        path: '/card_detail',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          if (extra is! ExperienceCardModel) {
            return const NoTransitionPage(
              child: Scaffold(
                body: Center(child: Text('Unable to open card details.')),
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
    ],
  );
});
