import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../style/palette.dart';

int _currentHintIndex = 0;
int _lastHintIndex = -1;
final _rng = Random();

const List<String> hints = [
  'Start in the center if you can.',
  'Put X\'s close to each other.',
  'Try to put X\'s in places where they could be part of two different winning lines.',
  'If the opponent is in trouble, press the advantage.',
  'Always be making new opportunities.',
  'Don’t pursue lines that are already doomed (when there’s no place for a winning line there anymore).',
];

void showHintSnackbar(BuildContext context) {
  final palette = context.read<Palette>();

  // Pick a random hint but avoid repeating the last one
  if (hints.length > 1) {
    do {
      _currentHintIndex = _rng.nextInt(hints.length);
    } while (_currentHintIndex == _lastHintIndex);
  }
  _lastHintIndex = _currentHintIndex;
  final hint = hints[_currentHintIndex];

  // Subtle vibration
  HapticFeedback.lightImpact();

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  final chars = hint.characters.length;
  final durationMs = (chars * 55).clamp(2000, 5500);

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 30, left: 16, right: 16),
      elevation: 0,
      backgroundColor: Colors.transparent,
      duration: Duration(milliseconds: durationMs),
      padding: EdgeInsets.zero,
      dismissDirection: DismissDirection.horizontal,
      content: _HintSnackBarContent(
        hint: hint,
        palette: palette,
      ),
    ),
  );
}

class _HintSnackBarContent extends StatefulWidget {
  const _HintSnackBarContent({required this.hint, required this.palette});
  final String hint;
  final Palette palette;

  @override
  State<_HintSnackBarContent> createState() => _HintSnackBarContentState();
}

class _HintSnackBarContentState extends State<_HintSnackBarContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _typeProgress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _typeProgress = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return FadeTransition(
      opacity: _fade,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: ShapeDecoration(
          color: palette.backgroundLevelSelection.withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: palette.redPen.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          shadows: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tips_and_updates_rounded,
                color: palette.redPen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: _TypewriterText(
                prefix: 'Hint: ',
                text: widget.hint,
                prefixStyle: TextStyle(
                  fontFamily: 'Permanent Marker',
                  fontSize: 16,
                  color: palette.redPen,
                ),
                textStyle: TextStyle(
                  fontFamily: 'Permanent Marker',
                  fontSize: 16,
                  color: palette.ink,
                ),
                progress: _typeProgress,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypewriterText extends AnimatedWidget {
  const _TypewriterText({
    required this.prefix,
    required this.text,
    required this.prefixStyle,
    required this.textStyle,
    required Animation<double> progress,
  }) : super(listenable: progress);

  Animation<double> get progress => listenable as Animation<double>;
  final String prefix;
  final String text;
  final TextStyle prefixStyle;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final total = text.characters.length;
    final shown = (progress.value * total).clamp(0, total).round();
    final visible = text.characters.take(shown).toString();

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: prefix, style: prefixStyle),
          TextSpan(text: visible, style: textStyle),
        ],
      ),
    );
  }
}
