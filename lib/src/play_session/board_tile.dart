import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game_internals/board_state.dart';
import '../game_internals/tile.dart';
import '../style/piece_palette.dart'; // <-- the InheritedWidget

class BoardTile extends StatelessWidget {
  const BoardTile(this.tile, {super.key});
  final Tile tile;

  @override
  Widget build(BuildContext context) {
    // 1) Read exact bits we need from BoardState, with fine-grained rebuilds
    final side = context.select<BoardState, Side>((s) => s.whoIsAt(tile));
    final isLocked = context.select<BoardState, bool>((s) => s.isLocked);
    final canTake = context.select<BoardState, bool>((s) => s.canTake(tile));

    // 2) Map Side -> piece widget (coins/icons)
    Widget piece;
    try {
      piece = switch (side) {
        Side.x => PiecePalette.of(context).playerPiece(context),
        Side.o => PiecePalette.of(context).aiPiece(context),
        _ => const SizedBox.shrink(),
      };
    } catch (_) {
      // Fallback if PiecePalette wasn’t provided (dev-safety)
      piece = switch (side) {
        Side.x => const Icon(Icons.close),
        Side.o => const Icon(Icons.radio_button_unchecked),
        _ => const SizedBox.shrink(),
      };
    }

    // 3) Size nicely within the cell + animate on change
    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            constraints.biggest.shortestSide * 0.65; // coin size % of cell
        final side = context.select<BoardState, Side>((s) => s.whoIsAt(tile));
        final label = 'Cell (${tile.x + 1}, ${tile.y + 1})';
        final value = switch (side) {
          Side.x => 'Player coin',
          Side.o => 'Opponent coin',
          Side.none => 'Empty',
        };
        final canTap = !isLocked && canTake;

        return Semantics(
          label: label,
          value: value,
          button: canTap,
          enabled: canTap,
          onTapHint: canTap ? 'Place your coin' : null,
          child: InkResponse(
            onTap: (!isLocked && canTake)
                ? () => context.read<BoardState>().take(tile)
                : null,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (w, anim) => ScaleTransition(
                  scale:
                      CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  child: w,
                ),
                child: SizedBox(
                  key: ValueKey(side), // animate only when side changes
                  width: size,
                  height: size,
                  child: FittedBox(
                    child:
                        PiecePalette.maybeOf(context)?.forSide(context, side) ??
                            (side == Side.x
                                ? const Icon(Icons.close)
                                : side == Side.o
                                    ? const Icon(Icons.radio_button_unchecked)
                                    : const SizedBox.shrink()),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
