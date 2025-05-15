import 'package:flutter/material.dart';

class TrianglePainter extends CustomPainter {
  final bool isRight;

  TrianglePainter({required this.isRight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final path = Path();

    if (isRight) {
      // Triangle pointing right
      path.moveTo(size.width * 0.35, size.height * 0.25);
      path.lineTo(size.width * 0.35, size.height * 0.75);
      path.lineTo(size.width * 0.65, size.height * 0.5);
    } else {
      // Triangle pointing left
      path.moveTo(size.width * 0.65, size.height * 0.25);
      path.lineTo(size.width * 0.65, size.height * 0.75);
      path.lineTo(size.width * 0.35, size.height * 0.5);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
