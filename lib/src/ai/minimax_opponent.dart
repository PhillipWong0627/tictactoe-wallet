// lib/src/ai/minimax_opponent.dart
import 'dart:math';
import 'package:tictactoe/src/ai/ai_opponent.dart';
import 'package:tictactoe/src/game_internals/board_setting.dart';
import 'package:tictactoe/src/game_internals/board_state.dart';
import 'package:tictactoe/src/game_internals/tile.dart';

/// A think-ahead opponent: shallow minimax + alpha-beta pruning with
/// one-ply (win/block) short-circuit and aggressive candidate pruning.
/// Works well on large boards with k=5 at depth 2–3.
class MinimaxOpponent extends AiOpponent {
  @override
  final String name;

  /// Total plies to search (1 ply = one move by either side).
  /// Use 2 on 15x15 for smoothness; 3 if device is fast.
  final int depth;

  /// Max number of candidate moves explored at each node.
  final int maxCandidates;

  /// Empty tiles beyond this taxi radius from any stone are ignored.
  final int proximityRadius;

  /// Heuristic weights (index == count in a k-window).
  final List<int> aiScoring;
  final List<int> playerScoring;

  MinimaxOpponent(
    BoardSetting setting, {
    this.name = 'Minimax',
    this.depth = 2,
    this.maxCandidates = 10,
    this.proximityRadius = 2,
    this.playerScoring = const [1, 60, 400, 10000, 2000000, 0],
    this.aiScoring = const [2, 80, 600, 12000, 3000000, 0],
  }) : super(setting) {
    assert(depth >= 1);
    assert(maxCandidates >= 1);
    assert(proximityRadius >= 1);
    assert(setting.k <= playerScoring.length + 1,
        'playerScoring does not support k > 5');
    assert(
        setting.k <= aiScoring.length + 1, 'aiScoring does not support k > 5');
  }

  @override
  Tile chooseNextMove(BoardState state) {
    // 0) If board empty -> center
    final empties = _emptyTiles(state);
    if (empties.isEmpty) return Tile(0, 0);
    if (_occupiedCount(state) == 0) {
      return _centerFallback(empties);
    }

    // 1) One-ply short-circuit (win in one / block in one)
    final winNow = _onePlyTactic(state, setting.aiOpponentSide);
    if (winNow != null) return winNow;

    final blockNow = _onePlyTactic(state, setting.playerSide);
    if (blockNow != null) return blockNow;

    // 2) Candidate generation & ordering
    final candidates = _orderedCandidates(state, maxCandidates);
    if (candidates.isEmpty) return _centerFallback(empties);

    // 3) Alpha-beta search
    int bestScore = -0x3fffffff;
    Tile? bestMove;

    int alpha = -0x3fffffff;
    int beta = 0x3fffffff;

    // Negamax form (score for side to move; we call with AI to move).
    for (final t in candidates) {
      state._pushHypo(t, setting.aiOpponentSide);
      final score = -_negamax(
        state,
        depth - 1,
        alpha: -beta,
        beta: -alpha,
        sideToMove: _opp(setting.aiOpponentSide),
      );
      state._popHypo(t);

      if (score > bestScore) {
        bestScore = score;
        bestMove = t;
      }
      if (score > alpha) alpha = score;
      if (alpha >= beta) break; // cut
    }

    return bestMove ?? _centerFallback(empties);
  }

  // --------------------- Search core ---------------------

  int _negamax(
    BoardState state,
    int d, {
    required int alpha,
    required int beta,
    required Side sideToMove,
  }) {
    // Terminal checks (fast): win/loss detected under current board
    final term = _terminalScore(state);
    if (term != null) return term;

    if (d == 0) return _eval(state);

    final moves = _orderedCandidates(state, maxCandidates);
    if (moves.isEmpty) return _eval(state);

    int a = alpha;
    int best = -0x3fffffff;

    for (final t in moves) {
      state._pushHypo(t, sideToMove);
      final score = -_negamax(
        state,
        d - 1,
        alpha: -beta,
        beta: -a,
        sideToMove: _opp(sideToMove),
      );
      state._popHypo(t);

      if (score > best) best = score;
      if (score > a) a = score;
      if (a >= beta) break; // prune
    }
    return best;
  }

  // Returns huge positive if AI has k-in-a-row, huge negative if player has.
  int? _terminalScore(BoardState state) {
    // We only need to check lines through last moves for speed,
    // but if BoardState doesn't expose, do a quick global scan
    // that relies on getValidLinesThrough of empty tiles around stones.
    // (Still fast enough with tight candidates + shallow depth.)
    final res = _winnerIfAny(state);
    if (res == null) return null;
    if (res == setting.aiOpponentSide) return 100000000;
    if (res == setting.playerSide) return -100000000;
    return null;
  }

