// lib/src/ai/threat_space_opponent.dart
import 'dart:math';
import 'package:tictactoe/src/ai/ai_opponent.dart';
import 'package:tictactoe/src/game_internals/board_setting.dart';
import 'package:tictactoe/src/game_internals/board_state.dart';
import 'package:tictactoe/src/game_internals/tile.dart';

/// Threat-Space (VCT/VCF-like) Opponent:
/// 1) Win-in-1
/// 2) Block-in-1
/// 3) VCT search: attacker creates threats; defender must block; repeat.
///    If at any step attacker has >= 2 winning replies -> forced win.
/// 4) Fallback: shallow negamax (depth 2) with good ordering.
///
/// Works well for k=5 on big boards. Time-boxed so UI stays responsive.
class ThreatSpaceOpponent extends AiOpponent {
  @override
  final String name;

  /// Max plies in the threat-space (attacker+defender steps). 8–12 is good.
  final int maxThreatDepth;

  /// Per-move time budget in milliseconds for the whole think.
  final int timeLimitMs;

  /// Candidate cap at each node.
  final int maxCandidates;

  /// Only consider empty tiles within this Chebyshev distance of any stone.
  final int proximityRadius;

  /// Heuristic weights for fallback search (index == stones in a k-window).
  final List<int> aiScoring;
  final List<int> playerScoring;

  ThreatSpaceOpponent(
    BoardSetting setting, {
    this.name = 'VCT',
    this.maxThreatDepth = 10,
    this.timeLimitMs = 160,
    this.maxCandidates = 12,
    this.proximityRadius = 2,
    this.playerScoring = const [1, 60, 400, 10000, 2000000, 0],
    this.aiScoring = const [2, 80, 600, 12000, 3000000, 0],
  }) : super(setting) {
    assert(setting.k <= playerScoring.length + 1);
    assert(setting.k <= aiScoring.length + 1);
  }

  // ---- public API ----
  @override
  Tile chooseNextMove(BoardState state) {
    final empties = _emptyTiles(state);
    if (empties.isEmpty) return Tile(0, 0);
    if (_occupiedCount(state) == 0) return _centerOf(empties);

    // 1) Immediate tactics
    final winNow = _winInOne(state, setting.aiOpponentSide);
    if (winNow != null) return winNow;

    final blockNow = _winInOne(state, setting.playerSide);
    if (blockNow != null) return blockNow;

    // 2) Threat-space search (VCT)
    _deadlineUs = DateTime.now().microsecondsSinceEpoch + timeLimitMs * 1000;
    _overlay.clear();
    _pv.clear();

    final vctMove = _vctRoot(state);
    if (vctMove != null) return vctMove;

    // 3) Fallback: shallow negamax (fast, good ordering)
    return _negamaxRoot(state);
  }

  // ---- Threat-space search (VCT/VCF-like) ----

  // Principal variation (stores sequence when found)
  final List<Tile> _pv = [];

  // simple time control
  late int _deadlineUs;
  bool get _timeUp => DateTime.now().microsecondsSinceEpoch >= _deadlineUs;

  /// Root: try candidate attacks; if any proves a VCT within depth/time, return it.
  Tile? _vctRoot(BoardState s) {
    // Try strongest candidate attacks first.
    final cand = _orderAttacks(s, maxCandidates * 2);
    for (final a in cand) {
      if (_timeUp) break;

      _place(a, setting.aiOpponentSide);

      // Check if double threat right away (two or more winning replies).
      final wins = _listImmediateWins(s, setting.aiOpponentSide);
      if (wins.length >= 2) {
        _undo(a);
        return a;
      }

      // Recursive VCT: attacker created at least 1 threat; defender must block.
      if (wins.isNotEmpty &&
          _vctDefend(s, depth: maxThreatDepth - 1, blocks: wins)) {
        _undo(a);
        return a; // first move in forced win line
      }

      _undo(a);
    }
    return null;
  }

  /// Defender turn in VCT: must block one of `blocks` (attacker’s winning replies).
  /// Returns true if for every legal block, attacker still has a VCT continuation.
  bool _vctDefend(BoardState s,
      {required int depth, required List<Tile> blocks}) {
    if (_timeUp) return false;
    if (depth <= 0) return false;

    // Defender must choose one of the winning replies to block.
    for (final b in blocks) {
      _place(b, setting.playerSide);

      // After defender blocks, attacker must create a new threat again.
      final ok = _vctAttack(s, depth: depth - 1);

      _undo(b);
      if (!ok) return false; // defender found a block that refutes
    }
    return true; // every block still loses -> forced win
  }

  /// Attacker turn in VCT: must make a move that (a) wins immediately or
  /// (b) produces at least one winning reply next turn; if it produces >=2,
  /// it's an instant VCF (double threat).
  bool _vctAttack(BoardState s, {required int depth}) {
    if (_timeUp) return false;
    if (depth <= 0) return false;

    // Attack moves: order aggressively near hot spots.
    final cand = _orderAttacks(s, maxCandidates);
    for (final a in cand) {
      _place(a, setting.aiOpponentSide);

      // immediate win?
      if (_completesK(s, a, setting.aiOpponentSide)) {
        _undo(a);
        return true;
      }

      final wins = _listImmediateWins(s, setting.aiOpponentSide);
      if (wins.length >= 2) {
        _undo(a);
        return true; // double threat => defender cannot parry all
      }

      if (wins.isNotEmpty) {
        // Defender must block one; if all blocks still lose, it's a VCT.
        final ok = _vctDefend(s, depth: depth - 1, blocks: wins);
        _undo(a);
        if (ok) return true;
      } else {
        _undo(a);
      }
    }
    return false;
  }

