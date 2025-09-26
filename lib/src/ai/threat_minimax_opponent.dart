import 'dart:math';
import 'package:tictactoe/src/ai/ai_opponent.dart';
import 'package:tictactoe/src/game_internals/board_setting.dart';
import 'package:tictactoe/src/game_internals/board_state.dart';
import 'package:tictactoe/src/game_internals/tile.dart';

/// A much tougher bot for k=5 on big boards:
/// - Tactics first: win-in-1, block-in-1, double-threat creation
/// - Time-boxed iterative deepening alpha-beta (negamax form)
/// - Simple transposition table + killer move ordering
class ThreatMinimaxOpponent extends AiOpponent {
  @override
  final String name;

  /// Max search depth (plies). We time-box each move, so this is an upper bound.
  final int maxDepth;

  /// Per-move time budget in milliseconds (keeps UI responsive).
  final int timeLimitMs;

  /// Cap of candidate moves checked at each node.
  final int maxCandidates;

  /// Only consider empty tiles within this Chebyshev distance of any stone.
  final int proximityRadius;

  /// Heuristic weights (index == stones in a k-window).
  final List<int> aiScoring;
  final List<int> playerScoring;

  ThreatMinimaxOpponent(
    BoardSetting setting, {
    this.name = 'Threat+',
    this.maxDepth = 4,
    this.timeLimitMs = 120, // 120–180ms is a good feel on phones
    this.maxCandidates = 12,
    this.proximityRadius = 2,
    this.playerScoring = const [1, 60, 400, 10000, 2000000, 0],
    this.aiScoring = const [2, 80, 600, 12000, 3000000, 0],
  }) : super(setting) {
    assert(setting.k <= playerScoring.length + 1);
    assert(setting.k <= aiScoring.length + 1);
  }

  // --------- public API ---------
  @override
  Tile chooseNextMove(BoardState state) {
    final empties = _emptyTiles(state);
    if (empties.isEmpty) return Tile(0, 0);

    // Opening: center
    if (_occupiedCount(state) == 0) return _centerOf(empties);

    // 1) Win now?
    final winNow = _winInOne(state, setting.aiOpponentSide);
    if (winNow != null) return winNow;

    // 2) Block now?
    final blockNow = _winInOne(state, setting.playerSide);
    if (blockNow != null) return blockNow;

    // 3) Create a double threat?
    final dt = _createDoubleThreat(state);
    if (dt != null) return dt;

    // 4) ID iterative deepening with a time budget
    final start = DateTime.now().microsecondsSinceEpoch;
    final deadline = start + timeLimitMs * 1000;

    Tile? bestMove;
    int bestScore = -inf;
    final killer = <int, Tile?>{}; // simple killer move per depth

    // iterative deepening 1..maxDepth
    for (int depth = 1; depth <= maxDepth; depth++) {
      final result = _searchRoot(state, depth, deadline, killer);
      if (result == null) break; // out of time
      bestMove = result.item1;
      bestScore = result.item2;
      // If we already found a forced win/lose score, we can stop
      if (bestScore >= winScore / 10 || bestScore <= -winScore / 10) break;
    }

    return bestMove ?? _centerOf(empties);
  }

  // --------- search core ---------
  // transposition table: key -> (depth, score, flag)
  final _tt = <String, _TTEntry>{};

  // Root search with ordering & deadline
  _RootPick? _searchRoot(
      BoardState s, int depth, int deadlineUs, Map<int, Tile?> killer) {
    final cands = _orderedCandidates(s, maxCandidates, killer: killer[depth]);
    if (cands.isEmpty) return (_RootPick(Tile(0, 0), 0));

    int alpha = -inf, beta = inf;
    Tile? bestMove;
    int bestScore = -inf;

    for (final mv in cands) {
      if (_timeUp(deadlineUs)) return null;

      _place(mv, setting.aiOpponentSide);
      final sc = -_negamax(s, depth - 1, -beta, -alpha,
          _opp(setting.aiOpponentSide), deadlineUs, killer);
      _undo(mv);

      if (sc > bestScore) {
        bestScore = sc;
        bestMove = mv;
      }
      if (sc > alpha) alpha = sc;
      if (alpha >= beta) {
        killer[depth] = mv; // store killer
        break;
      }
    }
    return _RootPick(bestMove!, bestScore);
  }

