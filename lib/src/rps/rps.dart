enum RpsChoice { rock, paper, scissors }

enum RpsWinner { player, ai, tie }

RpsWinner rpsResult(RpsChoice player, RpsChoice ai) {
  if (player == ai) return RpsWinner.tie;
  switch (player) {
    case RpsChoice.rock:
      return (ai == RpsChoice.scissors) ? RpsWinner.player : RpsWinner.ai;
    case RpsChoice.paper:
      return (ai == RpsChoice.rock) ? RpsWinner.player : RpsWinner.ai;
    case RpsChoice.scissors:
      return (ai == RpsChoice.paper) ? RpsWinner.player : RpsWinner.ai;
  }
}
