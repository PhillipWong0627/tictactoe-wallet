import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class PreloadedBannerAd {
  /// Something like [AdSize.mediumRectangle].
  final AdSize size;

  final AdRequest _adRequest;

  BannerAd? _bannerAd;

  final String adUnitId;

  final _adCompleter = Completer<BannerAd>();

  PreloadedBannerAd({
    required this.size,
    required this.adUnitId,
    AdRequest? adRequest,
  }) : _adRequest = adRequest ?? const AdRequest();

  Future<BannerAd> get ready => _adCompleter.future;

  Future<void> load() {
    assert(Platform.isAndroid || Platform.isIOS,
        'AdMob currently does not support ${Platform.operatingSystem}');

    _bannerAd = BannerAd(
      // This is a test ad unit ID from
      // https://developers.google.com/admob/android/test-ads. When ready,
      // you replace this with your own, production ad unit ID,
      // created in https://apps.admob.com/.
      adUnitId: adUnitId,
      size: size,
      request: _adRequest,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[INFO] Ad loaded: ${_bannerAd.hashCode}');

          _adCompleter.complete(_bannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[WARNING] Banner failedToLoad: $error');

          _adCompleter.completeError(error);
          ad.dispose();
        },
        onAdImpression: (ad) {
          debugPrint('[INFO] Ad impression registered');
        },
        onAdClicked: (ad) {
          debugPrint('[INFO] Ad click registered');
        },
      ),
    );

    return _bannerAd!.load();
  }

  void dispose() {
    debugPrint('[INFO] preloaded banner ad being disposed');

    _bannerAd?.dispose();
  }
}
