// lib/src/style/piece_palette.dart
import 'package:flutter/material.dart';
import 'package:tictactoe/src/game_internals/board_state.dart';

typedef PieceBuilder = Widget Function(BuildContext);

class PiecePalette extends InheritedWidget {
  const PiecePalette({
    super.key,
    required this.playerPiece,
    required this.aiPiece,
    required super.child,
  });

  final PieceBuilder playerPiece;
  final PieceBuilder aiPiece;

  static PiecePalette of(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<PiecePalette>();
    assert(p != null, 'PiecePalette not found above in the widget tree.');
    return p!;
  }

  /// Lenient lookup (returns null if missing)
  static PiecePalette? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PiecePalette>();
  }

  /// Convenience: map Side -> piece
  Widget forSide(BuildContext context, Side side) {
    switch (side) {
      case Side.x:
        return playerPiece(context);
      case Side.o:
        return aiPiece(context);
      case Side.none:
        return const SizedBox.shrink();
    }
  }

  @override
  bool updateShouldNotify(PiecePalette old) =>
      playerPiece != old.playerPiece || aiPiece != old.aiPiece;
}
