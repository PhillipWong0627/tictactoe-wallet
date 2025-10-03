import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:tictactoe/src/app_lifecycle/app_lifecycle_observer.dart';

import 'firebase_options.dart';
import 'src/ads/ads_controller.dart';
import 'src/audio/audio_controller.dart';
import 'src/crashlytics/crashlytics.dart';
import 'src/games_services/score.dart';
import 'src/level_selection/level_selection_screen.dart';
import 'src/level_selection/levels.dart';
import 'src/main_menu/main_menu_screen.dart';
import 'src/play_session/play_session_screen.dart';
import 'src/player_progress/persistence/local_storage_player_progress_persistence.dart';
import 'src/player_progress/persistence/player_progress_persistence.dart';
import 'src/player_progress/player_progress.dart';
import 'src/settings/persistence/local_storage_settings_persistence.dart';
import 'src/settings/persistence/settings_persistence.dart';
import 'src/settings/settings.dart';
import 'src/settings/settings_screen.dart';
import 'src/style/ink_transition.dart';
import 'src/style/palette.dart';
import 'src/style/snack_bar.dart';
import 'src/win_game/win_game_screen.dart';

final Logger _log = Logger('main.dart');

Future<void> main() async {
  // 1) Make sure plugins, SystemChrome, etc. are safe to call.
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseCrashlytics? crashlytics;
  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      crashlytics = FirebaseCrashlytics.instance;
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint("Firebase couldn't be initialized: $e");
    }
  }

  if (kDebugMode) {
    // Log more when in debug mode.
    Logger.root.level = Level.FINE;
  }
  // Subscribe to log messages.
  Logger.root.onRecord.listen((record) {
    final message = '${record.level.name}: ${record.time}: '
        '${record.loggerName}: '
        '${record.message}';

    debugPrint(message);
    // Add the message to the rotating Crashlytics log.
    crashlytics?.log(message);

    if (record.level >= Level.SEVERE) {
      crashlytics?.recordError(message, filterStackTrace(StackTrace.current),
          fatal: true);
    }
  });

  _log.info('Going full screen');
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  AdsController? adsController;
  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    /// Prepare the google_mobile_ads plugin so that the first ad loads
    /// faster. This can be done later or with a delay if startup
    /// experience suffers.
    await MobileAds.instance.initialize();
    adsController = AdsController(MobileAds.instance)..initialize();
  }

  // GamesServicesController? gamesServicesController;
  // if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
  //   gamesServicesController = GamesServicesController()
  //     // Attempt to log the player in.
  //     ..initialize();
  // }

  runApp(
    MyApp(
      settingsPersistence: LocalStorageSettingsPersistence(),
      playerProgressPersistence: LocalStoragePlayerProgressPersistence(),
      adsController: adsController,
      // gamesServicesController: gamesServicesController,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.playerProgressPersistence,
    required this.settingsPersistence,
    required this.adsController,
  });

  final PlayerProgressPersistence playerProgressPersistence;
  final SettingsPersistence settingsPersistence;
  final AdsController? adsController;

  // Define Routes Here
  static final _router = GoRouter(
    routes: [
      GoRoute(
          path: '/',
          builder: (context, state) =>
              const MainMenuScreen(key: Key('main menu')),
          routes: [
            GoRoute(
                path: 'play',
                pageBuilder: (context, state) => buildTransition<void>(
                      child: const LevelSelectionScreen(
                          key: Key('level selection')),
                      color: context.watch<Palette>().backgroundLevelSelection,
                    ),
                routes: [
                  GoRoute(
                    path: 'session/:level',
                    pageBuilder: (context, state) {
                      final levelNumber =
                          int.parse(state.pathParameters['level']!);
                      final level = gameLevels
                          .singleWhere((e) => e.number == levelNumber);
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

  @override
  Widget build(BuildContext context) {
    return _LifecycleHost(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) {
              var progress = PlayerProgress(playerProgressPersistence);
              progress.getLatestFromStore();
              return progress;
            },
          ),
          // Provider<GamesServicesController?>.value(
          //     value: gamesServicesController),
          Provider<AdsController?>.value(value: adsController),
          Provider<SettingsController>(
            lazy: false,
            create: (context) => SettingsController(
              persistence: settingsPersistence,
            )..loadStateFromPersistence(),
          ),
          ProxyProvider2<SettingsController, ValueNotifier<AppLifecycleState>,
              AudioController>(
            // Ensures that the AudioController is created on startup,
            // and not "only when it's needed", as is default behavior.
            // This way, music starts immediately.
            lazy: false,
            create: (context) => AudioController()..initialize(),
            update: (context, settings, lifecycleNotifier, audio) {
              if (audio == null) throw ArgumentError.notNull();
              audio.attachSettings(settings);
              audio.attachLifecycleNotifier(lifecycleNotifier);
              return audio;
            },
            dispose: (context, audio) => audio.dispose(),
          ),
          Provider(
            create: (context) => Palette(),
          ),
        ],
        child: Builder(builder: (context) {
          final palette = context.watch<Palette>();

          return MaterialApp.router(
            title: 'Flutter Demo',
            theme: ThemeData.from(
              colorScheme: ColorScheme.fromSeed(
                seedColor: palette.darkPen,
                background: palette.backgroundMain,
              ),
              textTheme: TextTheme(
                bodyMedium: TextStyle(
                  color: palette.ink,
                ),
              ),
            ),
            routeInformationProvider: _router.routeInformationProvider,
            routeInformationParser: _router.routeInformationParser,
            routerDelegate: _router.routerDelegate,
            scaffoldMessengerKey: scaffoldMessengerKey,
          );
        }),
      ),
    );
  }
}

/// Hosts and provides a ValueNotifier<AppLifecycleState> to the tree,
/// so AudioController (and others) can react to lifecycle changes.
/// This wraps your new AppLifecycleObserver class/file.
class _LifecycleHost extends StatefulWidget {
  const _LifecycleHost({required this.child});
  final Widget child;

  @override
  State<_LifecycleHost> createState() => _LifecycleHostState();
}

class _LifecycleHostState extends State<_LifecycleHost> {
  // What AudioController expects via ProxyProvider2
  final ValueNotifier<AppLifecycleState> _lifecycle =
      ValueNotifier<AppLifecycleState>(AppLifecycleState.resumed);

  late final AppLifecycleObserver _observer;

  @override
  void initState() {
    super.initState();
    // Bridge: forward observer events into the ValueNotifier the app already uses
    _observer = AppLifecycleObserver(
      _Hooks(
        onState: (s) => _lifecycle.value = s,
      ),
    )..attach();
  }

  @override
  void dispose() {
    _observer.detach();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Expose the ValueNotifier to the subtree (for ProxyProvider2 → AudioController)
    return ListenableProvider<ValueNotifier<AppLifecycleState>>.value(
      value: _lifecycle,
      child: widget.child,
    );
  }
}

class _Hooks extends AppLifecycleHooks {
  _Hooks({required this.onState});
  final void Function(AppLifecycleState) onState;

  @override
  void onResume() => onState(AppLifecycleState.resumed);
  @override
  void onPause() => onState(AppLifecycleState.paused);
  @override
  void onInactive() => onState(AppLifecycleState.inactive);
  @override
  void onDetach() => onState(AppLifecycleState.detached);
}
