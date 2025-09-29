import 'package:tictactoe/src/game_internals/tile.dart';
import 'package:tictactoe/src/game_internals/board_state.dart';

class PlacedMove {
  final Tile tile;
  final Side side; // Side.x or Side.o
  const PlacedMove(this.tile, this.side);
}
