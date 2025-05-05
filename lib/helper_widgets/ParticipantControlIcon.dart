import 'package:flutter/material.dart';

class ParticipantControlIcon extends StatelessWidget {
  final bool isActive;
  final bool isDisabled; // Add new property
  final IconData iconOn;
  final IconData iconOff;
  final String tooltipOn;
  final String tooltipOff;
  final Color colorActive;
  final Color colorInactive;
  final Color colorDisabled; // Add new property
  final VoidCallback onTap;

  const ParticipantControlIcon({
    Key? key,
    required this.isActive,
    this.isDisabled = false, // Default to false
    required this.iconOn,
    required this.iconOff,
    required this.tooltipOn,
    required this.tooltipOff,
    required this.colorActive,
    required this.colorInactive,
    this.colorDisabled = Colors.grey, // Default disabled color
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isDisabled ? 'Disabled' : (isActive ? tooltipOn : tooltipOff),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDisabled ? Colors.grey[200] : Colors.white,
              border: Border.all(
                color: isDisabled 
                    ? colorDisabled 
                    : (isActive ? colorActive : colorInactive),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDisabled ? Colors.transparent : Colors.black12, 
                  blurRadius: 4
                ),
              ],
            ),
            child: Icon(
              isActive ? iconOn : iconOff,
              color: isDisabled 
                  ? colorDisabled 
                  : (isActive ? colorActive : colorInactive),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}