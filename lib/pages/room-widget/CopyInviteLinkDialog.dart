import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyInviteLinkDialog {
  static Future<void> show(BuildContext context, String roomName) async {
    String encodedRoomName = Uri.encodeComponent(roomName);

    final hostInviteLink = 'https://${Uri.base.host}?room=$encodedRoomName&role=admin';
    final participantInviteLink = 'https://${Uri.base.host}?room=$encodedRoomName&role=participant';

    final selectedLink = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('Copy Invite Link'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, hostInviteLink);
              },
              child: Text('Host Link'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, participantInviteLink);
              },
              child: Text('Participant Link'),
            ),
          ],
        );
      },
    );

    if (selectedLink != null) {
      await Clipboard.setData(ClipboardData(text: selectedLink));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite link copied to clipboard'),
        ),
      );
    }
  }
}
