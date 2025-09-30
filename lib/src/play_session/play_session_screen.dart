import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart' hide Level;
import 'package:provider/provider.dart';
import 'package:tictactoe/src/ads/banner_ad_widget.dart';
import 'package:tictactoe/src/play_session/taunt_manager.dart';
import 'package:tictactoe/src/style/snack_bar.dart';

import '../ai/ai_opponent.dart';
import '../audio/audio_controller.dart';
import '../audio/sounds.dart';
import '../game_internals/board_state.dart';
import '../games_services/games_services.dart';
import '../games_services/score.dart';
import '../level_selection/levels.dart';
import '../player_progress/player_progress.dart';
import '../settings/custom_name_dialog.dart'; // you already have this
import '../settings/settings.dart';
import '../style/confetti.dart';
import '../style/delayed_appear.dart';
import '../style/palette.dart';
import 'game_board.dart';
import 'hint_snackbar.dart';

class PlaySessionScreen extends StatefulWidget {
  final GameLevel level;

  const PlaySessionScreen(this.level, {super.key});

  @override
  State<PlaySessionScreen> createState() => _PlaySessionScreenState();
}

class _PlaySessionScreenState extends State<PlaySessionScreen> {
  static final _log = Logger('PlaySessionScreen');
  final TauntManager _taunts = TauntManager();

  static const _celebrationDuration = Duration(milliseconds: 2000);
  static const _preCelebrationDuration = Duration(milliseconds: 500);

  final StreamController<void> _resetHint = StreamController.broadcast();

  bool _duringCelebration = false;
  late DateTime _startOfPlay;
  late final AiOpponent opponent;

  // 👇 captured once under provider so listeners don’t climb the tree
  late GameMode _modeForSession;

  void _onDraw() {
    if (!mounted) return;
    final audio = context.read<AudioController>();
    audio.playSfx(SfxType.buttonTap);
    _resetHint.add(null);
    showSnackBar("It's a draw - try again !");
  }

  // 👇 small helper to edit second player name (Local PvP)
  Future<void> _editSecondPlayerName(
      BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final palette = context.read<Palette>();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Second player name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(palette.redPen),
            ),
            onPressed: () {
              final v = controller.text.trim().isEmpty
                  ? 'Friend'
                  : controller.text.trim();
              context.read<SettingsController>().player2Name.value = v;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final palette = context.watch<Palette>();

    // read mode from route
    final extra = GoRouterState.of(context).extra;
    final GameMode selectedMode = (extra is Map && extra['mode'] is GameMode)
        ? extra['mode'] as GameMode
        : GameMode.vsAI;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BoardState>(
          create: (context) {
            final state = BoardState.clean(
              widget.level.setting,
              opponent,
              mode: selectedMode,
            );

            Future.delayed(const Duration(milliseconds: 500)).then((_) {
              if (!mounted) return;
              state.initialize();
            });

            // ⚠️ capture the mode only; do NOT read provider later inside listeners
            _modeForSession = state.mode;

            // it’s okay to wire here since we captured mode
            state.playerWon.addListener(_playerWon);
            state.aiOpponentWon.addListener(_aiOpponentWon);
            state.draw.addListener(_onDraw);

            return state;
          },
        ),
      ],

