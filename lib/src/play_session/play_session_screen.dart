import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart' hide Level;
import 'package:provider/provider.dart';
import 'package:tictactoe/gen/assets.gen.dart';
import 'package:tictactoe/src/ads/banner_ad_widget.dart';
import 'package:tictactoe/src/play_session/taunt_manager.dart';
import 'package:tictactoe/src/style/dialog/dialog.dart';
import 'package:tictactoe/src/style/snack_bar.dart';
import 'package:tictactoe/src/widget/ads/ad_gated_action.dart';
import 'package:tictactoe/src/widget/ads/watch_ad_badge.dart';

import '../ai/ai_opponent.dart';
import '../audio/audio_controller.dart';
import '../audio/sounds.dart';
import '../game_internals/board_state.dart';
import '../games_services/score.dart';
import '../level_selection/levels.dart';
import '../player_progress/player_progress.dart';
import '../settings/custom_name_dialog.dart';
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

  void _onDraw() {
    if (!mounted) return;

    // optional niceties:
    final audio = context.read<AudioController>();
    audio.playSfx(SfxType.buttonTap);

    _resetHint.add(null); // bump the Restart button
    showSnackBar("It's a draw - try again !");
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final palette = context.watch<Palette>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) {
            final state = BoardState.clean(
              widget.level.setting,
              opponent,
            );

            Future.delayed(const Duration(milliseconds: 500)).then((_) {
              if (!mounted) return;
              state.initialize();
            });

            state.playerWon.addListener(_playerWon);
            state.aiOpponentWon.addListener(_aiOpponentWon);
            state.draw.addListener(_onDraw);

            return state;
          },
        ),
      ],
      child: IgnorePointer(
        ignoring: _duringCelebration,
        child: Scaffold(
          backgroundColor: palette.backgroundPlaySession,
          bottomNavigationBar: SafeArea(
            child: BannerAdWidget(
              fallbackSize: AdSize.banner, // 320x50 if adaptive not available
            ),
          ),
          body: Stack(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: settings.playerName,
                builder: (context, playerName, child) {
                  final textStyle = DefaultTextStyle.of(context).style.copyWith(
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
                        ..onTap = () => showCustomNameDialog(context),
                    ),
                    opponentName: TextSpan(
                      text: opponent.name,
                      style: textStyle,
                      recognizer: TapGestureRecognizer()
                        // TODO: implement
                        //       (except maybe not, because in user testing,
                        //        nobody has ever touched this)
                        ..onTap = () => _log
                            .severe('Tapping opponent name NOT IMPLEMENTED'),
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
                          child: Assets.images.back.image(
                            fit: BoxFit.cover,
                          ),
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
                          context.push('/settings'); // open settings
                        },
                        child: Tooltip(
                          message: 'Settings',
                          child: Assets.images.settings.image(),
                        ),
                      ),
                    ),
                    actionsArea: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // UNDO (Watch Ads)
                        AdGatedAction(
                          enabled: context
                              .select<BoardState, bool>((s) => s.canUndo),
                          isAvailable: (ctx) =>
                              ctx.read<BoardState>().canUndo, // runtime guard
                          onUnavailable: () {
                            showSnackBar("There is no previous move.");
                          },

                          requireConfirm: true,
                          onConfirm: (ctx) => showConfirmProceedDialog(
                            ctx,
                            title: 'Watch Ad?',
                            message: 'Watch an ad to undo your last move.',
                            confirmText: 'Watch Ad',
                            cancelText: 'Cancel',
                            icon: Icons.undo,
                          ),
                          onAllowed: () {
                            final audio = context.read<AudioController>();
                            audio.playSfx(SfxType.buttonTap);
                            final state = context.read<BoardState>();
                            if (state.canUndo) state.undoFullTurn();
                          },
                          child: Column(
                            children: [
                              // Wrap the icon and badge together
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.undo,
                                      size: 32, color: Colors.black),

                                  // Position the badge bottom-right
                                  Positioned(
                                    right: -6, // tweak as needed
                                    bottom: -6, // tweak as needed
                                    child: const WatchAdBadge(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Undo',
                                style: TextStyle(
                                  fontFamily: 'Permanent Marker',
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 24),

                        // Restart button
                        InkResponse(
                          onTap: () {
                            final audio = context.read<AudioController>();
                            audio.playSfx(SfxType.buttonTap);

                            context.read<BoardState>().clearBoard();
                            _startOfPlay = DateTime.now();

                            Future.delayed(const Duration(milliseconds: 200))
                                .then((_) {
                              if (!mounted) return;
                              context.read<BoardState>().initialize();
                            });

                            Future.delayed(const Duration(milliseconds: 1000))
                                .then((_) {
                              if (!mounted) return;
                              showHintSnackbar(context);
                            });
                          },
                          child: Column(
                            children: const [
                              Icon(Icons.refresh,
                                  size: 32, color: Colors.black),
                              SizedBox(height: 4),
                              Text('Restart',
                                  style: TextStyle(
                                    fontFamily: 'Permanent Marker',
                                    fontSize: 14,
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),

                        // // (Future) Hint button placeholder
                        // InkResponse(
                        //   onTap: () {
                        //     final audio = context.read<AudioController>();
                        //     audio.playSfx(SfxType.buttonTap);
                        //     showHintSnackbar(
                        //         context); // already exists in your code
                        //   },
                        //   child: Column(
                        //     children: const [
                        //       Icon(Icons.lightbulb_outline,
                        //           size: 32, color: Colors.black),
                        //       SizedBox(height: 4),
                        //       Text('Hint',
                        //           style: TextStyle(
                        //             fontFamily: 'Permanent Marker',
                        //             fontSize: 14,
                        //           )),
                        //     ],
                        //   ),
                        // ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox.expand(
                child: Visibility(
                  visible: _duringCelebration,
                  child: IgnorePointer(
                    child: Confetti(
                      isStopped: !_duringCelebration,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    opponent = widget.level.aiOpponentBuilder(widget.level.setting);
    _log.info('$opponent enters the fray');

    _startOfPlay = DateTime.now();

    // Preload ad for the win screen.
  }

  void _aiOpponentWon() {
    // "Pop" the reset button to remind the player what to do next.
    _resetHint.add(null);
    // 👇 show a short taunt on AI victory
    final msg = _taunts.maybeTaunt(event: 'ai_win');
    if (!mounted) return;

    if (msg != null) {
      showSnackBar(msg);
    }
  }

  void _playerWon() async {
    final score = Score(
      widget.level.number,
      widget.level.setting,
      widget.level.difficulty,
      DateTime.now().difference(_startOfPlay),
    );

    final playerProgress = context.read<PlayerProgress>();
    playerProgress.setLevelReached(widget.level.number);

    // Let the player see the game just after winning for a bit.
    await Future<void>.delayed(_preCelebrationDuration);
    if (!mounted) return;

    setState(() {
      _duringCelebration = true;
    });

    final audioController = context.read<AudioController>();
    audioController.playSfx(SfxType.congrats);

    /// Give the player some time to see the celebration animation.
    await Future.delayed(_celebrationDuration);
    if (!mounted) return;

    GoRouter.of(context).go('/play/won', extra: {'score': score});
  }
}

class _ResponsivePlaySessionScreen extends StatelessWidget {
  /// This is the "hero" of the screen. It's more or less square, and will
  /// be placed in the visual "center" of the screen.
  final Widget mainBoardArea;

  final Widget backButtonArea;

  final Widget settingsButtonArea;
  final Widget actionsArea;

  // final Widget restartButtonArea;
  // final Widget undoButtonArea;

  final TextSpan playerName;

  final TextSpan opponentName;

  // dedicated level widget slot
  final Widget levelWidget;

  /// How much bigger should the [mainBoardArea] be compared to the other
  /// elements.
  final double mainAreaProminence;

  const _ResponsivePlaySessionScreen({
    required this.mainBoardArea,
    required this.backButtonArea,
    required this.settingsButtonArea,
    required this.actionsArea, // 👈 instead of restart/undo separately

    // required this.restartButtonArea,
    // required this.undoButtonArea,

    required this.playerName,
    required this.opponentName,
    required this.levelWidget,

    // ignore: unused_element
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
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // This widget wants to fill the whole screen.
        final size = constraints.biggest;
        final padding = EdgeInsets.all(size.shortestSide / 30);

        if (size.height >= size.width) {
          // "Portrait" / "mobile" mode.
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
                      SizedBox(
                        width: 45,
                        child: backButtonArea,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 15,
                            right: 15,
                            top: 5,
                          ),
                          child: Column(
                            children: [
                              _buildVersusText(context, TextAlign.center),
                              const SizedBox(height: 6),
                              // 👉 level placed under names, never overlaps
                              levelWidget,
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 45,
                        child: settingsButtonArea,
                      ),
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
                    children: [
                      actionsArea, // 👈 contains Undo, Restart, future Hint
                    ],
                  ),
                ),
              ),
            ],
          );
        } else {
          // "Landscape" / "tablet" mode.
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
                        // 👉 level sits under the names on the left column
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
                      Padding(
                        padding: padding,
                        child: settingsButtonArea,
                      ),
                      const Spacer(),
                      Padding(
                        padding: padding,
                        child: actionsArea,
                      ),
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
          BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black26),
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
