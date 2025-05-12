import 'package:flutter/material.dart';
import 'dart:math' as math;

class NoVideoWidget extends StatelessWidget {
  //
  const NoVideoWidget({super.key});

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(10),
        ),
        child: LayoutBuilder(
          builder: (ctx, constraints) => Icon(
            Icons.account_circle,
            color: Colors.white,
            size: math.min(constraints.maxHeight, constraints.maxWidth) /2,
          ),
        ),
      );
}
