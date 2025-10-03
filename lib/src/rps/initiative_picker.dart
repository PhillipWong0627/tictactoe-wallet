// lib/src/rps/initiative_picker.dart
import 'package:flutter/material.dart';

Future<bool?> showInitiativeBottomSheet(
  BuildContext context, {
  required bool initialRps,
}) {
  bool temp = initialRps;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: false,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setStateSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Who moves style',
                  style:
                      TextStyle(fontFamily: 'Permanent Marker', fontSize: 22),
                ),
                const SizedBox(height: 8),
                ToggleButtons(
                  isSelected: [temp == true, temp == false],
                  onPressed: (i) {
                    final picked = (i == 0); // true = RPS, false = Classic
                    setStateSheet(() => temp = picked);
                    Navigator.of(ctx).pop(picked); // <- instant return
                  },
                  children: const [
                    Padding(padding: EdgeInsets.all(12), child: Text('RPS')),
                    Padding(
                        padding: EdgeInsets.all(12), child: Text('Classic')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
