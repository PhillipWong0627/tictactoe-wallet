import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tictactoe/gen/assets.gen.dart';
import 'package:tictactoe/src/audio/audio_controller.dart';
import 'package:tictactoe/src/audio/sounds.dart';
import 'package:tictactoe/src/style/palette.dart';

class RoughButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? textColor;
  final bool drawRectangle;
  final double fontSize;
  final SfxType soundEffect;

  /// NEW: Disable the button externally (e.g., when ad is loading).
  final bool disabled;

  /// NEW: Show a small progress indicator when [disabled] is true.
  final bool showBusyWhenDisabled;

  /// NEW: Slight scale-down on press.
  final double pressedScale;

  /// NEW: Animation duration for the press animation.
  final Duration pressAnimDuration;

  /// NEW: Prevents same-frame double taps. If true, the button locks itself
  /// for [tapLockDuration] after a successful tap.
  final bool lockOnTap;

  /// NEW: How long the internal tap lock should last.
  final Duration tapLockDuration;

  const RoughButton({
    super.key,
    required this.child,
    required this.onTap,
    this.textColor,
    this.fontSize = 32,
    this.drawRectangle = false,
    this.soundEffect = SfxType.buttonTap,

    // new defaults
    this.disabled = false,
    this.showBusyWhenDisabled = false,
    this.pressedScale = 0.96,
    this.pressAnimDuration = const Duration(milliseconds: 140),
    this.lockOnTap = true,
    this.tapLockDuration = const Duration(milliseconds: 500),
  });

  @override
  State<RoughButton> createState() => _RoughButtonState();
}

class _RoughButtonState extends State<RoughButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.pressAnimDuration);
    _scale = Tween<double>(begin: 1.0, end: widget.pressedScale)
        .animate(_controller);
  }

  @override
  void didUpdateWidget(covariant RoughButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressAnimDuration != widget.pressAnimDuration) {
      _controller.duration = widget.pressAnimDuration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _enabled {
    // enabled only if: has onTap AND not externally disabled AND not locally locked
    return widget.onTap != null && !widget.disabled && !_locked;
  }

  void _animateDown() {
    if (_enabled) _controller.forward();
  }

  void _animateUp() {
    _controller.reverse();
  }

  void _handleTap() {
    if (!_enabled) return;

    // local lock to kill same-frame double taps
    if (widget.lockOnTap) {
      setState(() => _locked = true);
      Future.delayed(widget.tapLockDuration, () {
        if (!mounted) return;
        setState(() => _locked = false);
      });
    }

    // play sfx
    final audioController = context.read<AudioController>();
    audioController.playSfx(widget.soundEffect);

    // call user handler
    widget.onTap!.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();
    final baseColor = widget.textColor ?? palette.ink;

    final effectiveEnabled = _enabled;
    final textColor = effectiveEnabled
        ? baseColor
        : baseColor.withValues(alpha: 0.55); // dim when disabled/locked

    return GestureDetector(
      onTapDown: (_) => _animateDown(),
      onTapCancel: () => _animateUp(),
      onTapUp: (_) => _animateUp(),
      onTap: _handleTap,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                if (widget.drawRectangle) Assets.images.bar.image(),
                DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: 'Permanent Marker',
                    fontSize: widget.fontSize,
                    color: textColor,
                  ),
                  child: widget.child,
                ),
              ],
            ),
          ),

          // Optional busy indicator when disabled/busy
          if (widget.showBusyWhenDisabled && (widget.disabled || _locked))
            const Positioned(
              right: 12,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}
