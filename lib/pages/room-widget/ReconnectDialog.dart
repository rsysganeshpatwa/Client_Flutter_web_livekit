import 'dart:async';
import 'package:flutter/material.dart';

class ReconnectDialog extends StatefulWidget {
  final String roomName;
  
  // Static key to reference the dialog globally
  static final GlobalKey<_ReconnectDialogState> reconnectDialogKey = GlobalKey<_ReconnectDialogState>();

  // Add a static property to track active dialog
  static bool isDialogShowing = false;

  ReconnectDialog({
    Key? key,
    required this.roomName,
  }) : super(key: key ?? reconnectDialogKey);

  // Enhanced static method to close any active dialog
  static void closeActiveDialog(BuildContext context) {
    if (reconnectDialogKey.currentState != null) {
      reconnectDialogKey.currentState!.closeDialog();
    } else if (isDialogShowing && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      isDialogShowing = false;
    }
  }

  @override
  State<ReconnectDialog> createState() => _ReconnectDialogState();
}

class _ReconnectDialogState extends State<ReconnectDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _autoCloseTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Set the static flag when the dialog is shown
    ReconnectDialog.isDialogShowing = true;
    
    // Create animation controller for the indeterminate progress indicator
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // Set up auto-close timer as a safety mechanism (60 seconds)
    _autoCloseTimer = Timer(const Duration(seconds: 60), () {
      closeDialog();
    });
  }

  // Method to close this dialog
  void closeDialog() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      ReconnectDialog.isDialogShowing = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _autoCloseTimer?.cancel();
    ReconnectDialog.isDialogShowing = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        width: 320, // Slightly narrower for a cleaner look
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Connection lost icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF424242),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off,
                color: Color(0xFFFFD54F),
                size: 32,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Connection lost text
            const Text(
              'Connection Lost',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Simple message
            const Text(
              'Reconnecting to the meeting...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFE0E0E0),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Simple loading animation
            RotationTransition(
              turns: _controller,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Leave meeting button
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Return true to indicate user wants to leave
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: const Color(0xFF505050),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Leave Meeting',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}