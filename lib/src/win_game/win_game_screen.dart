import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../ads/ads_controller.dart';
import '../ads/banner_ad_widget.dart';
import '../games_services/score.dart';
import '../style/palette.dart';
import '../style/responsive_screen.dart';
import '../style/rough/button.dart';

class WinGameScreen extends StatefulWidget {
  final Score score;

  const WinGameScreen({
    super.key,
    required this.score,
  });

  @override
  State<WinGameScreen> createState() => _WinGameScreenState();
}

class _WinGameScreenState extends State<WinGameScreen> {
  @override
  void initState() {
    super.initState();
  }

  final _rng = math.Random(); // reuse the same RNG

  @override
  Widget build(BuildContext context) {
    final adsControllerAvailable = context.watch<AdsController?>() != null;
    final palette = context.watch<Palette>();
    final ads = context.watch<AdsController?>();
    final adBusy = ads?.isAdBusy ?? false;

    return Scaffold(
      backgroundColor: palette.backgroundPlaySession,
      body: ResponsiveScreen(
        squarishMainArea: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (adsControllerAvailable)
              Center(
                child: BannerAdWidget(
                  useAdaptive: false,
                  fallbackSize: AdSize.mediumRectangle,
                ),
              ),
            const SizedBox(height: 15),
            const Center(
              child: Text(
                'You won!',
                style: TextStyle(
                  fontFamily: 'Permanent Marker',
                  fontSize: 50,
                ),
              ),
            ),
            Center(
              child: Text(
                'Score: ${widget.score.score}\n'
                'Time: ${widget.score.formattedTime}\n'
                'Difficulty: ${widget.score.difficulty}',
                style: const TextStyle(
                  fontFamily: 'Permanent Marker',
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        rectangularMenuArea: RoughButton(
          onTap: () {
            // 30% chance to show an interstitial, else just pop
            const p = 0.30;
            final roll = _rng.nextDouble(); // ← sample once
            developer.log('interstitial roll=$roll (p=$p)');

            // Show interstitial only if roll < p
            if (roll < p) {
              final controller = context.read<AdsController?>();
              if (controller != null) {
                controller.loadInterstitialAd(onClose: () {
                  if (!context.mounted) return;
                  GoRouter.of(context).pop();
                });
                return; // don't fall through
              }
            }
            // No controller or roll >= p → just continue
            GoRouter.of(context).pop();
          },
          disabled: adBusy, // blocks taps while ad is loading/showing
          showBusyWhenDisabled: true, // tiny spinner at the right

          textColor: palette.ink,
          child: const Text('Continue'),
        ),
      ),
    );
  }
}
