import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../settings/settings.dart';

/// Opens a dialog to edit either Player 1 or Player 2's name.
void showCustomNameDialog(BuildContext context, {bool isSecondPlayer = false}) {
  showGeneralDialog(
    context: context,
    pageBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) =>
        CustomNameDialog(animation: animation, isSecondPlayer: isSecondPlayer),
  );
}

class CustomNameDialog extends StatefulWidget {
  final Animation<double> animation;
  final bool isSecondPlayer;

  const CustomNameDialog({
    required this.animation,
    this.isSecondPlayer = false,
    super.key,
  });

  @override
  State<CustomNameDialog> createState() => _CustomNameDialogState();
}

class _CustomNameDialogState extends State<CustomNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsController>();

    return ScaleTransition(
      scale: CurvedAnimation(
        parent: widget.animation,
        curve: Curves.easeOutCubic,
      ),
      child: SimpleDialog(
        title: Text('Change name'),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 12,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              if (widget.isSecondPlayer) {
                settings.setPlayer2Name(value);
              } else {
                settings.setPlayerName(value);
              }
            },
            onSubmitted: (value) {
              Navigator.pop(context);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    final settings = context.read<SettingsController>();
    _controller.text = widget.isSecondPlayer
        ? settings.player2Name.value
        : settings.playerName.value;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
