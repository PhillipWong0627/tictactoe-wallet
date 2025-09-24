import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../audio/sounds.dart';
import '../player_progress/player_progress.dart';
import '../style/delayed_appear.dart';
import '../style/palette.dart';
import '../style/responsive_screen.dart';
import '../style/rough/button.dart';

class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({super.key});

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
                    style:
                        TextStyle(fontFamily: 'Permanent Marker', fontSize: 30),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50),
            // This is the grid of numbers.
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
                                    child: _LevelButton(y * 3 + x + 1),
                                  )
                              ],
                            ),
                          )
                      ],
                    )),
              ),
            ),
          ],
        ),
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

  const _LevelButton(this.number);

  @override
  Widget build(BuildContext context) {
    final playerProgress = context.watch<PlayerProgress>();
    final palette = context.watch<Palette>();

    /// Level is either one that the player has already bested, on one above.
    final available = playerProgress.highestLevelReached + 1 >= number;

    /// We allow the player to skip one level.
    final availableWithSkip = playerProgress.highestLevelReached + 2 >= number;

    return DelayedAppear(
      ms: ScreenDelays.second + (number - 1) * 70,
      child: RoughButton(
          onTap: availableWithSkip
              ? () => GoRouter.of(context).go('/play/session/$number')
              : null,
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
                if (!available && !availableWithSkip)
                  Positioned(
                    // right: 20,
                    bottom: 4, // place lock under the number
                    child: Icon(
                      Icons.lock,
                      size: 28,
                      color: palette.ink,
                    ),
                  ),
              ],
            ),
          )),
    );
  }
}
