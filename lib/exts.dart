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
      barrierColor: Colors.black.withOpacity(0.6), // Darker backdrop for focus
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Slightly less rounded for professional look
        ),
        backgroundColor: const Color(0xFF2C2C2C), // Dark grey background
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: [
            Icon(
              Icons.logout, // Disconnect icon
              color: Colors.red[300],
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              'Disconnect Session',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500, // Medium weight looks more professional
                color: Colors.white, // White text for contrast
                letterSpacing: 0.25, // Subtle letter spacing for readability
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to disconnect from this meeting?',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFFDDDDDD), // Light grey for body text
            height: 1.5, // Line height for better readability
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // Cancel button - more subtle
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              backgroundColor: const Color(0xFF3A3A3A), // Slightly lighter than background
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.white70, // Slightly transparent white
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          // Disconnect button - more emphasis
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              backgroundColor: const Color(0xFFE53935), // Red color for warning action
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'DISCONNECT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
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


