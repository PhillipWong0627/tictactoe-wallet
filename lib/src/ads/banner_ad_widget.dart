import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:tictactoe/src/ads/ad_ids.dart';

import 'ads_controller.dart';
import 'preloaded_banner_ad.dart';

/// Displays a banner ad that conforms to the widget's size in the layout,
/// and reloads the ad when the user changes orientation.
///
/// Do not use this widget on platforms that AdMob currently doesn't support.
/// For example:
///
/// ```dart
/// if (kIsWeb) {
///   return Text('No ads here! (Yet.)');
/// } else {
///   return MyBannerAd();
/// }
/// ```
///
/// This widget is adapted from pkg:google_mobile_ads's example code,
/// namely the `anchored_adaptive_example.dart` file:
/// https://github.com/googleads/googleads-mobile-flutter/blob/main/packages/google_mobile_ads/example/lib/anchored_adaptive_example.dart
class BannerAdWidget extends StatefulWidget {
  /// If true, uses Anchored Adaptive banner (recommended).
  final bool useAdaptive;

  /// Fallback when adaptive size isn't available. Defaults to 320x50 banner.
  final AdSize fallbackSize;

  /// Optional top/bottom horizontal padding you might have in the layout.
  /// This is subtracted from screen width for better adaptive sizing.
  final EdgeInsets safeAreaPadding;

  const BannerAdWidget({
    super.key,
    this.useAdaptive = true,
    this.fallbackSize = AdSize.banner, // 320x50 (smaller than MREC)
    this.safeAreaPadding = EdgeInsets.zero,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  _LoadingState _adLoadingState = _LoadingState.initial;

  late Orientation _currentOrientation;

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (_currentOrientation == orientation &&
            _bannerAd != null &&
            _adLoadingState == _LoadingState.loaded) {
          debugPrint(
              '[INFO] We have everything we need. Showing the ad ${_bannerAd.hashCode} now.');

          return SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          );
        }
        // Reload the ad if the orientation changes.
        if (_currentOrientation != orientation) {
          debugPrint('[INFO] Orientation changed.');

          _currentOrientation = orientation;
          _loadAd();
        }
        return const SizedBox();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentOrientation = MediaQuery.of(context).orientation;
  }

  @override
  void dispose() {
    debugPrint('[INFO] Disposing ad.');

    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final adsController = context.read<AdsController>();
    final ad = adsController.takePreloadedAd();
    if (ad != null) {
      debugPrint('[INFO] A preloaded banner was supplied. Using it.');

      _showPreloadedAd(ad);
    } else {
      _loadAd();
    }
  }

  /// Load (another) ad, disposing of the current ad if there is one.
  Future<void> _loadAd() async {
    if (!mounted) return;
    debugPrint('[INFO] _loadAd() called.');

    if (_adLoadingState == _LoadingState.loading ||
        _adLoadingState == _LoadingState.disposing) {
      debugPrint('[INFO] An ad is already being loaded or disposed. Aborting.');

      return;
    }
    _adLoadingState = _LoadingState.disposing;
    await _bannerAd?.dispose();
    debugPrint('[FINE] _bannerAd disposed.');

    if (!mounted) return;

    setState(() {
      _bannerAd = null;
      _adLoadingState = _LoadingState.loading;
    });

    // AdSize size;
    AdSize size = widget.fallbackSize;

    if (widget.useAdaptive) {
      // Compute available width (subtract padding if your layout has it).
      final screenWidth = MediaQuery.of(context).size.width;
      final availableWidth = (screenWidth -
              widget.safeAreaPadding.left -
              widget.safeAreaPadding.right)
          .truncate();

      final AnchoredAdaptiveBannerAdSize? adaptiveSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
              availableWidth);

      if (adaptiveSize == null) {
        debugPrint(
            '[WARNING] Unable to get height of anchored adaptive banner. Falling back to ${widget.fallbackSize.width}x${widget.fallbackSize.height}.');
      } else {
        debugPrint(
            '[INFO] Falling back to ${widget.fallbackSize.width}x${widget.fallbackSize.height}.');

        size = adaptiveSize;
      }
    }

    if (!mounted) return;

    assert(Platform.isAndroid || Platform.isIOS,
        'AdMob currently does not support ${Platform.operatingSystem}');
    _bannerAd = BannerAd(
      // This is a test ad unit ID from
      // https://developers.google.com/admob/android/test-ads. When ready,
      // you replace this with your own, production ad unit ID,
      // created in https://apps.admob.com/.
      adUnitId: AdIds.banner(),
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint(
              '[INFO] Ad loaded: ${ad.responseInfo} (${(ad as BannerAd).size.width}x${ad.size.height}) ');

          setState(() {
            // When the ad is loaded, get the ad size and use it to set
            // the height of the ad container.
            _bannerAd = ad;
            _adLoadingState = _LoadingState.loaded;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[WARNING] Banner failedToLoad: $error ');

          ad.dispose();
          if (mounted) {
            setState(() => _adLoadingState = _LoadingState.initial);
          }
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

  Future<void> _showPreloadedAd(PreloadedBannerAd ad) async {
    // It's possible that the banner is still loading (even though it started
    // preloading at the start of the previous screen).
    _adLoadingState = _LoadingState.loading;
    try {
      _bannerAd = await ad.ready;
    } on LoadAdError catch (error) {
      debugPrint('[SEVERE] Error when loading preloaded banner: $error');

      unawaited(_loadAd());
      return;
    }
    if (!mounted) return;

    setState(() => _adLoadingState = _LoadingState.loaded);
  }
}

enum _LoadingState {
  /// The state before we even start loading anything.
  initial,

  /// The ad is being loaded at this point.
  loading,

  /// The previous ad is being disposed of. After that is done, the next
  /// ad will be loaded.
  disposing,

  /// An ad has been loaded already.
  loaded,
}