  int _negamax(
    BoardState s,
    int depth,
    int alpha,
    int beta,
    Side sideToMove,
    int deadlineUs,
    Map<int, Tile?> killer,
  ) {
    if (_timeUp(deadlineUs)) return 0;

    // Terminal checks
    final t = _terminalWinner(s);
    if (t != null) {
      if (t == setting.aiOpponentSide) return winScore;
      if (t == setting.playerSide) return -winScore;
    }
    if (depth == 0) return _eval(s);

    final key = _hashKey(s, sideToMove);
    final tt = _tt[key];
    if (tt != null && tt.depth >= depth) {
      // Simple exact lookup
      return tt.score;
    }

    int a = alpha;
    int best = -inf;

    final cands = _orderedCandidates(s, maxCandidates, killer: killer[depth]);
    if (cands.isEmpty) return _eval(s);

    for (final mv in cands) {
      _place(mv, sideToMove);
      final sc = -_negamax(
          s, depth - 1, -beta, -a, _opp(sideToMove), deadlineUs, killer);
      _undo(mv);

      if (sc > best) best = sc;
      if (sc > a) a = sc;
      if (a >= beta) {
        killer[depth] = mv;
        break;
      }
    }

    _tt[key] = _TTEntry(depth, best);
    return best;
  }

  // --------- tactics ---------

