import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../main_menu/main_menu_screen.dart';
import '../level_selection/level_selection_screen.dart';
import '../play_session/play_session_screen.dart';
import '../settings/settings_screen.dart';
import '../win_game/win_game_screen.dart';
import '../style/ink_transition.dart';
import '../style/palette.dart';
import '../games_services/score.dart';
import '../level_selection/levels.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
        path: '/',
        builder: (context, state) =>
            const MainMenuScreen(key: Key('main menu')),
        routes: [
          GoRoute(
              path: 'play',
              pageBuilder: (context, state) => buildTransition<void>(
                    child:
                        const LevelSelectionScreen(key: Key('level selection')),
                    color: context.watch<Palette>().backgroundLevelSelection,
                  ),
              routes: [
                GoRoute(
                  path: 'session/:level',
                  pageBuilder: (context, state) {
                    final levelNumber =
                        int.parse(state.pathParameters['level']!);
                    final level =
                        gameLevels.singleWhere((e) => e.number == levelNumber);
                    return buildTransition<void>(
                      child: PlaySessionScreen(
                        level,
                        key: const Key('play session'),
                      ),
                      color: context.watch<Palette>().backgroundPlaySession,
                      flipHorizontally: true,
                    );
                  },
                ),
                GoRoute(
                  path: 'won',
                  pageBuilder: (context, state) {
                    final map = state.extra! as Map<String, dynamic>;
                    final score = map['score'] as Score;

                    return buildTransition<void>(
                      child: WinGameScreen(
                        score: score,
                        key: const Key('win game'),
                      ),
                      color: context.watch<Palette>().backgroundPlaySession,
                      flipHorizontally: true,
                    );
                  },
                )
              ]),
          GoRoute(
            path: 'settings',
            pageBuilder: (context, state) {
              return buildTransition<void>(
                color: context.watch<Palette>().backgroundPlaySession,
                flipHorizontally: true,
                child: const SettingsScreen(key: Key('settings')),
              );
            },
          ),
        ]),
  ],
);
