import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tictactoe/src/ads/ads_controller.dart';
import 'package:tictactoe/src/rps/initiative_picker.dart';
import 'package:tictactoe/src/style/dialog/dialog.dart';

import '../audio/sounds.dart';
import '../player_progress/player_progress.dart';
import '../style/delayed_appear.dart';
import '../style/palette.dart';
import '../style/responsive_screen.dart';
import '../style/rough/button.dart';

// For GameMode (enum) — move this import if you placed GameMode elsewhere
import '../game_internals/board_state.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  GameMode _mode = GameMode.vsAI; // default
  bool _rpsInitiative = true; // default: RPS ON for Vs AI

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();

    return Scaffold(
      backgroundColor: palette.backgroundLevelSelection,
      body: ResponsiveScreen(
        squarishMainArea: Column(
          children: [
            const SizedBox(height: 50),
            DelayedAppear(
              ms: ScreenDelays.first,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Center(
                  child: Text(
                    'Select level',
                    style: TextStyle(
                      fontFamily: 'Permanent Marker',
                      fontSize: 30,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ===== Mode toggle (Vs AI / Pass & Play) =====
            DelayedAppear(
              ms: ScreenDelays.second,
              child: SegmentedButton<GameMode>(
                segments: const [
                  ButtonSegment(
                    value: GameMode.vsAI,
                    label: Text('Vs AI'),
                    icon: Icon(Icons.smart_toy),
                  ),
                  ButtonSegment(
                    value: GameMode.localPvP,
                    label: Text('Vs Player'),
                    icon: Icon(Icons.people_outline),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) {
                  setState(() => _mode = s.first);
                },
              ),
            ),
            const SizedBox(height: 12),

            if (_mode == GameMode.vsAI) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12), // LevelSelectionScreen
                  const Text('Style :'),
                  TextButton.icon(
                    label: Text(
                      _rpsInitiative ? '✊📄✂ Rock Paper Scissor' : '▶️ Classic',
                      style: const TextStyle(
                          fontFamily: 'Permanent Marker', fontSize: 16),
                    ),
                    onPressed: () async {
                      final picked = await showInitiativeBottomSheet(context,
                          initialRps: _rpsInitiative);
                      if (picked != null) {
                        setState(() => _rpsInitiative =
                            picked); // <-- triggers reactive label update
                      }
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 50),

            // ===== Grid of numbers =====
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Column(
                    children: [
                      for (var y = 0; y < 3; y++)
                        Expanded(
                          child: Row(
                            children: [
                              for (var x = 0; x < 3; x++)
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: _LevelButton(y * 3 + x + 1,
                                      mode: _mode,
                                      rpsInitiative: _rpsInitiative),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // ===== Bottom "Back" button =====
        rectangularMenuArea: DelayedAppear(
          ms: ScreenDelays.fourth,
          child: RoughButton(
            onTap: () {
              GoRouter.of(context).pop();
            },
            textColor: palette.ink,
            child: const Text('Back'),
          ),
        ),
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  final int number;
  final GameMode mode;
  final bool rpsInitiative;

  const _LevelButton(this.number,
      {required this.mode, required this.rpsInitiative});

  @override
  Widget build(BuildContext context) {
    final playerProgress = context.watch<PlayerProgress>();
    final palette = context.watch<Palette>();
    final bool isPvP = mode == GameMode.localPvP;

    /// Level is either one that the player has already bested, or one above.
    // In PvP: every level is available, no ads, no locks.
    final bool available =
        isPvP ? true : playerProgress.highestLevelReached + 1 >= number;

    /// Allow skipping one level via ad.
    // In PvP: never show "watch ad to skip".
    final bool availableWithSkip = isPvP
        ? false
        : (!available && playerProgress.highestLevelReached + 2 >= number);

    return DelayedAppear(
      ms: ScreenDelays.second + (number - 1) * 70,
      child: RoughButton(
        onTap: () async {
          final controller = context.read<AdsController?>();

          if (available) {
            GoRouter.of(context).push(
              '/play/session/$number',
              extra: {'mode': mode, 'rps': rpsInitiative},
            );
          } else if (availableWithSkip) {
            // Confirm before showing ad to attempt the level
            final ok = await showConfirmProceedDialog(
              context,
              title: 'Watch Ads?',
              message: 'Do you want to watch an ad to attempt Level $number?',
              confirmText: 'Watch Ads',
              cancelText: 'Cancel',
              icon: Icons.ondemand_video,
            );
            if (ok) {
              controller?.loadInterstitialAd(onClose: () {
                GoRouter.of(context).push(
                  '/play/session/$number',
                  extra: {'mode': mode, 'rps': rpsInitiative},
                );
              });
            }
          } else {
            // Locked — friendly info dialog
            await showConfirmProceedDialog(
              context,
              title: 'Locked',
              message: 'Beat earlier levels to unlock Level $number.',
              confirmText: 'OK',
              cancelText: 'Close',
              icon: Icons.lock,
            );
          }
        },
        soundEffect: SfxType.erase,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/images/$number.png',
                  semanticLabel: 'Level $number',
                  fit: BoxFit.cover,
                  color: available
                      ? palette.redPen
                      : availableWithSkip
                          ? Color.alphaBlend(
                              palette.redPen.withValues(alpha: 0.6),
                              palette.ink)
                          : palette.ink,
                ),
              ),
              // Lock icon (only if not available)
              if (!isPvP && !available && !availableWithSkip)
                Positioned(
                  bottom: 4,
                  child: Icon(
                    Icons.lock,
                    size: 28,
                    color: palette.ink,
                  ),
                ),
              // Watch Ads pill (only if availableWithSkip)
              if (!isPvP && availableWithSkip)
                Positioned(
                  bottom: 4,
                  child: _buildWatchAdPill(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Small "AD" badge under skippable levels
Widget _buildWatchAdPill({
  String text = 'AD',
  Color fill = const Color(0xFFFFC107), // amber
  Color border = const Color(0xFFFF9F00), // deeper orange border
  Color textColor = const Color(0xFF3E2723),
  double fontSize = 10,
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
    vertical: 2,
    horizontal: 4,
  ),
  double radius = 8,
}) {
  final badge = Container(
    padding: padding,
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: 2),
      boxShadow: [
        BoxShadow(
          color: border.withValues(alpha: 0.45),
          blurRadius: 10,
          spreadRadius: 1.5,
        ),
      ],
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Permanent Marker',
        fontSize: fontSize,
        color: textColor,
        height: 1.0,
      ),
    ),
  );

  return Semantics(label: text, readOnly: true, child: badge);
}
