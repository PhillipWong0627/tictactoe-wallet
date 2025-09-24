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

  @override
  Widget build(BuildContext context) {
    final adsControllerAvailable = context.watch<AdsController?>() != null;
    final palette = context.watch<Palette>();

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
            final ads = context.read<AdsController?>();
            if (ads == null) {
              GoRouter.of(context).pop(); // no ads controller, just continue
            } else {
              // Load + show; when the ad closes (or fails), pop.
              ads.loadInterstitialAd(onClose: () {
                GoRouter.of(context).pop();
              });
            }
          },
          textColor: palette.ink,
          child: const Text('Continue'),
        ),
      ),
    );
  }
}
