// ignore_for_file: unnecessary_brace_in_string_interps, file_names, deprecated_member_use

import 'package:flutter/material.dart';

class NewParticipantDialog {

  static Future<void> show(BuildContext context, String participantName) async {
    participantName = participantName[0].toUpperCase() + participantName.substring(1);
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6), // Darker backdrop for focus
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // Less rounded for professional look
          ),
          elevation: 8,
          backgroundColor: Colors.transparent, // Use transparent and handle it with child
          child: Container(
            padding: const EdgeInsets.all(0), // Remove padding as we'll handle it inside
            constraints: const BoxConstraints(
              minWidth: 300,
              maxWidth: 400,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5), // Light grey background
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2), // More subtle shadow
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF303030), // Dark grey header
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.mic_off, // Mute icon
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Microphone Muted',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500, // Medium weight
                          color: Colors.white,
                          letterSpacing: 0.25, // Subtle letter spacing
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Text(
                    '${participantName}, you are currently muted by default. To request to speak, please raise your hand using the control panel.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF424242), // Dark grey text
                      height: 1.5, // Line height for readability
                    ),
                    textAlign: TextAlign.left, // Left-aligned looks more professional
                  ),
                ),
                
                // Hand raise hint
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE), // Lighter grey background
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFFE0E0E0), // Light grey border
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF616161), // Medium grey
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Look for the "Raise Hand" icon in the meeting controls at the top of the screen.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Divider
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE0E0E0), // Light grey divider
                ),
                
                // Button area
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // OK button
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          backgroundColor: const Color(0xFF424242), // Dark grey button
                          foregroundColor: Colors.white,
                          elevation: 0, // No elevation for flat look
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'GOT IT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500, // Medium weight
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}