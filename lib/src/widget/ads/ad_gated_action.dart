import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tictactoe/src/ads/ads_controller.dart';
import 'package:tictactoe/src/style/dialog/dialog.dart'; // <-- for showConfirmProceedDialog

class AdGatedAction extends StatelessWidget {
  final Widget child;

  final bool enabled;

  /// Final check right before confirm/ad; returns true if the action can run now.
  final FutureOr<bool> Function(BuildContext context)? isAvailable;

  final VoidCallback? onUnavailable;
  final Future<bool> Function(BuildContext context)? onConfirm;
  final VoidCallback onAllowed;
  final VoidCallback? onCancelled;
  final bool requireConfirm;

  const AdGatedAction({
    super.key,
    required this.child,
    required this.onAllowed,
    this.enabled = true,
    this.isAvailable,
    this.onUnavailable,
    this.onConfirm,
    this.onCancelled,
    this.requireConfirm = true,
  });

  Future<void> _run(BuildContext context) async {
    if (isAvailable != null) {
      final ok = await Future.value(isAvailable!(context));
      if (!ok) {
        onUnavailable?.call();
        return;
      }
    }
    if (requireConfirm) {
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
    return Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: InkWell(onTap: () => _run(context), child: child));
  }
}
