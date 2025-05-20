// ignore_for_file: file_names

import 'package:flutter/material.dart';

class AdminApprovalDialog extends StatelessWidget {
  final String participantName;
  final String roomName;
  final Function(bool) onDecision;

  const AdminApprovalDialog({
    super.key,
    required this.participantName,
    required this.roomName,
    required this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // Less rounded corners for professional look
      ),
      elevation: 8,
      backgroundColor: Colors.transparent, // Transparent background to show custom container
      child: Container(
        padding: const EdgeInsets.all(0), // Remove padding as we'll manage it inside
        constraints: const BoxConstraints(
          minWidth: 300, // Minimum width
          maxWidth: 400, // Maximum width to control content stretching
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5), // Light grey background
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2), // Subtle shadow
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch content horizontally
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
                    Icons.person_add, // Icon representing approval
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Approval Request',
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
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF424242), // Dark grey text
                        height: 1.5, // Line height
                      ),
                      children: [
                        const TextSpan(text: 'Participant '),
                        TextSpan(
                          text: participantName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600, // Semi-bold
                            color: Color(0xFF212121), // Darker text for emphasis
                          ),
                        ),
                        const TextSpan(text: ' has requested to join room '),
                        TextSpan(
                          text: roomName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600, // Semi-bold
                            color: Color(0xFF212121), // Darker text for emphasis
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // User info hint
                  Container(
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
                          color: Color(0xFF757575), // Medium grey
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please review this request carefully before making a decision.',
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
                ],
              ),
            ),
            
            // Divider
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE0E0E0), // Light grey divider
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Reject Button
                  TextButton(
                    onPressed: () {
                      onDecision(false); // Reject
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      backgroundColor: Colors.white, // White background
                      foregroundColor: const Color(0xFF424242), // Dark grey text
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: const BorderSide(
                          color: Color(0xFFBDBDBD), // Light grey border
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text(
                      'REJECT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500, // Medium weight
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Approve Button
                  ElevatedButton(
                    onPressed: () {
                      onDecision(true); // Approve
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      backgroundColor: const Color(0xFF424242), // Dark grey button
                      foregroundColor: Colors.white,
                      elevation: 0, // No elevation for flat look
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'APPROVE',
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
  }
}
