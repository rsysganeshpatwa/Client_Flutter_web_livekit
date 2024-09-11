import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class HandRaiseNotification {
  static void show(BuildContext context, Participant participant, void Function(Participant) allowSpeak, void Function(Participant) denySpeak) {
    final participantName = participant.name ?? 'Unknown';
    participant.handRaised = true;

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
                participant.handRaised = false;
                scaffoldMessenger.hideCurrentSnackBar();
              },
              child: const Text('Allow Speak', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                // Handle cancel action
                denySpeak(participant);
                participant.handRaised = false;
                scaffoldMessenger.hideCurrentSnackBar();
              },
              child: const Text('No', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }
}