  // Find any immediate winning move for `side`
  Tile? _winInOne(BoardState s, Side side) {
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        if (_occ(s, t) != Side.none) continue;
        if (_completesK(s, t, side)) return t;
      }
    }
    return null;
  }

  // Try to create a double threat (two distinct immediate wins next turn)
  Tile? _createDoubleThreat(BoardState s) {
    for (final t in _orderedCandidates(s, maxCandidates * 2)) {
      _place(t, setting.aiOpponentSide);
      final wins = _listImmediateWins(s, setting.aiOpponentSide);
      _undo(t);
      if (wins.length >= 2) {
        // Opponent can block at most one → essentially forced win soon.
        return t;
      }
    }
    return null;
  }

  List<Tile> _listImmediateWins(BoardState s, Side side) {
    final res = <Tile>[];
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        if (_occ(s, t) != Side.none) continue;
        if (_completesK(s, t, side)) res.add(t);
      }
    }
    return res;
  }

  bool _completesK(BoardState s, Tile t, Side side) {
    // Pretend place at t and check any k-window reaches k
    for (final line in s.getValidLinesThrough(t)) {
      int cnt = 0;
      for (final q in line) {
        final occSide = (q == t) ? side : _occ(s, q);
        if (occSide == side) cnt++;
      }
      if (cnt >= setting.k) return true;
    }
    return false;
  }

  // --------- eval & move ordering ---------

  int _eval(BoardState s) {
    // ScoringOpponent-like heuristic over empty tiles/windows, using overlay.
    int score = 0;
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        if (_occ(s, t) != Side.none) continue;

        for (final line in s.getValidLinesThrough(t)) {
          int ai = 0, pl = 0;
          for (final q in line) {
            final side = _occ(s, q);
            if (side == setting.aiOpponentSide)
              ai++;
            else if (side == setting.playerSide) pl++;
          }
          if (ai > 0 && pl > 0) continue; // mixed window is dead
          if (ai == 0) score += playerScoring[pl]; // defense
          if (pl == 0) score += aiScoring[ai]; // offense
        }
      }
    }
    return score;
  }

  List<Tile> _orderedCandidates(BoardState s, int limit, {Tile? killer}) {
    final occ = _occupiedSet(s);
    final empties = _emptyTiles(s);
    if (occ.isEmpty) return [_centerOf(empties)];

    // Seed obvious tactics first: (win/block) ordering signal
    final map = <Tile, int>{};

    for (final e in empties) {
      if (!_nearAny(e, occ, proximityRadius)) continue;

      int score = 0;

      // Tactical priority signals
      if (_completesK(s, e, setting.aiOpponentSide))
        score += 100000; // winning now
      if (_completesK(s, e, setting.playerSide)) score += 90000; // block now

      // Local hotness: neighbors count
      for (final n in s.getNeighborhood(e)) {
        if (_occ(s, n) != Side.none) score += 10;
      }

      // Line-end bias for near wins/blocks
      for (final line in s.getValidLinesThrough(e)) {
        final isEnd = (e == line.first || e == line.last);
        if (!isEnd) continue;
        int ai = 0, pl = 0;
        for (final q in line) {
          final side = _occ(s, q);
          if (side == setting.aiOpponentSide)
            ai++;
          else if (side == setting.playerSide) pl++;
        }
        if (ai > 0 && pl == 0) {
          if (ai == setting.k - 1)
            score += 600;
          else if (ai == setting.k - 2) score += 300;
        }
        if (pl > 0 && ai == 0) {
          if (pl == setting.k - 1)
            score += 800; // prioritize blocking
          else if (pl == setting.k - 2) score += 400;
        }
      }

      // Killer move gets a boost
      if (killer != null && e == killer) score += 2000;

      map[e] = score;
    }

    var list = map.keys.toList()..sort((a, b) => -map[a]!.compareTo(map[b]!));

    if (list.isEmpty) list = empties;
    if (list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  // --------- overlay / occupancy utils ---------

  final Map<Tile, Side> _overlay = {};

  Side _occ(BoardState s, Tile t) => _overlay[t] ?? s.whoIsAt(t);

  void _place(Tile t, Side side) => _overlay[t] = side;

  void _undo(Tile t) => _overlay.remove(t);

  Set<Tile> _occupiedSet(BoardState s) {
    final set = <Tile>{};
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        if (_occ(s, t) != Side.none) set.add(t);
      }
    }
    return set;
  }

  List<Tile> _emptyTiles(BoardState s) {
    final out = <Tile>[];
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        if (_occ(s, t) == Side.none) out.add(t);
      }
    }
    return out;
  }

  int _occupiedCount(BoardState s) {
    var c = 0;
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        if (_occ(s, Tile(x, y)) != Side.none) c++;
      }
    }
    return c;
  }

  bool _nearAny(Tile t, Set<Tile> stones, int r) {
    for (final s in stones) {
      if ((t.x - s.x).abs() <= r && (t.y - s.y).abs() <= r) return true;
    }
    return false;
  }

  Tile _centerOf(List<Tile> empties) {
    final cx = (setting.m - 1) / 2.0, cy = (setting.n - 1) / 2.0;
    empties.sort((a, b) {
      final da = (a.x - cx) * (a.x - cx) + (a.y - cy) * (a.y - cy);
      final db = (b.x - cx) * (b.x - cx) + (b.y - cy) * (b.y - cy);
      return da.compareTo(db);
    });
    return empties.first;
  }

  // Winner detection (simple global scan; OK with pruning/time-box)
  Side? _terminalWinner(BoardState s) {
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        for (final line in s.getValidLinesThrough(t)) {
          int ai = 0, pl = 0;
          for (final q in line) {
            final side = _occ(s, q);
            if (side == setting.aiOpponentSide)
              ai++;
            else if (side == setting.playerSide) pl++;
          }
          if (ai >= setting.k) return setting.aiOpponentSide;
          if (pl >= setting.k) return setting.playerSide;
        }
      }
    }
    return null;
  }

  // --------- TT & misc ---------

  // Very simple hash: serialize occupancy + sideToMove
  String _hashKey(BoardState s, Side stm) {
    final sb =
        StringBuffer('${setting.m}x${setting.n}k${setting.k}|${stm.index}|');
    for (var y = 0; y < setting.n; y++) {
      for (var x = 0; x < setting.m; x++) {
        final t = Tile(x, y);
        final side = _occ(s, t);
        sb.write(side.index); // 0 none, 1 X, 2 O (assuming Side order)
      }
      sb.write('|');
    }
    return sb.toString();
  }

  bool _timeUp(int deadlineUs) =>
      DateTime.now().microsecondsSinceEpoch >= deadlineUs;

  static const int inf = 0x3fffffff;
  static const int winScore = 100000000;
}

class _TTEntry {
  final int depth;
  final int score;
  _TTEntry(this.depth, this.score);
}

class _RootPick {
  final Tile item1;
  final int item2;
  _RootPick(this.item1, this.item2);
}

Side _opp(Side s) {
  if (s == Side.x) return Side.o;
  if (s == Side.o) return Side.x;
  return Side.none;
}
