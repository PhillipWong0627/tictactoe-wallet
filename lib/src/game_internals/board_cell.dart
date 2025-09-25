// lib/src/play_session/game_board.dart  (or: lib/src/board/board_cell.dart)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game_internals/board_state.dart';
import '../game_internals/tile.dart';
import '../style/piece_palette.dart'; // the InheritedWidget we wrapped in PlaySessionScreen

class BoardCell extends StatelessWidget {
  const BoardCell({super.key, required this.tile, this.size = 40});
  final Tile tile;
  final double size;

  @override
  Widget build(BuildContext context) {
    // ✅ This is exactly your snippet:
    final side = context.select<BoardState, Side>((s) => s.whoIsAt(tile));
    final piece = switch (side) {
      Side.x => PiecePalette.of(context).playerPiece(context),
      Side.o => PiecePalette.of(context).aiPiece(context),
      _ => const SizedBox.shrink(),
    };

    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: SizedBox(
          key: ValueKey(side),
          width: size,
          height: size,
          child: FittedBox(child: piece),
        ),
      ),
    );
  }
}
