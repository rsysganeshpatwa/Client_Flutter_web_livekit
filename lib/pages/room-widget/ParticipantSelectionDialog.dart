// lib/widgets/participant_selection_dialog.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';

class ParticipantSelectionDialog extends StatefulWidget {
  final List<ParticipantTrack> participantTracks;
  final Set<Participant> allowedToTalk;
  final void Function(Participant) onToggleParticipantForTalk;
  final String localParticipantIdentity;

  ParticipantSelectionDialog({
    required this.participantTracks,
    required this.allowedToTalk,
    required this.onToggleParticipantForTalk,
    required this.localParticipantIdentity,
  });

  @override
  _ParticipantSelectionDialogState createState() =>
      _ParticipantSelectionDialogState();
}

class _ParticipantSelectionDialogState
    extends State<ParticipantSelectionDialog> {
  @override
  Widget build(BuildContext context) {
    // Separate participants into admins and non-admins
    final adminTracks = widget.participantTracks.where((track) {
      final metadata = track.participant.metadata;
      final role = metadata != null ? jsonDecode(metadata)['role'] : null;
      return role == Role.admin.toString();
    }).toList();

    final nonAdminTracks = widget.participantTracks.where((track) {
      final metadata = track.participant.metadata;
      final role = metadata != null ? jsonDecode(metadata)['role'] : null;
      return role != Role.admin.toString();
    }).toList();

    return AlertDialog(
      title: Text('Select Participants'),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            // Displaying admins first (without checkbox and with (host))
            ...adminTracks.map((track) {
              final participantName = track.participant.name ?? 'Unknown';
              final isLocal = track.participant.identity == widget.localParticipantIdentity;
              final displayName = isLocal ? '$participantName (you) (host)' : '$participantName (host)';

              return ListTile(
                title: Text(displayName, style: TextStyle(color: Colors.white)),
                trailing: null, // No checkbox for admins
                onTap: null, // No tap action for admins
              );
            }).toList(),

            // Displaying non-admin participants
            ...nonAdminTracks.map((track) {
              final participantName = track.participant.name ?? 'Unknown';
              final isLocal = track.participant.identity == widget.localParticipantIdentity;
              final isHandRaised = track.participant.metadata != null
                  ? jsonDecode(track.participant.metadata ?? '{}')['handraise'] == true
                  : false;

              return ListTile(
                title: Text(
                  isLocal ? '$participantName (you)' : participantName,
                  style: TextStyle(color: Colors.white),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHandRaised) Icon(Icons.pan_tool, color: Colors.orange), // Hand raised icon
                    if (!isLocal) Checkbox(
                      value: widget.allowedToTalk.contains(track),
                      onChanged: (value) {
                        widget.onToggleParticipantForTalk(track as Participant<TrackPublication<Track>>);
                      },
                    ),
                  ],
                ),
                onTap: isLocal
                    ? null
                    : () {
                        widget.onToggleParticipantForTalk(track as Participant<TrackPublication<Track>>);
                      },
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog
          },
          child: Text('Close'),
        ),
      ],
    );
  }
}
