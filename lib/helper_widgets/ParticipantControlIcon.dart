import 'package:flutter/material.dart';

class ParticipantControlIcon extends StatelessWidget {
  final bool isActive;
  final IconData iconOn;
  final IconData iconOff;
  final String tooltipOn;
  final String tooltipOff;
  final Color colorActive;
  final Color colorInactive;
  final VoidCallback onTap;

  const ParticipantControlIcon({
    Key? key,
    required this.isActive,
    required this.iconOn,
    required this.iconOff,
    required this.tooltipOn,
    required this.tooltipOff,
    required this.colorActive,
    required this.colorInactive,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isActive ? tooltipOn : tooltipOff,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: isActive ? colorActive : colorInactive),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 4),
            ],
          ),
          child: Icon(
            isActive ? iconOn : iconOff,
            color: isActive ? colorActive : colorInactive,
            size: 18,
          ),
        ),
      ),
    );
  }
}
