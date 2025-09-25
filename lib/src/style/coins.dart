// lib/src/style/coins.dart
import 'package:flutter/material.dart';

enum CoinIcon { generic, btc, eth, sol }

Icon coinIcon(CoinIcon c) {
  switch (c) {
    case CoinIcon.btc:
      return const Icon(Icons.currency_bitcoin);
    // ETH/SOL don’t exist in Material Icons — use generic or your own assets for now:
    case CoinIcon.eth:
      return const Icon(Icons.toll_outlined);
    case CoinIcon.sol:
      return const Icon(Icons.circle_outlined);
    case CoinIcon.generic:
      return const Icon(Icons.monetization_on);
  }
}
