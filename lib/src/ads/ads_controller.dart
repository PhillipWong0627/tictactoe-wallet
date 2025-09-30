import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tictactoe/src/ads/ad_ids.dart';
import 'package:tictactoe/src/ads/ad_ids.dart';

import 'preloaded_banner_ad.dart';

/// Allows showing ads. A facade for `package:google_mobile_ads`.
class AdsController {
  final MobileAds _instance;

  PreloadedBannerAd? _preloadedAd;

  //Interstitial
  InterstitialAd? interstitialAd;
  bool isInterstitialAdReady = false;
  // Spam guard
  bool _busy = false;
  bool get isAdBusy => _busy;

  static Future<InitializationStatus> initMobileAds() {
    return MobileAds.instance.initialize();
  }

  void loadInterstitialAd({VoidCallback? onClose}) {
    if (_busy) return; // Guard against spam
    if (_busy) return; // Guard against spam
    _busy = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          interstitialAd = ad;
          isInterstitialAdReady = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (adsDismissed) {
              adsDismissed.dispose();
              interstitialAd = null;

              isInterstitialAdReady = false;
              _busy = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onClose?.call();
              });
            },
            onAdFailedToShowFullScreenContent: (adFailed, error) {
              adFailed.dispose();
              interstitialAd = null;
              isInterstitialAdReady = false;
              _busy = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onClose?.call();
              });
            },
          );

          showInterstitialAd();
        },
        onAdFailedToLoad: (loadError) {
          log('InterstitialAd failed to load: $loadError');
          isInterstitialAdReady = false;
          interstitialAd?.dispose();
          interstitialAd = null;
          _busy = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onClose?.call();
          });
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (isInterstitialAdReady && interstitialAd != null) {
      interstitialAd?.show();
    } else {
      _busy = false;
    }
  }

  /// Creates an [AdsController] that wraps around a [MobileAds] [instance].
  ///
  /// Example usage:
  ///
  ///     var controller = AdsController(MobileAds.instance);
  AdsController(MobileAds instance) : _instance = instance;

  void dispose() {
    interstitialAd?.dispose();
    _preloadedAd?.dispose();
  }

  /// Initializes the injected [MobileAds.instance].
  Future<void> initialize() async {
    await _instance.initialize();
  }

  /// Starts preloading an ad to be used later.
  ///
  /// The work doesn't start immediately so that calling this doesn't have
  /// adverse effects (jank) during start of a new screen.
  void preloadAd() {
    final adUnitId = defaultTargetPlatform == TargetPlatform.android
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-3940256099942544/6300978111';
    _preloadedAd =
        PreloadedBannerAd(size: AdSize.mediumRectangle, adUnitId: adUnitId);

    // Wait a bit so that calling at start of a new screen doesn't have
    // adverse effects on performance.
    Future<void>.delayed(const Duration(seconds: 1)).then((_) {
      return _preloadedAd!.load();
    });
  }

  /// Allows caller to take ownership of a [PreloadedBannerAd].
  ///
  /// If this method returns a non-null value, then the caller is responsible
  /// for disposing of the loaded ad.
  PreloadedBannerAd? takePreloadedAd() {
    final ad = _preloadedAd;
    _preloadedAd = null;
    return ad;
  }
}
