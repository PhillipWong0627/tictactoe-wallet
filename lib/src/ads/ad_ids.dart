// lib/src/ads/ad_ids.dart
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class AdIds {
  static bool get _useTest => !kReleaseMode;

  static String banner() {
    if (_useTest) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Android test banner
          : 'ca-app-pub-3940256099942544/6300978111'; // iOS test banner
    }
    // Replace with production IDs
    return Platform.isAndroid
        ? 'ca-app-pub-3457855080577194/9115953980'
        : 'ca-app-pub-3457855080577194/7200237080';
  }

  static String interstitial() {
    if (_useTest) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712' // Android test interstitial
          : 'ca-app-pub-3940256099942544/1033173712'; // iOS test interstitial
    }
    // Replace with production IDs
    return Platform.isAndroid
        ? 'ca-app-pub-3457855080577194/3176397441'
        : 'ca-app-pub-3457855080577194/5400054345';
  }
}
