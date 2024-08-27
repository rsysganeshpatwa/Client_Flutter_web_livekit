import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class HandRaiseNotification {
  static void show(BuildContext context, Participant participant, void Function(Participant) allowSpeak) {
    final participantName = participant.name ?? 'Unknown';

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text('$participantName has raised their hand to speak.')),
            TextButton(
              onPressed: () {
                allowSpeak(participant);
                scaffoldMessenger.hideCurrentSnackBar();
              },
              child: Text('Allow Speak', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                // Handle cancel action
                scaffoldMessenger.hideCurrentSnackBar();
              },
              child: Text('No', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );
  }
}
