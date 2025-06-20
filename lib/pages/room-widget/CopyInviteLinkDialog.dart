// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_meeting_room/utils.dart'; // Ensure this import is correct

class CopyInviteLinkDialog {
  static Future<void> show(BuildContext context, String roomName) async {
   
    // Encode the room name for safe URL usage
    String encodedRoomName = roomName;

    // Show the dialog with the updated styling
    final selectedLink = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _CopyInviteLinkDialogContent(roomName: encodedRoomName);
      },
    );

    // Copy the selected link to the clipboard and show a snackbar
    if (selectedLink != null) {
      await Clipboard.setData(ClipboardData(text: selectedLink));
       if ( !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite link copied to clipboard'),
        ),
      );
    }
  }
}

class _CopyInviteLinkDialogContent extends StatefulWidget {
  final String roomName;

  const _CopyInviteLinkDialogContent({required this.roomName});

  @override
  _CopyInviteLinkDialogContentState createState() =>
      _CopyInviteLinkDialogContentState();
}

class _CopyInviteLinkDialogContentState
    extends State<_CopyInviteLinkDialogContent> {
  bool muteByDefault = true;
  bool joinRequiresApproval = true;
  bool enableAudio = false;
  bool enableVideo = false;

  @override
  Widget build(BuildContext context) {
    String encodedRoomName = widget.roomName;

    // Define the parameters for both host and participant
 
    final Map<String, String> hostParams = {
      'room': encodedRoomName,
      'role': 'admin',
    };

    final Map<String, String> participantParams = {
      'room': encodedRoomName,
      'role': 'participant',
      'muteByDefault': muteByDefault.toString(),
      'joinRequiresApproval': joinRequiresApproval.toString(),
      'enableAudio': enableAudio.toString(),
          'enableVideo': enableVideo.toString(),
    };

    final encodedHostParams = UrlEncryptionHelper.encodeParams(hostParams);
    final encryptedHostParams = UrlEncryptionHelper.encrypt(encodedHostParams);
    final encodedEncryptedHostParams = Uri.encodeComponent(encryptedHostParams);

    final encodedParticipantParams =
        UrlEncryptionHelper.encodeParams(participantParams);
    final encryptedParticipantParams =
        UrlEncryptionHelper.encrypt(encodedParticipantParams);
    final encodedEncryptedParticipantParams =
        Uri.encodeComponent(encryptedParticipantParams);

    final hostInviteLink =
        'https://${Uri.base.host}?data=$encodedEncryptedHostParams';
    final participantInviteLink =
        'https://${Uri.base.host}?data=$encodedEncryptedParticipantParams';

    return Center(
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 200,
              maxWidth: 400,
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title and close button
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Copy Invite Link',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Host link row
                    _buildLinkRow(
                      'Host Link',
                      'https://dhws-production.s3.ap-south-1.amazonaws.com/66daabcf132e0c0023f12804/66daac278309bf001b0f4695/66daaca38309bf001b0f4fbb/appSource/images/img_television_gray_600_01_1.svg',
                      'Copy',
                      () => Navigator.pop(context, hostInviteLink),
                    ),
                    const SizedBox(height: 20),
                    // Participant link row
                    _buildLinkRow(
                      'Participants Link',
                      'https://dhws-production.s3.ap-south-1.amazonaws.com/66daabcf132e0c0023f12804/66daac278309bf001b0f4695/66daaca38309bf001b0f4fbb/appSource/images/img_television_gray_600_01_1.svg',
                      'Copy',
                      () => Navigator.pop(context, participantInviteLink),
                    ),
                    const SizedBox(height: 10),
                   SwitchListTile(
  title: const Text('Join Requires Approval'),
  subtitle: joinRequiresApproval
      ? const Text(
          'Participants must be approved before joining',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        )
      : null,
  value: joinRequiresApproval,
  onChanged: (value) {
    setState(() {
      joinRequiresApproval = value;
    });
  },
  activeColor: Colors.indigo[900],
),


                   SwitchListTile(
  title: const Text('Mute By Default'),
  subtitle: muteByDefault
      ? const Text(
          'Participants will be muted by default for host',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        )
      : null,
  value: muteByDefault,
  onChanged: (mute) {
    setState(() {
      muteByDefault = mute;
   
    });
  },
  activeColor: Colors.indigo[900],
),

Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Padding(
      padding: EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        'Together Mode',
        
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    ),
    SwitchListTile(
      title: const Text('Enable Audio'),
      subtitle: enableAudio
          ? const Text(
              'Participants will be able to speak everyone',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          : null,
      value: enableAudio,
      onChanged: (value) {
        setState(() {
          enableAudio = value;
          muteByDefault = !value; // Mute by default if audio is enabled
        });
      },
      activeColor: Colors.indigo[900],
    ),
    SwitchListTile(
      title: const Text('Enable Video'),
      subtitle: enableVideo
          ? const Text(
              'Participants will be able to see everyone',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          : null,
      value: enableVideo,
      onChanged: (value) {
        setState(() {
          enableVideo = value;
        });
      },
      activeColor: Colors.indigo[900],
    ),
  ],
),


           
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusable function to build each link row
  static Widget _buildLinkRow(
    String labelText,
    String imageUrl,
    String buttonText,
    VoidCallback onCopy,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: Row(
        children: [
          Icon(
            Icons.link,
            size: 40,
            color: Colors.grey[600],
          ),
          const VerticalDivider(
            color: Colors.black,
            thickness: 10,
            width: 20,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labelText,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Divider(thickness: 1, color: Colors.grey[400]),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo[900],
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: onCopy,
            child: Text(buttonText),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
