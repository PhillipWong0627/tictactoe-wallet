import 'dart:ui';
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
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: const SizedBox.expand(),
            ),
          ),
          Center(child: _LiveNameDialog(animation: a)),
        ],
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _LiveNameDialog extends StatefulWidget {
  const _LiveNameDialog({required this.animation});
  final Animation<double> animation;

  @override
  State<_LiveNameDialog> createState() => _LiveNameDialogState();
}

class _LiveNameDialogState extends State<_LiveNameDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void didChangeDependencies() {
    final settings = context.read<SettingsController>();
    _controller.text = widget.isSecondPlayer
        ? settings.player2Name.value
        : settings.playerName.value;
    super.didChangeDependencies();
    // Auto-focus
    Future.microtask(() => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          decoration: ShapeDecoration(
            color: cs.surface.withValues(alpha: 0.96),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            shadows: [
              BoxShadow(
                blurRadius: 24,
                offset: const Offset(0, 10),
                color: Colors.black.withValues(alpha: 0.12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Change name',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                maxLength: 12,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                onChanged: (value) {
                  context.read<SettingsController>().setPlayerName(value);
                },
                onSubmitted: (_) => Navigator.of(context).maybePop(),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  filled: true,
                  fillColor: cs.surfaceContainer.withValues(alpha: 0.6),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
