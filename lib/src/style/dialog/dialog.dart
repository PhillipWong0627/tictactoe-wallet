import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tictactoe/src/style/palette.dart';

/// Shows a confirm dialog and returns true if user pressed Confirm.
Future<bool> showConfirmProceedDialog(
  BuildContext context, {
  String title = 'Are you sure?',
  String message = 'Do you want to proceed?',
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  IconData icon = Icons.help_outline,
}) async {
  final palette = context.read<Palette>(); // to keep your app theme consistent

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor:
            palette.backgroundLevelSelection.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(icon, color: palette.ink),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Permanent Marker',
                fontSize: 20,
                color: palette.ink,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontFamily: 'Permanent Marker',
            fontSize: 16,
            color: palette.ink,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).maybePop(false),
            child: Text(
              cancelText,
              style: TextStyle(
                fontFamily: 'Permanent Marker',
                color: palette.ink,
                fontSize: 16,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.redPen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).maybePop(true),
            child: Text(
              confirmText,
              style:
                  const TextStyle(fontFamily: 'Permanent Marker', fontSize: 16),
            ),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
