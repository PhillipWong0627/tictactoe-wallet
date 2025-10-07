import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Put this in MaterialApp.router(..., scaffoldMessengerKey: scaffoldMessengerKey)
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey(debugLabel: 'scaffoldMessengerKey');

/// High-level variants for quick calls
enum SnackKind { info, success, warning, error }

/// Main entry: Reusable snackbar.
/// Example:
///   showSnack('Saved!', kind: SnackKind.success);
Future<SnackBarClosedReason?> showSnack(
  String message, {
  SnackKind kind = SnackKind.info,
  String? title,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
  bool dismissCurrent = true,
  bool showClose = true,
  IconData? leading,
  EdgeInsets margin = const EdgeInsets.only(bottom: 24, left: 16, right: 16),
}) async {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return null;

  if (dismissCurrent) messenger.hideCurrentSnackBar();

  final context = messenger.context;
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  // Colors per kind
  final (bg, fg, icon) = switch (kind) {
    SnackKind.success => (
        cs.secondaryContainer,
        cs.onSecondaryContainer,
        Icons.check_circle_rounded
      ),
    SnackKind.warning => (
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
        Icons.warning_amber_rounded
      ),
    SnackKind.error => (
        cs.errorContainer,
        cs.onErrorContainer,
        Icons.error_rounded
      ),
    SnackKind.info => (
        cs.surfaceContainer,
        cs.onSurfaceVariant,
        Icons.info_rounded
      ),
  };

  // Allow override of icon if caller provided one
  final iconData = leading ?? icon;

  // Haptics per kind (soft for info/success, heavy for error)
  switch (kind) {
    case SnackKind.error:
      HapticFeedback.mediumImpact();
      break;
    case SnackKind.warning:
      HapticFeedback.selectionClick();
      break;
    default:
      HapticFeedback.selectionClick();
  }

  final label = title ?? _defaultTitle(kind);

  final content = Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(iconData, color: fg),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty)
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (label.isNotEmpty) const SizedBox(height: 2),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    ],
  );

  final sb = SnackBar(
    content: content,
    behavior: SnackBarBehavior.floating,
    margin: margin,
    dismissDirection: DismissDirection.horizontal,
    backgroundColor: bg,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    duration: duration ??
        switch (kind) {
          SnackKind.error => const Duration(seconds: 5),
          SnackKind.warning => const Duration(seconds: 4),
          _ => const Duration(seconds: 3),
        },
    showCloseIcon: showClose,
    closeIconColor: fg,
    action: (actionLabel != null && onAction != null)
        ? SnackBarAction(
            label: actionLabel,
            onPressed: onAction,
            textColor: fg,
          )
        : null,
  );

  return messenger.showSnackBar(sb).closed;
}

/// Convenience wrappers
Future<SnackBarClosedReason?> showInfoSnack(String message,
        {String? title, String? actionLabel, VoidCallback? onAction}) =>
    showSnack(message,
        kind: SnackKind.info,
        title: title,
        actionLabel: actionLabel,
        onAction: onAction);

Future<SnackBarClosedReason?> showSuccessSnack(String message,
        {String? title, String? actionLabel, VoidCallback? onAction}) =>
    showSnack(message,
        kind: SnackKind.success,
        title: title,
        actionLabel: actionLabel,
        onAction: onAction);

Future<SnackBarClosedReason?> showWarningSnack(String message,
        {String? title, String? actionLabel, VoidCallback? onAction}) =>
    showSnack(message,
        kind: SnackKind.warning,
        title: title,
        actionLabel: actionLabel,
        onAction: onAction);

Future<SnackBarClosedReason?> showErrorSnack(String message,
        {String? title, String? actionLabel, VoidCallback? onAction}) =>
    showSnack(message,
        kind: SnackKind.error,
        title: title,
        actionLabel: actionLabel,
        onAction: onAction);

String _defaultTitle(SnackKind k) => switch (k) {
      SnackKind.success => 'Success',
      SnackKind.warning => 'Heads up',
      SnackKind.error => 'Error',
      SnackKind.info => '',
    };
