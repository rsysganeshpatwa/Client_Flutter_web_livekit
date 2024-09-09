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

    // Show the dialog with the updated styling
    final selectedLink = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Center(
          // Ensures the dialog content is centered
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.white, // Set background color to white 700
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                // Constrain the box width based on content
                constraints: BoxConstraints(
                  minWidth: 200, // Minimum width
                  maxWidth: 400, // Maximum width to control content stretching
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title and close button
                    // Header with title and close button
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // Centers the text
                      children: [
                        Text(
                          'Copy Invite Link',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black, // Set text color to grey 600
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    // Copy the selected link to the clipboard and show a snackbar
    if (selectedLink != null) {
      await Clipboard.setData(ClipboardData(text: selectedLink));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite link copied to clipboard'),
        ),
      );
    }
  }

  // Reusable function to build each link row
static Widget _buildLinkRow(
    String labelText, String imageUrl, String buttonText, VoidCallback onCopy) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey[200], // Background color of the row (light grey)
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.5), // Shadow color
          spreadRadius: 2,
          blurRadius: 5,
          offset: const Offset(0, 3), // Shadow position
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
    child: Row(
      children: [
        // Icon or Image
        Icon(
          Icons.link,
          size: 40,
          color: Colors.grey[600],
        ),
        const VerticalDivider(
          color: Colors.black, // Divider color
          thickness: 10, // Divider thickness
          width: 20, // Space between icon and label
        ),
        // Label and Line
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
              Divider(thickness: 1, color: Colors.grey[400]), // Line below label
            ],
          ),
        ),

        // Copy button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo[900],
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: onCopy,
          child: Text(buttonText),
        ),
      ],
    ),
  );
}
}
