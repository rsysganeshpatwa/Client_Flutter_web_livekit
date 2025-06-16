import 'package:flutter/material.dart';

class BlinkingIndicator extends StatefulWidget {
  final bool isActive;

  const BlinkingIndicator({Key? key, required this.isActive}) : super(key: key);

  @override
  _BlinkingIndicatorState createState() => _BlinkingIndicatorState();
}

class _BlinkingIndicatorState extends State<BlinkingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true); // Repeats forever (for blinking)

    _opacityAnim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _scaleAnim = Tween<double>(begin: 0.6, end: 1.2).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BlinkingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.red.withOpacity(0.7), width: 2),
          ),
        ),
      ),
    );
  }
}