      // Use builder so this context is below the provider
      builder: (context, _) {
        // for opponent display: compute if PvP and the displayed name
        final boardState = context.watch<BoardState>();
        final bool isPvP = boardState.mode == GameMode.localPvP;
        final secondPlayerName = context.select<SettingsController, String>(
          (s) => s.player2Name.value,
        );
        final displayedOpponentName = isPvP ? secondPlayerName : opponent.name;

        return IgnorePointer(
          ignoring: _duringCelebration,
          child: Scaffold(
            backgroundColor: palette.backgroundPlaySession,
            bottomNavigationBar: const SafeArea(
              child: BannerAdWidget(fallbackSize: AdSize.banner),
            ),
            body: Stack(
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: settings.playerName,
                  builder: (context, playerName, child) {
                    return ValueListenableBuilder<String>(
                      valueListenable: settings.player2Name,
                      builder: (context, player2Name, _) {
                        final textStyle =
                            DefaultTextStyle.of(context).style.copyWith(
                                  fontFamily: 'Permanent Marker',
                                  fontSize: 24,
                                  color: palette.redPen,
                                );

                        return _ResponsivePlaySessionScreen(
                          levelWidget: _LevelChip(number: widget.level.number),
                          playerName: TextSpan(
                            text: playerName,
                            style: textStyle,
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => showCustomNameDialog(context,
                                  isSecondPlayer: false),
                          ),
                          opponentName: TextSpan(
                            text: (_modeForSession == GameMode.localPvP)
                                ? context
                                    .watch<SettingsController>()
                                    .player2Name
                                    .value
                                : opponent.name,
                            style: textStyle,
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                if (_modeForSession == GameMode.localPvP) {
                                  showCustomNameDialog(context,
                                      isSecondPlayer: true); // 👈 edit P2 name
                                }
                              },
                          ),
                          mainBoardArea: Center(
                            child: DelayedAppear(
                              ms: ScreenDelays.fourth,
                              delayStateCreation: true,
                              onDelayFinished: () {
                                final audioController =
                                    context.read<AudioController>();
                                audioController.playSfx(SfxType.swishSwish);
                              },
                              child: Board(
                                key: const Key('main board'),
                                setting: widget.level.setting,
                              ),
                            ),
                          ),
                          backButtonArea: DelayedAppear(
                            ms: ScreenDelays.first,
                            child: InkResponse(
                              onTap: () {
                                final audioController =
                                    context.read<AudioController>();
                                audioController.playSfx(SfxType.buttonTap);
                                GoRouter.of(context).pop();
                              },
                              child: Tooltip(
                                message: 'Back',
                                child: Image.asset('assets/images/back.png'),
                              ),
                            ),
                          ),
                          settingsButtonArea: DelayedAppear(
                            ms: ScreenDelays.third,
                            child: InkResponse(
                              onTap: () {
                                final audioController =
                                    context.read<AudioController>();
                                audioController.playSfx(SfxType.buttonTap);
                                context.push('/settings');
                              },
                              child: Tooltip(
                                message: 'Settings',
                                child:
                                    Image.asset('assets/images/settings.png'),
                              ),
                            ),
                          ),
                          actionsArea: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Undo
                              InkResponse(
                                onTap: () {
                                  final audio = context.read<AudioController>();
                                  audio.playSfx(SfxType.buttonTap);
                                  final state = context.read<BoardState>();
                                  if (state.canUndo) state.undoFullTurn();
                                },
                                child: const Column(
                                  children: [
                                    Icon(Icons.undo,
                                        size: 32, color: Colors.black),
                                    SizedBox(height: 4),
                                    Text('Undo',
                                        style: TextStyle(
                                            fontFamily: 'Permanent Marker',
                                            fontSize: 14)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Restart
                              InkResponse(
                                onTap: () {
                                  final audio = context.read<AudioController>();
                                  audio.playSfx(SfxType.buttonTap);

                                  context.read<BoardState>().clearBoard();
                                  _startOfPlay = DateTime.now();

                                  Future.delayed(
                                          const Duration(milliseconds: 200))
                                      .then((_) {
                                    if (!mounted) return;
                                    context.read<BoardState>().initialize();
                                  });

                                  Future.delayed(
                                          const Duration(milliseconds: 1000))
                                      .then((_) {
                                    if (!mounted) return;
                                    showHintSnackbar(context);
                                  });
                                },
                                child: const Column(
                                  children: [
                                    Icon(Icons.refresh,
                                        size: 32, color: Colors.black),
                                    SizedBox(height: 4),
                                    Text('Restart',
                                        style: TextStyle(
                                            fontFamily: 'Permanent Marker',
                                            fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                SizedBox.expand(
                  child: Visibility(
                    visible: _duringCelebration,
                    child: const IgnorePointer(
                      child: Confetti(isStopped: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    opponent = widget.level.aiOpponentBuilder(widget.level.setting);
    _log.info('$opponent enters the fray');
    _startOfPlay = DateTime.now();
  }

  void _aiOpponentWon() {
    _resetHint.add(null);
    if (_modeForSession == GameMode.localPvP) {
      showSnackBar("O wins! 🏆");
      return;
    }
    final msg = _taunts.maybeTaunt(event: 'ai_win');
    if (!mounted) return;
    if (msg != null) showSnackBar(msg);
  }

  void _playerWon() async {
    if (_modeForSession == GameMode.localPvP) {
      showSnackBar("X wins! 🎉");
      return;
    }

    final score = Score(
      widget.level.number,
      widget.level.setting,
      widget.level.difficulty,
      DateTime.now().difference(_startOfPlay),
    );

    final playerProgress = context.read<PlayerProgress>();
    playerProgress.setLevelReached(widget.level.number);

    await Future<void>.delayed(_preCelebrationDuration);
    if (!mounted) return;

    setState(() => _duringCelebration = true);

    final audioController = context.read<AudioController>();
    audioController.playSfx(SfxType.congrats);

    final gamesServicesController = context.read<GamesServicesController?>();
    if (gamesServicesController != null) {
      if (widget.level.awardsAchievement) {
        gamesServicesController.awardAchievement(
          android: widget.level.achievementIdAndroid!,
          iOS: widget.level.achievementIdIOS!,
        );
      }
      gamesServicesController.submitLeaderboardScore(score);
    }

    await Future.delayed(_celebrationDuration);
    if (!mounted) return;
    GoRouter.of(context).go('/play/won', extra: {'score': score});
  }
}

class _ResponsivePlaySessionScreen extends StatelessWidget {
  final Widget mainBoardArea;
  final Widget backButtonArea;
  final Widget settingsButtonArea;
  final Widget actionsArea;

  final TextSpan playerName;
  final TextSpan opponentName;
  final Widget levelWidget;

  final double mainAreaProminence;

  const _ResponsivePlaySessionScreen({
    required this.mainBoardArea,
    required this.backButtonArea,
    required this.settingsButtonArea,
    required this.actionsArea,
    required this.playerName,
    required this.opponentName,
    required this.levelWidget,
    this.mainAreaProminence = 0.8,
  });

  Widget _buildVersusText(BuildContext context, TextAlign textAlign) {
    String versusText;
    switch (textAlign) {
      case TextAlign.start:
      case TextAlign.left:
      case TextAlign.right:
      case TextAlign.end:
        versusText = '\nversus\n';
        break;
      case TextAlign.center:
      case TextAlign.justify:
        versusText = ' versus ';
        break;
    }

    return DelayedAppear(
      ms: ScreenDelays.second,
      child: RichText(
        textAlign: textAlign,
        text: TextSpan(
          children: [
            playerName,
            TextSpan(
              text: versusText,
              style: DefaultTextStyle.of(context)
                  .style
                  .copyWith(fontFamily: 'Permanent Marker', fontSize: 18),
            ),
            opponentName,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final padding = EdgeInsets.all(size.shortestSide / 30);

        if (size.height >= size.width) {
          // Portrait
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: padding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 45, child: backButtonArea),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 15, right: 15, top: 5),
                          child: Column(
                            spacing: 6,
                            children: [
                              _buildVersusText(context, TextAlign.center),

                              // 👇 turn indicator (Local PvP only)
                              Selector<BoardState, (GameMode, Side)>(
                                selector: (_, s) => (s.mode, s.turn),
                                builder: (context, tuple, _) {
                                  final (mode, turn) = tuple;
                                  if (mode != GameMode.localPvP) {
                                    return const SizedBox.shrink();
                                  }
                                  final who = (turn == Side.x)
                                      ? "X's turn"
                                      : "O's turn";
                                  final palette = context.watch<Palette>();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      who,
                                      style: TextStyle(
                                        fontFamily: 'Permanent Marker',
                                        fontSize: 16,
                                        color: palette.ink,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              levelWidget,
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 45, child: settingsButtonArea),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: (mainAreaProminence * 100).round(),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  minimum: padding,
                  child: mainBoardArea,
                ),
              ),
              SafeArea(
                top: false,
                maintainBottomViewPadding: true,
                child: Padding(
                  padding: padding,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [actionsArea],
                  ),
                ),
              ),
            ],
          );
        } else {
          // Landscape
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: SafeArea(
                  right: false,
                  maintainBottomViewPadding: true,
                  child: Padding(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        backButtonArea,
                        _buildVersusText(context, TextAlign.start),
                        const SizedBox(height: 6),
                        levelWidget,
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: SafeArea(
                  left: false,
                  right: false,
                  maintainBottomViewPadding: true,
                  minimum: padding,
                  child: mainBoardArea,
                ),
              ),
              Expanded(
                flex: 3,
                child: SafeArea(
                  left: false,
                  maintainBottomViewPadding: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(padding: padding, child: settingsButtonArea),
                      const Spacer(),
                      Padding(padding: padding, child: actionsArea),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }
}

class _LevelChip extends StatelessWidget {
  final int number;
  const _LevelChip({required this.number});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: palette.backgroundPlaySession.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.ink, width: 1.5),
        boxShadow: const [
          BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black26)
        ],
      ),
      child: Text(
        'Level $number',
        style: TextStyle(
          fontFamily: 'Permanent Marker',
          fontSize: 18,
          color: palette.ink,
        ),
      ),
    );
  }
}
