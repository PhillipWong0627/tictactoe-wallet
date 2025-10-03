import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tictactoe/src/style/palette.dart';
import 'rps.dart';

class RpsInlineBar extends StatefulWidget {
  final ValueChanged<RpsWinner> onResult;
  final bool active; // Eable/disable interaction
  final String? idleText; // Status when inactive

  const RpsInlineBar({
    super.key,
    required this.onResult,
    required this.active,
    this.idleText,
  });

  @override
  State<RpsInlineBar> createState() => _RpsInlineBarState();
}

class _RpsInlineBarState extends State<RpsInlineBar> {
  final _rng = Random();
  RpsChoice? _player;
  RpsChoice? _ai;
  RpsWinner? _winner;
  bool _choicesEnabled = true;

  // Reset internal state whenever a new round starts (key changes)
  @override
  void didUpdateWidget(covariant RpsInlineBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When becoming active (new round), reset visuals
    if (widget.active && !oldWidget.active) {
      _player = null;
      _ai = null;
      _winner = null;
      _choicesEnabled = true;
    }
  }

  void _pick(RpsChoice c) async {
    if (!widget.active) return; // ⬅Ignore if not in RPS phase
    if (!_choicesEnabled) return;
    setState(() => _choicesEnabled = false);

    final aiPick = RpsChoice.values[_rng.nextInt(3)];
    final win = rpsResult(c, aiPick);
    setState(() {
      _player = c;
      _ai = aiPick;
      _winner = win;
    });

    if (win == RpsWinner.player || win == RpsWinner.ai) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      widget.onResult(win);
    } else {
      setState(() => _choicesEnabled = true); // tie → allow again
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.read<Palette>();
    final inactive = !widget.active;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: palette.backgroundLevelSelection.withValues(alpha: 0.95),
      child: Opacity(
        opacity: inactive ? 0.55 : 1.0,
        child: IgnorePointer(
          ignoring: inactive,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.ink, width: 1.2),
            ),
            child: Column(
              spacing: 6,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.active
                      ? (_winner == null
                          ? 'RPS: decide who moves'
                          : _winner == RpsWinner.tie
                              ? 'Tie — again?'
                              : _winner == RpsWinner.player
                                  ? 'You win!'
                                  : 'AI wins!')
                      : (widget.idleText ?? 'Waiting for next round…'),
                  style: TextStyle(
                    fontFamily: 'Permanent Marker',
                    fontSize: 20,
                    color: palette.ink,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    _chip(context, 'Rock', Icons.handshake,
                        selected: _player == RpsChoice.rock,
                        onTap: () => _pick(RpsChoice.rock)),
                    _chip(context, 'Paper', Icons.back_hand_outlined,
                        selected: _player == RpsChoice.paper,
                        onTap: () => _pick(RpsChoice.paper)),
                    _chip(context, 'Scissors', Icons.content_cut,
                        selected: _player == RpsChoice.scissors,
                        onTap: () => _pick(RpsChoice.scissors)),
                  ],
                ),
                if (_ai != null) ...[
                  Text(
                    'AI: ${_ai!.name}',
                    style: TextStyle(
                      fontFamily: 'Permanent Marker',
                      fontSize: 12,
                      color: palette.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, IconData icon,
      {required bool selected, required VoidCallback onTap}) {
    final palette = context.read<Palette>();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? palette.redPen.withValues(alpha: 0.12)
              : palette.backgroundPlaySession.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? palette.redPen : palette.ink,
              width: selected ? 2 : 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 70, color: palette.ink),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontFamily: 'Permanent Marker',
                  fontSize: 12,
                  color: palette.ink,
                )),
          ],
        ),
      ),
    );
  }
}
