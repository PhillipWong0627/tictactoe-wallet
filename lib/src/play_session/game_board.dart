import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tictactoe/src/game_internals/board_state.dart';
import 'package:tictactoe/src/style/palette.dart';

import '../game_internals/board_setting.dart';
import '../game_internals/tile.dart';
import 'board_tile.dart';
import 'rough_grid.dart';

class Board extends StatefulWidget {
  final VoidCallback? onPlayerWon;

  const Board({super.key, required this.setting, this.onPlayerWon});

  final BoardSetting setting;

  @override
  State<Board> createState() => _BoardState();
}

class _BoardState extends State<Board> {
  @override
  Widget build(BuildContext context) {
    // Get the current winning line (null if no one has won yet)
    final winningLine = context.select<BoardState, List<Tile>?>(
      (s) => s.winningLine?.toList(growable: false),
    );
    // Pick a highlight color; feel free to swap to your palette.redPen
    final highlight = Palette().redPen;

    return AspectRatio(
      aspectRatio: widget.setting.m / widget.setting.n,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RoughGrid(widget.setting.m, widget.setting.n),
          Column(
            children: [
              for (var y = 0; y < widget.setting.n; y++)
                Expanded(
                  child: Row(
                    children: [
                      for (var x = 0; x < widget.setting.m; x++)
                        Expanded(
                          child: BoardTile(Tile(x, y)),
                        ),
                    ],
                  ),
                )
            ],
          ),
          // 🔶 Draw the stroke across the winning tiles
          if (winningLine != null && winningLine.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _WinningLinePainter(
                    tiles: winningLine,
                    setting: widget.setting,
                    color: highlight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WinningLinePainter extends CustomPainter {
  _WinningLinePainter({
    required this.tiles,
    required this.setting,
    required this.color,
  });

  final List<Tile> tiles;
  final BoardSetting setting;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (tiles.isEmpty) return;

    final cellW = size.width / setting.m;
    final cellH = size.height / setting.n;

    // Build a path through the centers of each winning tile (in order)
    final path = Path();
    for (var i = 0; i < tiles.length; i++) {
      final t = tiles[i];
      final cx = t.x * cellW + cellW / 2;
      final cy = t.y * cellH + cellH / 2;
      if (i == 0) {
        path.moveTo(cx, cy);
      } else {
        path.lineTo(cx, cy);
      }
    }

    final strokeW = math.min(cellW, cellH) * 0.12;

    // Soft glow under the line
    final glow = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Main stroke
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _WinningLinePainter old) =>
      old.tiles != tiles || old.setting != setting || old.color != color;
}
