import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_meeting_room/utils.dart';

class CopyInviteLinkDialog {
  static Future<void> show(BuildContext context, String roomName) async {
    // Encode the room name for safe URL usage
    String encodedRoomName = roomName;

    // Define the parameters for both host and participant
      final baseUrl = 'https://${Uri.base.host}';
    final Map<String, String> hostParams = {
      'room': encodedRoomName,
      'role': 'admin',
    };

    final Map<String, String> participantParams = {
      'room': encodedRoomName,
      'role': 'participant',
    };

 
  final encodedHostParams = UrlEncryptionHelper.encodeParams(hostParams);
    final encryptedHostParams = UrlEncryptionHelper.encrypt(encodedHostParams);
    final encodedEncryptedHostParams = Uri.encodeComponent(encryptedHostParams);

    final encodedParticipantParams = UrlEncryptionHelper.encodeParams(participantParams);
    final encryptedParticipantParams = UrlEncryptionHelper.encrypt(encodedParticipantParams);
    final encodedEncryptedParticipantParams = Uri.encodeComponent(encryptedParticipantParams);

    final hostInviteLink = 'https://${Uri.base.host}?data=$encodedEncryptedHostParams';
    final participantInviteLink = 'https://${Uri.base.host}?data=$encodedEncryptedParticipantParams';

    print('Encrypted Host Params: $encryptedHostParams');
    final decryptedHostParams = UrlEncryptionHelper.decrypt(encryptedHostParams);
    print('Decrypted Host Params: $decryptedHostParams');

  
    // Show the dialog to select which link to copy
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

    // Copy the selected link to the clipboard and show a snackbar
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
