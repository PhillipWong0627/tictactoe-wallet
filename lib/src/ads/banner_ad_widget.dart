import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';
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
  static final _log = Logger('BannerAdWidget');

  static const useAnchoredAdaptiveSize = false;
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
          _log.info(() => 'We have everything we need. Showing the ad '
              '${_bannerAd.hashCode} now.');
          return SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          );
        }
        // Reload the ad if the orientation changes.
        if (_currentOrientation != orientation) {
          _log.info('Orientation changed');
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
    _log.info('disposing ad');
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final adsController = context.read<AdsController>();
    final ad = adsController.takePreloadedAd();
    if (ad != null) {
      _log.info("A preloaded banner was supplied. Using it.");
      _showPreloadedAd(ad);
    } else {
      _loadAd();
    }
  }

  /// Load (another) ad, disposing of the current ad if there is one.
  Future<void> _loadAd() async {
    if (!mounted) return;
    _log.info('_loadAd() called.');
    if (_adLoadingState == _LoadingState.loading ||
        _adLoadingState == _LoadingState.disposing) {
      _log.info('An ad is already being loaded or disposed. Aborting.');
      return;
    }
    _adLoadingState = _LoadingState.disposing;
    await _bannerAd?.dispose();
    _log.fine('_bannerAd disposed');
    if (!mounted) return;

    setState(() {
      _bannerAd = null;
      _adLoadingState = _LoadingState.loading;
    });

    // AdSize size;
    AdSize size = widget.fallbackSize;

    // if (useAnchoredAdaptiveSize) {
    //   final AnchoredAdaptiveBannerAdSize? adaptiveSize =
    //       await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
    //           MediaQuery.of(context).size.width.truncate());

    //   if (adaptiveSize == null) {
    //     _log.warning('Unable to get height of anchored banner.');
    //     size = AdSize.banner;
    //   } else {
    //     _log.info('normal anchored banner.');

    //     size = adaptiveSize;
    //   }
    // } else {
    //   size = AdSize.mediumRectangle;
    // }
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
        _log.warning('Unable to get height of anchored adaptive banner. '
            'Falling back to ${widget.fallbackSize.width}x${widget.fallbackSize.height}.');
      } else {
        _log.info(
            'Falling back to ${widget.fallbackSize.width}x${widget.fallbackSize.height}.');

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
          _log.info(() => 'Ad loaded: ${ad.responseInfo} '
              '(${(ad as BannerAd).size.width}x${ad.size.height})');
          setState(() {
            // When the ad is loaded, get the ad size and use it to set
            // the height of the ad container.
            _bannerAd = ad as BannerAd;
            _adLoadingState = _LoadingState.loaded;
          });
        },
        onAdFailedToLoad: (ad, error) {
          _log.warning('Banner failedToLoad: $error');
          ad.dispose();
          if (mounted) {
            setState(() => _adLoadingState = _LoadingState.initial);
          }
        },
        onAdImpression: (ad) {
          _log.info('Ad impression registered');
        },
        onAdClicked: (ad) {
          _log.info('Ad click registered');
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
      _log.severe('Error when loading preloaded banner: $error');
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
