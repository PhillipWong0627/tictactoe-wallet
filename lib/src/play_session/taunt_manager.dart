import 'dart:math';

class TauntManager {
  final _rand = Random();
  DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);

  bool _cooldown() =>
      DateTime.now().difference(_lastShown) > const Duration(seconds: 8);

  String? maybeTaunt({required String event}) {
    if (!_cooldown()) return null;
    final pool = _taunts[event];
    if (pool == null || pool.isEmpty) return null;
    _lastShown = DateTime.now();
    return pool[_rand.nextInt(pool.length)];
  }

  static const _taunts = {
    // existing mid-game events if you want them later...
    'trap': [
      "Oops, I set a fork 😉",
      "Two ways to win… pick your poison.",
      "Check… mate soon?",
    ],
    'blunder': [
      "Are you sure about that? 😏",
      "I’ll pretend I didn’t see that.",
    ],
    'near_win': [
      "One more and it’s over 😎",
      "Smell that? Victory.",
    ],
    'near_block': [
      "Nice block! But can you block twice?",
    ],

    // For AI victory
    'ai_win': [
      "Good game! Better luck next time 😏",
      "TicTacWIN achieved.",
      "I warned you about the fork 👀",
      "Victory dance! 💃🕺",
      "Outplayed and out-TicTac-Toed.",
      "Resistance was futile.",
    ],
  };
}
