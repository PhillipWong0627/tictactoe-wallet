import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tictactoe/src/ads/ads_controller.dart';
import 'package:tictactoe/src/style/dialog/dialog.dart'; // <-- for showConfirmProceedDialog

class AdGatedAction extends StatelessWidget {
  final Widget child;
  final Future<bool> Function(BuildContext context)? onConfirm; // optional
  final VoidCallback onAllowed;
  final VoidCallback? onCancelled;
  final bool requireConfirm;

  const AdGatedAction({
    super.key,
    required this.child,
    required this.onAllowed,
    this.onCancelled,
    this.onConfirm,
    this.requireConfirm = true,
  });

  Future<void> _run(BuildContext context) async {
    if (requireConfirm) {
      // Prefer custom confirm if provided; otherwise use your shared dialog
      final ok = await (onConfirm?.call(context) ??
          showConfirmProceedDialog(
            context,
            title: 'Watch Ad?',
            message: 'Watch an ad to continue?',
            confirmText: 'Watch Ad',
            cancelText: 'Cancel',
            icon: Icons.ondemand_video,
          ));
      if (!ok) {
        onCancelled?.call();
        return;
      }
    }

    final ads = context.read<AdsController?>();
    if (ads == null) {
      onAllowed();
      return;
    }
    ads.loadInterstitialAd(onClose: onAllowed);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: () => _run(context), child: child);
  }
}
