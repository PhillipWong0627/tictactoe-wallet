import 'package:flutter/material.dart';

class WatchAdBadge extends StatelessWidget {
  final String text;
  final Color fill;
  final Color border;
  final Color textColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool semanticsOnly;

  const WatchAdBadge({
    super.key,
    this.text = 'ADs',
    this.fill = const Color(0xFFFFC107), // amber
    this.border = const Color(0xFFFF9F00), // deeper orange
    this.textColor = const Color(0xFF3E2723),
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
    this.radius = 8,
    this.semanticsOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: 0.45),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Permanent Marker',
          fontSize: fontSize,
          color: textColor,
          height: 1,
        ),
      ),
    );

    return semanticsOnly
        ? Semantics(label: text, readOnly: true, child: badge)
        : badge;
  }
}
