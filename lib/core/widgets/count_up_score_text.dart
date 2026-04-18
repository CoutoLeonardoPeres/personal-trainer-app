import 'package:flutter/material.dart';

String formatScoreDisplay(double v) {
  if (v == 0) return '0';
  if ((v - v.round()).abs() < 1e-6) return '${v.round()}';
  return v.toStringAsFixed(1);
}

/// Anima o valor numérico até [target] (reinicia quando [target] muda).
class CountUpScoreText extends StatefulWidget {
  const CountUpScoreText({
    super.key,
    required this.target,
    this.style,
    this.duration = const Duration(milliseconds: 750),
    this.format = formatScoreDisplay,
  });

  final double target;
  final TextStyle? style;
  final Duration duration;
  final String Function(double) format;

  @override
  State<CountUpScoreText> createState() => _CountUpScoreTextState();
}

class _CountUpScoreTextState extends State<CountUpScoreText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _animation;
  double _display = 0;

  void _beginTween(double begin, double end) {
    _animation?.removeListener(_onTick);
    _display = begin;
    _animation = Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(_onTick);
  }

  void _onTick() {
    if (_animation != null) {
      setState(() => _display = _animation!.value);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _beginTween(0, widget.target);
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountUpScoreText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if ((oldWidget.target - widget.target).abs() > 1e-9) {
      _controller.stop();
      _controller.reset();
      _beginTween(_display, widget.target);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _animation?.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(widget.format(_display), style: widget.style);
  }
}
