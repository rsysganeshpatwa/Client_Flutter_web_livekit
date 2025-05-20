import 'package:flutter/material.dart';
import 'dart:math' as math;

class NoVideoWidget extends StatelessWidget {
  final String name;

  const NoVideoWidget({
    super.key,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
   
    final circleColor = _getCircleColor(context);
    final textColor = _getTextColor(circleColor);

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[700], // background of the tile
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final size = math.min(constraints.maxHeight, constraints.maxWidth) / 2;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: circleColor,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: size / 2.5,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          );
        },
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Color _getCircleColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
   
    if (brightness == Brightness.light) {
      return Colors.blueGrey.shade200;
    } else {
      return Colors.indigo;
    }
  }

  Color _getTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
