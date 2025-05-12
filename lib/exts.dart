import 'package:flutter/material.dart';

extension LKExampleExt on BuildContext {
  //

  void showApprovalStatusDialog( String status) {
    showDialog(
      context: this,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Approval Status',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold, // Set the font to bold
            ),
          ),
          content: Text(
            status == 'approved'
                ? 'Your request has been approved! You can now join the room.'
                : status == 'rejected'
                    ? 'Your request has been rejected. You cannot join the room at this time.'
                    : 'No host is available at the moment. Please try again .',
            style: const TextStyle(color: Colors.black),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate back or close the dialog based on the status
                if (status == 'rejected') {
                  // Optionally, handle rejection (e.g., navigate back or show a message)
                  Navigator.of(context).pop(); // Or navigate to another page
                  Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    Navigator.of(context).pop(); // ✅ Navigate back to the previous page
                  }
                });

                }
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 20),
                // backgroundColor: Colors.green, // Button color
                 backgroundColor: Colors.indigo[900],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white), // Set button text color to green
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> showPublishDialog() => showDialog<bool>(
        context: this,
        builder: (ctx) => AlertDialog(
          title: const Text('Publish'),
          content: const Text('Would you like to publish your Camera & Mic ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('NO'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('YES'),
            ),
          ],
        ),
      );

  Future<bool?> showPlayAudioManuallyDialog() => showDialog<bool>(
        context: this,
        builder: (ctx) => AlertDialog(
          title: const Text('Play Audio'),
          content: const Text(
              'You need to manually activate audio PlayBack for iOS Safari !'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ignore'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Play Audio'),
            ),
          ],
        ),
      );

  Future<bool?> showUnPublishDialog() => showDialog<bool>(
        context: this,
        builder: (ctx) => AlertDialog(
          title: const Text('UnPublish'),
          content:
              const Text('Would you like to un-publish your Camera & Mic ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('NO'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('YES'),
            ),
          ],
        ),
      );

  Future<void> showErrorDialog(dynamic exception, {String title ='Error'}) => showDialog<void>(
        context: this,
        builder: (ctx) => AlertDialog(
          title:  Text(title),
          content: Text(exception.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            )
          ],
        ),
      );

Future<bool?> showDisconnectDialog() => showDialog<bool>(
      context: this,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Rounded corners
        ),
        backgroundColor: Colors.grey[200], // Light grey background
        title: const Text(
          'Disconnect',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black, // Text color
          ),
        ),
        content: const Text(
          'Are you sure to disconnect?',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black, // Content text color
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        actions: [
          // Cancel button
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              backgroundColor: Colors.indigo[900], // Button text color
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          // Disconnect button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo[900], // Button background color
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );


  Future<bool?> showReconnectDialog() => showDialog<bool>(
        context: this,
        builder: (ctx) => AlertDialog(
          title: const Text('Reconnect'),
          content: const Text('This will force a reconnection'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reconnect'),
            ),
          ],
        ),
      );

  Future<void> showReconnectSuccessDialog() => showDialog<void>(
        context: this,
        builder: (ctx) => AlertDialog(
          title: const Text('Reconnect'),
          content: const Text('Reconnection was successful.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  Future<bool?> showSendDataDialog() => showDialog<bool>(
        context: this,
        builder: (ctx) => AlertDialog(
          title: const Text('Send data'),
          content: const Text(
              'This will send a sample data to all participants in the room'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send'),
            ),
          ],
        ),
      );

  Future<bool?> showDataReceivedDialog(String data) => showDialog<bool>(
        context: this,
        builder: (ctx) => AlertDialog(
          title: const Text('Received data'),
          content: Text(data),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  Future<bool?> showRecordingStatusChangedDialog(bool isActiveRecording) =>
      showDialog<bool>(
        context: this,
        builder: (ctx) => AlertDialog(
          title: const Text('Room recording reminder'),
          content: Text(isActiveRecording
              ? 'Room recording is active.'
              : 'Room recording is stoped.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  Future<bool?> showSubscribePermissionDialog() => showDialog<bool>(
        context: this,
        builder: (ctx) => AlertDialog(
          title: const Text('Allow subscription'),
          content: const Text(
              'Allow all participants to subscribe tracks published by local participant?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('NO'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('YES'),
            ),
          ],
        ),
      );

  Future<SimulateScenarioResult?> showSimulateScenarioDialog() =>
      showDialog<SimulateScenarioResult>(
        context: this,
        builder: (ctx) => SimpleDialog(
          title: const Text('Simulate Scenario'),
          children: SimulateScenarioResult.values
              .map((e) => SimpleDialogOption(
                    child: Text(e.name),
                    onPressed: () => Navigator.pop(ctx, e),
                  ))
              .toList(),
        ),
      );
}

enum SimulateScenarioResult {
  signalReconnect,
  fullReconnect,
  speakerUpdate,
  nodeFailure,
  migration,
  serverLeave,
  switchCandidate,
  e2eeKeyRatchet,
  participantName,
  participantMetadata,
  clear,
}


