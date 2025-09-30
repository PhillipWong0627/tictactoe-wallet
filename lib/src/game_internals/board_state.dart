import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:tictactoe/src/ai/ai_opponent.dart';
import 'package:tictactoe/src/game_internals/board_setting.dart';
import 'package:tictactoe/src/game_internals/placed_move.dart';
import 'package:tictactoe/src/game_internals/tile.dart';

class BoardState extends ChangeNotifier {
  static final Logger _log = Logger('BoardState');

  final BoardSetting setting;

  final AiOpponent aiOpponent;

  final Set<int> _xTaken;

  final Set<int> _oTaken;

  Tile? _latestXTile;

  Tile? _latestOTile;

  bool _isLocked = true;

  final ChangeNotifier playerWon = ChangeNotifier();

  final ChangeNotifier aiOpponentWon = ChangeNotifier();
  final ChangeNotifier draw = ChangeNotifier();

  List<Tile>? _winningLine;
  // --- UNDO support ---
  final List<PlacedMove> _history = [];

  bool get canUndo => _history.isNotEmpty;
// === Game mode & local-PvP turn ===
  final GameMode mode; // vsAI or localPvP
  Side _turn = Side.x; // whose turn in local PvP
  Side get turn => _turn;

  void _recomputeLatestForSide(Side side) {
    // Walk history from the end to find latest tile for this side.
    for (var i = _history.length - 1; i >= 0; i--) {
      final mv = _history[i];
      if (mv.side == side) {
        if (side == Side.x) _latestXTile = mv.tile;
        if (side == Side.o) _latestOTile = mv.tile;
        return;
      }
    }
    // No move for this side remains
    if (side == Side.x) _latestXTile = null;
    if (side == Side.o) _latestOTile = null;
  }

  void _clearTile(Tile tile, Side side) {
    final pointer = tile.toPointer(setting);
    final set = _selectSet(side);
    set.remove(pointer);
    // latestX/latestO will be recomputed by caller when needed
  }

  BoardState.clean(
    BoardSetting setting,
    AiOpponent aiOpponent, {
    GameMode mode = GameMode.vsAI, // 👈 default here
  }) : this._(setting, {}, {}, aiOpponent, null, null, mode);

  @visibleForTesting
  BoardState.withExistingState({
    required BoardSetting setting,
    required AiOpponent aiOpponent,
    required Set<int> takenByX,
    required Set<int> takenByO,
    Tile? latestX,
    Tile? latestO,
    GameMode mode = GameMode.vsAI, // 👈 default here too
  }) : this._(setting, takenByX, takenByO, aiOpponent, latestX, latestO, mode);

  BoardState._(
    this.setting,
    this._xTaken,
    this._oTaken,
    this.aiOpponent,
    this._latestXTile,
    this._latestOTile,
    this.mode, // 👈 store it
  );

  /// This is `true` if the board game is locked for the player.
  bool get isLocked => _isLocked;

  Iterable<Tile>? get winningLine => _winningLine;

  Iterable<Tile> get _allTakenTiles =>
      _allTiles.where((tile) => whoIsAt(tile) != Side.none);