  Side? _winnerIfAny(BoardState state) {
    // Scan: for every occupied tile, check k-windows that include it.
    // We approximate by scanning k-windows from every tile to keep it simple.
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        for (final line in state.getValidLinesThrough(t)) {
          int ai = 0, pl = 0;
          for (final q in line) {
            final s = state.whoIsAt(q);
            if (s == setting.aiOpponentSide)
              ai++;
            else if (s == setting.playerSide) pl++;
          }
          if (ai >= setting.k) return setting.aiOpponentSide;
          if (pl >= setting.k) return setting.playerSide;
        }
      }
    }
    return null;
  }

  // --------------------- Heuristic eval ---------------------

  int _eval(BoardState state) {
    // ScoringOpponent-style: sum attack & defense over all empty tiles/windows.
    int score = 0;
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        if (state.whoIsAt(t) != Side.none) continue;

        for (final line in state.getValidLinesThrough(t)) {
          int ai = 0, pl = 0;
          for (final q in line) {
            final s = state.whoIsAt(q);
            if (s == setting.aiOpponentSide)
              ai++;
            else if (s == setting.playerSide) pl++;
          }
          if (ai > 0 && pl > 0) continue; // mixed window: dead

          if (ai == 0) score += playerScoring[pl]; // defense
          if (pl == 0) score += aiScoring[ai]; // offense
        }
      }
    }
    return score;
  }

  // --------------------- Tactics & candidates ---------------------

  /// If `side` can win in one move, return that Tile. Else null.
  Tile? _onePlyTactic(BoardState state, Side side) {
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        if (state.whoIsAt(t) != Side.none) continue;

        // Pretend placing `side` at t: check any line reaches k
        bool win = false;
        for (final line in state.getValidLinesThrough(t)) {
          int cnt = 0;
          for (final q in line) {
            if (q == t || state.whoIsAt(q) == side) cnt++;
          }
          if (cnt >= setting.k) {
            win = true;
            break;
          }
        }
        if (win) return t;
      }
    }
    return null;
  }

  /// Generate and order promising moves near existing stones.
  List<Tile> _orderedCandidates(BoardState state, int limit) {
    final occupied = <Tile>{};
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        if (state.whoIsAt(t) != Side.none) occupied.add(t);
      }
    }

    final empties = _emptyTiles(state);
    if (occupied.isEmpty) return [_centerFallback(empties)];

    final hot = <Tile, int>{};
    for (final e in empties) {
      if (_isNearAny(e, occupied, proximityRadius)) {
        // Light local heuristic: neighbor count (both sides) to find hotspots
        int local = 0;
        for (final n in state.getNeighborhood(e)) {
          if (state.whoIsAt(n) != Side.none) local++;
        }
        // Bonus if e extends at a line end that is close to win/loss
        int lineBonus = 0;
        for (final line in state.getValidLinesThrough(e)) {
          final isEnd = (e == line.first || e == line.last);
          if (!isEnd) continue;
          int ai = 0, pl = 0;
          for (final q in line) {
            final s = state.whoIsAt(q);
            if (s == setting.aiOpponentSide)
              ai++;
            else if (s == setting.playerSide) pl++;
          }
          if (ai > 0 && pl == 0) {
            if (ai == setting.k - 1)
              lineBonus += 6;
            else if (ai == setting.k - 2) lineBonus += 3;
          }
          if (pl > 0 && ai == 0) {
            if (pl == setting.k - 1)
              lineBonus += 8; // blocking is priority
            else if (pl == setting.k - 2) lineBonus += 4;
          }
        }
        hot[e] = local * 10 + lineBonus; // local dominates; lineBonus refines
      }
    }

    var sorted = hot.keys.toList()..sort((a, b) => -hot[a]!.compareTo(hot[b]!));

    if (sorted.isEmpty) sorted = empties;

    if (sorted.length > limit) {
      sorted = sorted.sublist(0, limit);
    }
    return sorted;
  }

  // --------------------- Utilities ---------------------

  List<Tile> _emptyTiles(BoardState state) {
    final out = <Tile>[];
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        if (state.whoIsAt(t) == Side.none) out.add(t);
      }
    }
    return out;
  }

  int _occupiedCount(BoardState state) {
    int c = 0;
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        if (state.whoIsAt(Tile(x, y)) != Side.none) c++;
      }
    }
    return c;
  }

  Tile _centerFallback(List<Tile> empties) {
    final cx = (setting.m - 1) / 2.0;
    final cy = (setting.n - 1) / 2.0;
    empties.sort((a, b) {
      final da = (a.x - cx) * (a.x - cx) + (a.y - cy) * (a.y - cy);
      final db = (b.x - cx) * (b.x - cx) + (b.y - cy) * (b.y - cy);
      return da.compareTo(db);
    });
    return empties.first;
  }

  bool _isNearAny(Tile t, Set<Tile> stones, int r) {
    for (final s in stones) {
      if ((t.x - s.x).abs() <= r && (t.y - s.y).abs() <= r) return true;
    }
    return false;
  }

  Side _opp(Side s) {
    if (s == Side.x) return Side.o;
    if (s == Side.o) return Side.x;
    return Side.none;
  }
}

/// ---------- BoardState hypo overlay helpers ----------
/// We avoid mutating permanent state by placing/removing a "hypo" mark
/// directly on the BoardState if it supports it. If your BoardState
/// doesn't have these, you can replace with an external overlay map.
/// For simplicity, we attach minimal extension-like methods here.
///
/// NOTE: If your BoardState doesn't support temp placements,
/// implement these by tracking a private Map<Tile, Side> overlay and
/// patch whoIsAt() to consult it first. For now, we simulate by
/// calling hidden methods; replace with your own wiring if needed.
extension _Hypo on BoardState {
  // You may replace these with your own temporary placement mechanism.
  void _pushHypo(Tile t, Side s) {
    // If your BoardState has a dedicated API like `placeHypo` use it here.
    // Otherwise, if you only have permanent placement, consider creating
    // a forked state for search. For performance, most repos add a small
    // overlay map. Here we assume you have a light-weight internal hook:
    placeHypothetical(t, s); // <-- implement in your BoardState
  }

  void _popHypo(Tile t) {
    removeHypothetical(t); // <-- implement in your BoardState
  }
}
