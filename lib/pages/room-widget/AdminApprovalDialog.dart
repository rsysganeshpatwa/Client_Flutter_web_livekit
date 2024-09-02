import 'package:flutter/material.dart';

class AdminApprovalDialog extends StatelessWidget {
  final String participantName;
  final String roomName;
  final Function(bool) onDecision;

  AdminApprovalDialog({
    required this.participantName,
    required this.roomName,
    required this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Approval Request'),
      content: Text('Participant $participantName has requested to join room $roomName.'),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            onDecision(true); // Approve
            Navigator.of(context).pop();
          },
          child: Text('Approve'),
        ),
        TextButton(
          onPressed: () {
            onDecision(false); // Reject
            Navigator.of(context).pop();
          },
          child: Text('Reject'),
        ),
      ],
    );
  }
}
