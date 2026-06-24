import 'dart:async';

import 'package:flutter/material.dart';

class SmoothReveal extends StatefulWidget {
  const SmoothReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 16),
    this.duration = const Duration(milliseconds: 520),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;
  final Curve curve;

  @override
  State<SmoothReveal> createState() => _SmoothRevealState();
}

class _SmoothRevealState extends State<SmoothReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curved);
    _scale = Tween<double>(begin: 0.985, end: 1).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, _controller.forward);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _slide.value,
            child: Transform.scale(scale: _scale.value, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
