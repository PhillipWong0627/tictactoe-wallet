import 'package:tictactoe/src/ai/minimax_opponent.dart';
import 'package:tictactoe/src/ai/threat_minimax_opponent.dart';

import '../ai/ai_opponent.dart';
import '../ai/humanlike_opponent.dart';
import '../ai/random_opponent.dart';
import '../ai/scoring_opponent.dart';
import '../game_internals/board_setting.dart';

final gameLevels = [
  GameLevel(
    number: 1,
    setting: const BoardSetting(3, 3, 3),
    difficulty: 1,
    aiOpponentBuilder: (setting) => RandomOpponent(
      setting,
      name: 'Blobfish',
    ),
    achievementIdIOS: 'first_win',
    achievementIdAndroid: 'CgkIgZ29mawJEAIQAg',
  ),
  GameLevel(
    number: 2,
    setting: const BoardSetting(5, 5, 4),
    difficulty: 2,
    aiOpponentBuilder: (setting) => HumanlikeOpponent(
      setting,
      name: 'Chicken',
      humanlikePlayCount: 50,
      bestPlayCount: 5,
      // Heavily defense-focused.
      playerScoring: const [30, 100, 500, 10000, 100000, 0],
      aiScoring: const [1, 1, 10, 90, 8000, 0],
    ),
  ),
  GameLevel(
    number: 3,
    setting: const BoardSetting(6, 6, 4),
    difficulty: 3,
    aiOpponentBuilder: (setting) => HumanlikeOpponent(
      setting,
      name: 'Sparklemuffin',
      humanlikePlayCount: 5,
      bestPlayCount: 3,
    ),
  ),
  GameLevel(
    number: 4,
    setting: const BoardSetting(8, 8, 5),
    difficulty: 4,
    aiOpponentBuilder: (setting) => AttackOnlyScoringOpponent(
      setting,
      name: 'Puffbird',
    ),
  ),
  GameLevel(
    number: 5,
    setting: const BoardSetting(9, 9, 5, aiStarts: true),
    difficulty: 5,
    aiOpponentBuilder: (setting) => HumanlikeOpponent(
      setting,
      name: 'Gecko',
      humanlikePlayCount: 3,
      bestPlayCount: 12,
      stubbornness: 0.10,
    ),
    achievementIdIOS: 'half_way',
    achievementIdAndroid: 'CgkIgZ29mawJEAIQAw',
  ),
  GameLevel(
    number: 6,
    setting: const BoardSetting(9, 9, 5),
    difficulty: 6,
    aiOpponentBuilder: (setting) => HumanlikeOpponent(
      setting,
      name: 'Wobbegong',
      humanlikePlayCount: 2,
      bestPlayCount: 10,
      stubbornness: 0.1,
    ),
  ),
  GameLevel(
    number: 7,
    setting: const BoardSetting(10, 10, 5),
    difficulty: 7,
    aiOpponentBuilder: (setting) => HumanlikeOpponent(
      setting,
      name: 'Boops',
      humanlikePlayCount: 3,
      bestPlayCount: 5,
    ),
  ),
  GameLevel(
    number: 8,
    setting: const BoardSetting(10, 10, 5),
    difficulty: 8,
    aiOpponentBuilder: (setting) => HumanlikeOpponent(
      setting,
      name: 'Fossa',
      humanlikePlayCount: 4,
      bestPlayCount: 5,
    ),
  ),
  GameLevel(
    number: 9,
    setting: const BoardSetting(11, 11, 5),
    difficulty: 20,
    aiOpponentBuilder: (setting) => HumanlikeOpponent(
      setting,
      name: 'Tiger',
      humanlikePlayCount: 10,
      bestPlayCount: 2,
    ),
    achievementIdIOS: 'finished',
    achievementIdAndroid: 'CgkIgZ29mawJEAIQBA',
  ),
  // GameLevel(
  //   number: 10,
  //   setting: const BoardSetting(15, 15, 5), // 大盘 k=5
  //   difficulty: 99,
  //   aiOpponentBuilder: (setting) => HumanlikeOpponent(
  //     setting,
  //     name: 'Grandmaster',
  //     // 让“最优解”主导：先看 bestPlay，再看 humanlike 的交集
  //     bestPlayCount: 2, // 只保留最强的少数候选
  //     humanlikePlayCount: 50, // 允许做人味筛选，但很难盖过最优解
  //     stubbornness: 0.0, // 绝不执着于上一步位置

  //     // 高强度防守与进攻：k=5 时，对 k-1/k-2 赋予极高分
  //     playerScoring: const [
  //       1, // 玩家在该线有0子：轻微威胁
  //       40, // 1连
  //       200, // 2连
  //       2000, // 3连（要重视）
  //       2000000, // 4连（必须堵）
  //       0, // 完成线，不再计分
  //     ],
  //     aiScoring: const [
  //       2, // 我方0子：轻微潜力
  //       60, // 1连
  //       300, // 2连
  //       3000, // 3连（强势推进）
  //       3000000, // 4连（马上赢，极大权重）
  //       0,
  //     ],
  //   ),
  //   achievementIdIOS: 'grandmaster_cleared',
  //   achievementIdAndroid: 'CgkIgZ29mawJEAIQCA',
  // ),
  GameLevel(
    number: 10,
    setting: const BoardSetting(15, 15, 5), // 大盘 k=5
    difficulty: 150,
    aiOpponentBuilder: (setting) => ThreatMinimaxOpponent(
      setting,
      name: 'ThreatMaster',
      maxDepth: 4, // hard; try 3 if slow on older phones
      timeLimitMs: 140, // tune 120–180ms
      maxCandidates: 12,
      proximityRadius: 2,
      playerScoring: const [1, 60, 400, 10000, 2000000, 0],
      aiScoring: const [2, 80, 600, 12000, 3000000, 0],
    ),
    achievementIdIOS: 'threat_master',
    achievementIdAndroid: 'CgkIgZ29mawJEAIQDw',
  ),
  GameLevel(
    number: 11,
    setting:
        const BoardSetting(15, 15, 5, aiStarts: true), // big board, AI opens
    difficulty: 150,
    aiOpponentBuilder: (setting) => ThreatMinimaxOpponent(
      setting,
      name: 'ThreatMaster',
      maxDepth: 4, // hard; try 3 if slow on older phones
      timeLimitMs: 300, // tune 120–180ms
      maxCandidates: 12,
      proximityRadius: 2,
      playerScoring: const [1, 60, 400, 10000, 2000000, 0],
      aiScoring: const [2, 80, 600, 12000, 3000000, 0],
    ),
    achievementIdIOS: 'vct_clear',
    achievementIdAndroid: 'CgkIgZ29mawJEAIQEA',
  ),
  GameLevel(
    number: 12,
    setting: const BoardSetting(15, 15, 5, aiStarts: true),
    difficulty: 120, // higher than Nightmare
    aiOpponentBuilder: (setting) => MinimaxOpponent(
      setting,
      name: 'Grandmaster+',
      depth: 4, // try 2 if device is slow; 4 if you dare
      maxCandidates: 16, // search width cap
      proximityRadius: 2,
      // crank weights for must-block/must-win
      playerScoring: const [1, 60, 400, 10000, 2000000, 0],
      aiScoring: const [2, 80, 600, 12000, 3000000, 0],
    ),
    achievementIdIOS: 'grandmaster_plus',
    achievementIdAndroid: 'CgkIgZ29mawJEAIQDQ',
  ),
];

class GameLevel {
  final int number;

  final BoardSetting setting;

  final int difficulty;

  final AiOpponent Function(BoardSetting) aiOpponentBuilder;

  /// The achievement to unlock when the level is finished, if any.
  final String? achievementIdIOS;

  final String? achievementIdAndroid;

  bool get awardsAchievement => achievementIdAndroid != null;

  const GameLevel({
    required this.number,
    required this.setting,
    required this.difficulty,
    required this.aiOpponentBuilder,
    this.achievementIdIOS,
    this.achievementIdAndroid,
  }) : assert(
            (achievementIdAndroid != null && achievementIdIOS != null) ||
                (achievementIdAndroid == null && achievementIdIOS == null),
            'Either both iOS and Android achievement ID must be provided, '
            'or none');
}