  Iterable<Tile> get _allTiles sync* {
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        yield Tile(x, y);
      }
    }
  }

  bool get _hasOpenTiles {
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final owner = whoIsAt(Tile(x, y));
        if (owner == Side.none) return true;
      }
    }
    return false;
  }

  /// Returns true if this tile can be taken by the player.
  bool canTake(Tile tile) {
    return whoIsAt(tile) == Side.none;
  }

  void clearBoard() {
    _xTaken.clear();
    _oTaken.clear();
    _winningLine?.clear();
    _latestXTile = null;
    _latestOTile = null;
    _history.clear(); // <--- add this
    _winningLine = null;

    _isLocked = true;
    _turn = Side.x; // reset turn; initialize() will set again

    notifyListeners();
  }

  void initialize() {
    _oTaken.clear();
    _xTaken.clear();
    _winningLine?.clear();
    _history.clear();
    _latestXTile = null;
    _latestOTile = null;

    if (mode == GameMode.localPvP) {
      // Pass & Play: X starts, no AI auto-move.
      _turn = Side.x;
      _isLocked = false;
      notifyListeners();
      return; // 👈 skip AI opening
    }

    if (setting.aiStarts) {
      final center = Tile((setting.m / 2).floor(), (setting.n ~/ 2).floor());
      _oTaken.add(center.toPointer(setting));
      _latestOTile = center;
      _history.add(PlacedMove(center, Side.o));
    }

    _isLocked = false;
    notifyListeners();
  }

  @override
  void dispose() {
    playerWon.dispose();
    aiOpponentWon.dispose();
    draw.dispose();

    super.dispose();
  }

  Tile? getLatestTileForSide(Side side) {
    if (side == Side.x) {
      return _latestXTile;
    }
    if (side == Side.o) {
      return _latestOTile;
    }
    return null;
  }

  Iterable<Tile> getNeighborhood(Tile tile) sync* {
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) {
          // Same tile as [tile], skipping.
          continue;
        }
        final x = tile.x + dx;
        final y = tile.y + dy;
        if (x < 0) continue;
        if (y < 0) continue;
        if (x >= setting.m) continue;
        if (y >= setting.n) continue;
        yield Tile(x, y);
      }
    }
  }

  /// Returns all valid lines going through [tile].
  Iterable<List<Tile>> getValidLinesThrough(Tile tile) sync* {
    // Horizontal lines.
    for (var startX = tile.x - setting.k + 1; startX <= tile.x; startX++) {
      final startTile = Tile(startX, tile.y);
      if (!startTile.isValid(setting)) continue;
      final endTile = Tile(startTile.x + setting.k - 1, tile.y);
      if (!endTile.isValid(setting)) continue;
      yield [for (var i = startTile.x; i <= endTile.x; i++) Tile(i, tile.y)];
    }

    // Vertical lines.
    for (var startY = tile.y - setting.k + 1; startY <= tile.y; startY++) {
      final startTile = Tile(tile.x, startY);
      if (!startTile.isValid(setting)) continue;
      final endTile = Tile(tile.x, startTile.y + setting.k - 1);
      if (!endTile.isValid(setting)) continue;
      yield [for (var i = startTile.y; i <= endTile.y; i++) Tile(tile.x, i)];
    }

    // Downward diagonal lines.
    for (var xOffset = -setting.k + 1; xOffset <= 0; xOffset++) {
      var yOffset = xOffset;
      final startTile = Tile(tile.x + xOffset, tile.y + yOffset);
      if (!startTile.isValid(setting)) continue;
      final endTile =
          Tile(startTile.x + setting.k - 1, startTile.y + setting.k - 1);
      if (!endTile.isValid(setting)) continue;
      yield [
        for (var i = 0; i < setting.k; i++)
          Tile(startTile.x + i, startTile.y + i)
      ];
    }

    // Upward diagonal lines.
    for (var xOffset = -setting.k + 1; xOffset <= 0; xOffset++) {
      var yOffset = -xOffset;
      final startTile = Tile(tile.x + xOffset, tile.y + yOffset);
      if (!startTile.isValid(setting)) continue;
      final endTile =
          Tile(startTile.x + setting.k - 1, startTile.y - setting.k + 1);
      if (!endTile.isValid(setting)) continue;
      yield [
        for (var i = 0; i < setting.k; i++)
          Tile(startTile.x + i, startTile.y - i)
      ];
    }
  }

  /// Take [tile] with player's token.
  void take(Tile tile) async {
    _log.info(() => 'taking $tile');
    assert(canTake(tile));
    assert(!_isLocked);
    // Decide who is moving: player vs AI mode → playerSide, PvP → current turn
    final mover = (mode == GameMode.vsAI) ? setting.playerSide : _turn;

    _takeTile(tile, mover);
    _history.add(PlacedMove(tile, mover));

    _isLocked = true;

    final moverJustWon = _getWinner() == mover;

    if (moverJustWon) {
      // Reuse existing notifiers (X → playerWon, O → aiOpponentWon)
      (mover == Side.x ? playerWon : aiOpponentWon).notifyListeners();
      notifyListeners();
      return;
    }

    // ADDED: if player didn't win and there are no open tiles -> DRAW
    if (!_hasOpenTiles) {
      draw.notifyListeners();
      notifyListeners();
      return;
    }

    // In local PvP: toggle turn and DO NOT call AI.
    if (mode == GameMode.localPvP) {
      _turn = (mover == Side.x) ? Side.o : Side.x;
      _isLocked = false;
      notifyListeners();
      return; // 👈 important: skip AI move
    }

    // Time for AI to move.
    await Future.delayed(const Duration(milliseconds: 300));
    assert(_isLocked);
    assert(_hasOpenTiles, 'Somehow, tiles got taken while waiting for AI turn');

    final aiTile = aiOpponent.chooseNextMove(this);
    _takeTile(aiTile, setting.aiOpponentSide);
    _history.add(PlacedMove(aiTile, setting.aiOpponentSide));

    if (_getWinner() == setting.aiOpponentSide) {
      aiOpponentWon.notifyListeners();
      notifyListeners();
      return;
    }

    // ADDED: after AI move, if nobody won and no open tiles -> DRAW
    if (!_hasOpenTiles) {
      draw.notifyListeners();
      notifyListeners();
      return;
    }

    // Play continues.
    _isLocked = false;
    notifyListeners();
  }

  Side whoIsAt(Tile tile) {
    final pointer = tile.toPointer(setting);
    bool takenByX = _xTaken.contains(pointer);
    bool takenByO = _oTaken.contains(pointer);

    if (takenByX && takenByO) {
      throw StateError('The $tile at is taken by both X and Y.');
    }
    if (takenByX) {
      return Side.x;
    } else if (takenByO) {
      return Side.o;
    }
    return Side.none;
  }

  /// Returns `null` if nobody has yet won this board. Otherwise, returns
  /// the winner.
  ///
  /// If somehow both parties are winning, then the behavior of this method
  /// is undefined.
  ///
  /// As a side-effect, this function sets [winningLine] if found.
  ///
  /// This function might take some time on bigger boards to evaluate.
  Side? _getWinner() {
    for (final tile in _allTakenTiles) {
      // TODO: instead of checking each tile, check each valid line just once
      for (final validLine in getValidLinesThrough(tile)) {
        final owner = whoIsAt(validLine.first);
        if (owner == Side.none) continue;
        if (validLine.every((tile) => whoIsAt(tile) == owner)) {
          _winningLine = validLine;
          return owner;
        }
      }
    }

    return null;
  }

  Set<int> _selectSet(Side owner) {
    switch (owner) {
      case Side.x:
        return _xTaken;
      case Side.o:
        return _oTaken;
      case Side.none:
        throw ArgumentError.value(owner);
    }
  }

  void _takeTile(Tile tile, Side side) {
    final pointer = tile.toPointer(setting);
    final set = _selectSet(side);
    set.add(pointer);
    if (side == Side.x) {
      _latestXTile = tile;
    } else if (side == Side.o) {
      _latestOTile = tile;
    }
  }

  Set<int> _generateInitialOTaken() {
    assert(setting.aiOpponentSide == Side.o, "Unimplemented: AI plays as X");

    if (setting.aiStarts) {
      final tile = Tile((setting.m / 2).floor(), (setting.n ~/ 2).floor());
      return {
        tile.toPointer(setting),
      };
    } else {
      return {};
    }
  }

  /// Undo just the last move (good for PvP or single-step undo).
  void undoLast() {
    if (_history.isEmpty) return;

    final last = _history.removeLast();
    _clearTile(last.tile, last.side);
    _recomputeLatestForSide(last.side);

    // Unlock for player to move after undo
    _isLocked = false;
    _winningLine = null;

    notifyListeners();
  }

  /// Undo a full turn vs AI (AI move + player's previous move).
  void undoFullTurn() {
    if (_history.isEmpty) return;

    // If AI moved last, pop 2. If player moved last, pop 1 (and possibly AI before that).
    final last = _history.last;

    if (last.side == setting.aiOpponentSide) {
      // undo AI
      undoLast();
      // undo player (if present)
      if (_history.isNotEmpty) undoLast();
    } else {
      // last was player
      undoLast();
      // If AI had moved previously, also undo it to revert a full turn
      if (_history.isNotEmpty && _history.last.side == setting.aiOpponentSide) {
        undoLast();
      }
    }
  }
}

enum Side {
  x,
  o,
  none,
}

enum GameMode { vsAI, localPvP }