  // List tiles that would win immediately for `side` (from current overlay state).
  List<Tile> _listImmediateWins(BoardState s, Side side) {
    final out = <Tile>[];
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        if (_occ(s, t) != Side.none) continue;
        if (_completesK(s, t, side)) out.add(t);
      }
    }
    return out;
  }

  // ---- Fallback search: shallow negamax (depth 2) ----

  Tile _negamaxRoot(BoardState s) {
    final cand = _orderedCandidates(s, maxCandidates);
    if (cand.isEmpty) return _centerOf(_emptyTiles(s));

    int alpha = -inf, beta = inf;
    int bestScore = -inf;
    Tile best = cand.first;

    for (final mv in cand) {
      _place(mv, setting.aiOpponentSide);
      final sc = -_negamax(s,
          d: 1, alpha: -beta, beta: -alpha, stm: _opp(setting.aiOpponentSide));
      _undo(mv);
      if (sc > bestScore) {
        bestScore = sc;
        best = mv;
      }
      if (sc > alpha) alpha = sc;
      if (alpha >= beta) break;
    }
    return best;
  }

  int _negamax(
    BoardState s, {
    required int d,
    required int alpha,
    required int beta,
    required Side stm,
  }) {
    // quick terminal
    final w = _terminalWinner(s);
    if (w != null) {
      if (w == setting.aiOpponentSide) return winScore;
      if (w == setting.playerSide) return -winScore;
    }
    if (d == 0) return _eval(s);

    int a = alpha;
    int best = -inf;
    final cand = _orderedCandidates(s, maxCandidates);
    if (cand.isEmpty) return _eval(s);

    for (final mv in cand) {
      _place(mv, stm);
      final sc = -_negamax(s, d: d - 1, alpha: -beta, beta: -a, stm: _opp(stm));
      _undo(mv);
      if (sc > best) best = sc;
      if (sc > a) a = sc;
      if (a >= beta) break;
    }
    return best;
  }

  // ---- Tactics & ordering ----

  // Any immediate winning move for side?
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

  // True if placing `side` at t completes k-in-a-row.
  bool _completesK(BoardState s, Tile t, Side side) {
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

  // Attack move ordering: prefer moves that win, block, make hot threats.
  List<Tile> _orderAttacks(BoardState s, int limit) {
    final occ = _occupiedSet(s);
    final empties = _emptyTiles(s);
    if (occ.isEmpty) return [_centerOf(empties)];

    final map = <Tile, int>{};
    for (final e in empties) {
      if (!_nearAny(e, occ, proximityRadius)) continue;

      int score = 0;
      // Immediate win / block signals
      if (_completesK(s, e, setting.aiOpponentSide)) score += 200000;
      if (_completesK(s, e, setting.playerSide)) score += 150000;

      // Local hotness
      for (final n in s.getNeighborhood(e)) {
        if (_occ(s, n) != Side.none) score += 10;
      }

      // Threat potential (line-end bias)
      for (final line in s.getValidLinesThrough(e)) {
        final isEnd = (e == line.first || e == line.last);
        if (!isEnd) continue;
        int ai = 0, pl = 0;
        for (final q in line) {
          final sd = _occ(s, q);
          if (sd == setting.aiOpponentSide)
            ai++;
          else if (sd == setting.playerSide) pl++;
        }
        if (ai > 0 && pl == 0) {
          if (ai == setting.k - 1)
            score += 600;
          else if (ai == setting.k - 2) score += 300;
        }
        if (pl > 0 && ai == 0) {
          if (pl == setting.k - 1)
            score += 800; // prioritize blocks
          else if (pl == setting.k - 2) score += 400;
        }
      }

      map[e] = score;
    }

    var list = map.keys.toList()..sort((a, b) => -map[a]!.compareTo(map[b]!));
    if (list.isEmpty) list = empties;
    if (list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  List<Tile> _orderedCandidates(BoardState s, int limit) {
    // shared with fallback negamax
    return _orderAttacks(s, limit);
  }

  // ---- Eval / winner / overlay ----

  int _eval(BoardState s) {
    int score = 0;
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        if (_occ(s, t) != Side.none) continue;

        for (final line in s.getValidLinesThrough(t)) {
          int ai = 0, pl = 0;
          for (final q in line) {
            final sd = _occ(s, q);
            if (sd == setting.aiOpponentSide)
              ai++;
            else if (sd == setting.playerSide) pl++;
          }
          if (ai > 0 && pl > 0) continue;
          if (ai == 0) score += playerScoring[pl]; // defense
          if (pl == 0) score += aiScoring[ai]; // offense
        }
      }
    }
    return score;
  }

  Side? _terminalWinner(BoardState s) {
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final t = Tile(x, y);
        for (final line in s.getValidLinesThrough(t)) {
          int ai = 0, pl = 0;
          for (final q in line) {
            final sd = _occ(s, q);
            if (sd == setting.aiOpponentSide)
              ai++;
            else if (sd == setting.playerSide) pl++;
          }
          if (ai >= setting.k) return setting.aiOpponentSide;
          if (pl >= setting.k) return setting.playerSide;
        }
      }
    }
    return null;
  }

  final Map<Tile, Side> _overlay = {};
  Side _occ(BoardState s, Tile t) => _overlay[t] ?? s.whoIsAt(t);
  void _place(Tile t, Side side) => _overlay[t] = side;
  void _undo(Tile t) => _overlay.remove(t);

  // ---- utils ----
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

  int _occupiedCount(BoardState s) {
    int c = 0;
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

  Side _opp(Side s) =>
      (s == Side.x) ? Side.o : (s == Side.o ? Side.x : Side.none);

  static const int inf = 0x3fffffff;
  static const int winScore = 100000000;
}
