// lib/src/rps/rps_overlay.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tictactoe/src/style/palette.dart';
import 'rps.dart';

Future<RpsWinner> showRpsOverlay(BuildContext context) async {
  return await showGeneralDialog<RpsWinner>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'RPS',
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (ctx, anim1, anim2) => const _RpsOverlay(),
        transitionBuilder: (ctx, anim, _, child) {
          return AnimatedOpacity(
            opacity: anim.value,
            duration: const Duration(milliseconds: 220),
            child: child,
          );
        },
      ) ??
      RpsWinner.tie;
}

class _RpsOverlay extends StatefulWidget {
  const _RpsOverlay();

  @override
  State<_RpsOverlay> createState() => _RpsOverlayState();
}

class _RpsOverlayState extends State<_RpsOverlay>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  RpsChoice? _player;
  RpsChoice? _ai;
  RpsWinner? _winner;

  // 🔒 stop reroll spam
  bool _choicesEnabled = true;

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _pick(RpsChoice c) async {
    if (!_choicesEnabled) return; // ignore spam
    setState(() => _choicesEnabled = false); // lock immediately

    final aiPick = RpsChoice.values[_rng.nextInt(3)];
    final win = rpsResult(c, aiPick);
    setState(() {
      _player = c;
      _ai = aiPick;
      _winner = win;
    });

    // On win/lose → auto confirm after short beat
    if (win == RpsWinner.player || win == RpsWinner.ai) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      Navigator.of(context).maybePop(win);
    } else {
      // Tie → allow retry
      setState(() => _choicesEnabled = true);
    }
  }

  void _retryOnTie() {
    if (_winner != RpsWinner.tie) return; // only on tie
    setState(() {
      _player = null;
      _ai = null;
      _winner = null;
      _choicesEnabled = true; // re-enable taps
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.read<Palette>();

    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.backgroundLevelSelection.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.ink, width: 1.8),
                boxShadow: const [
                  BoxShadow(
                      blurRadius: 18,
                      offset: Offset(0, 8),
                      color: Colors.black26),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 14,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black26, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/rps/RPS.jpg',
                            width: 35,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Rock · Paper · Scissors',
                        style: TextStyle(
                          fontFamily: 'Permanent Marker',
                          fontSize: 20,
                          color: palette.ink,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _winner == null
                        ? 'Pick one to decide who moves!'
                        : switch (_winner!) {
                            RpsWinner.player => 'You win — your move!',
                            RpsWinner.ai => 'AI wins — it will move!',
                            RpsWinner.tie => 'Tie — pick again!',
                          },
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Permanent Marker',
                      fontSize: 25,
                      color: palette.ink,
                    ),
                  ),

                  // Choices row (disabled after first tap unless tie)
                  IgnorePointer(
                    ignoring: !_choicesEnabled,
                    child: Opacity(
                      opacity: _choicesEnabled ? 1 : 0.6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ChoiceCard(
                            label: 'Rock',
                            icon: Icons.handshake,
                            selected: _player == RpsChoice.rock,
                            onTap: () => _pick(RpsChoice.rock),
                          ),
                          _ChoiceCard(
                            label: 'Paper',
                            icon: Icons.back_hand_outlined,
                            selected: _player == RpsChoice.paper,
                            onTap: () => _pick(RpsChoice.paper),
                          ),
                          _ChoiceCard(
                            label: 'Scissors',
                            icon: Icons.content_cut,
                            selected: _player == RpsChoice.scissors,
                            onTap: () => _pick(RpsChoice.scissors),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // AI reveal / status
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: _ai == null
                        ? ScaleTransition(
                            scale: Tween<double>(begin: .98, end: 1.02)
                                .animate(CurvedAnimation(
                              parent: _pulse,
                              curve: Curves.easeInOut,
                            )),
                            child: Text(
                              'Waiting for your pick…',
                              style: TextStyle(
                                fontFamily: 'Permanent Marker',
                                fontSize: 14,
                                color: palette.ink.withValues(alpha: 0.8),
                              ),
                            ),
                          )
                        : Text(
                            'AI chose: ${_ai!.name}',
                            style: TextStyle(
                              fontFamily: 'Permanent Marker',
                              fontSize: 15,
                              color: palette.ink,
                            ),
                          ),
                  ),

                  // Actions: only show "Again" on tie; no Confirm (auto-close on win/lose)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_winner == RpsWinner.tie)
                        TextButton(
                          onPressed: _retryOnTie,
                          child: Text(
                            'Again',
                            style: TextStyle(
                              fontFamily: 'Permanent Marker',
                              color: palette.ink,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).maybePop(RpsWinner.tie),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Permanent Marker',
                            color: palette.ink,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.read<Palette>();
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? palette.redPen.withValues(alpha: 0.16)
              : palette.backgroundPlaySession.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? palette.redPen : palette.ink,
            width: selected ? 2.4 : 1.6,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.redPen.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: palette.ink, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Permanent Marker',
                fontSize: 14,
                color: palette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
