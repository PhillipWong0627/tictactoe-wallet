// lib/src/style/coins.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

enum CoinIcon { generic, btc, eth, base, xrp }

Widget coinIcon(CoinIcon c) {
  switch (c) {
    case CoinIcon.btc:
      return SvgPicture.asset('assets/coins/btc-logo.svg');
    case CoinIcon.eth:
      return SvgPicture.asset('assets/coins/eth-logo.svg');
    case CoinIcon.base:
      return Image.asset('assets/coins/base.png');
    case CoinIcon.xrp:
      return SvgPicture.asset('assets/coins/xrp-logo.svg');
    case CoinIcon.generic:
      return Image.asset('assets/coins/icon-tux-dark.png');
  }
}
