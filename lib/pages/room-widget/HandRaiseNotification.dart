// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class HandRaiseNotification {
  static void show(BuildContext context, Participant participant, void Function(Participant) allowSpeak, void Function(Participant) denySpeak) {
    final participantName = participant.name.isNotEmpty ? participant.name : participant.identity;
    
    // Create snackbar content
    final snackBar = SnackBar(
      backgroundColor: const Color(0xFF323232), // Dark grey background
      behavior: SnackBarBehavior.floating, // Use floating style for cleaner look
      dismissDirection: DismissDirection.horizontal, // Allow horizontal dismissal
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Add margins for floating appearance
      padding: EdgeInsets.zero, // Remove default padding for more control
      elevation: 6, // Add slight elevation for depth
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6), // More professional rounded corners
      ),
      duration: const Duration(seconds: 15), // Longer duration for important notifications
      content: Container(
        padding: const EdgeInsets.all(0), // No padding for container
        child: Row(
          children: [
            // Left accent stripe
            Container(
              width: 6,
              height: 60, // Match height of notification
              color: const Color(0xFFFFA726), // Orange accent color for hand raise
            ),
            
            // Hand icon container
            Container(
              width: 48,
              height: 60,
              color: const Color(0xFF323232), // Dark grey
              child: const Center(
                child: Icon(
                  Icons.pan_tool_rounded,
                  color: Color(0xFFFFA726), // Orange hand icon
                  size: 24,
                ),
              ),
            ),
            
            // Message content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Hand Raised', // Title
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$participantName would like to speak', // Message
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Deny button
                TextButton(
                  onPressed: () {
                    denySpeak(participant);
                    // Close the overlay if using custom top notification
                    removeCurrentOverlay();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'DECLINE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Allow button
                TextButton(
                  onPressed: () {
                    allowSpeak(participant);
                    // Close the overlay if using custom top notification
                    removeCurrentOverlay();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFFFFA726), // Orange button text
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'ALLOW',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8), // Spacing at the end
              ],
            ),
          ],
        ),
      ),
    );
    
    // Use our custom method to show at top instead of default SnackBar
    showAtTop(context, snackBar);
  }
  
  // Track current overlay entry to manage dismissal
  static OverlayEntry? _currentOverlay;
  
  // Method to remove current overlay if exists
  static void removeCurrentOverlay() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
  
  // Method to position the SnackBar at the top of the screen
  static void showAtTop(BuildContext context, SnackBar snackBar) {
    // Remove any existing notification first
    removeCurrentOverlay();
    
    final overlay = Overlay.of(context);
    
    // Create new overlay entry
    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).viewPadding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(6),
          color: snackBar.backgroundColor,
          child: snackBar.content,
        ),
      ),
    );
    
    // Add to overlay
    overlay.insert(_currentOverlay!);
    
    // Remove after duration
    Future.delayed(snackBar.duration).then((_) {
      if (_currentOverlay != null) {
        _currentOverlay!.remove();
        _currentOverlay = null;
      }
    });
  }
}
