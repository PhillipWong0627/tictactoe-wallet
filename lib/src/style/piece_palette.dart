// lib/src/style/piece_palette.dart
import 'package:flutter/material.dart';

class PiecePalette extends InheritedWidget {
  const PiecePalette({
    super.key,
    required this.playerPiece,
    required this.aiPiece,
    required super.child,
  });

  /// Icons (or any widget) for each side
  final Widget Function(BuildContext) playerPiece;
  final Widget Function(BuildContext) aiPiece;

  static PiecePalette of(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<PiecePalette>();
    assert(p != null, 'PiecePalette not found in context');
    return p!;
  }

  @override
  bool updateShouldNotify(PiecePalette old) =>
      playerPiece != old.playerPiece || aiPiece != old.aiPiece;
}
