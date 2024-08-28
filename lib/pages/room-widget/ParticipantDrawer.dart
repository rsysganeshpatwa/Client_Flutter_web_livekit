import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';

class ParticipantDrawer extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final List<ParticipantTrack> Function(String) filterParticipants;
  final Participant? localParticipant;
  final Set<Participant> allowedToTalk;
  final void Function(Participant) toggleParticipantForTalk;

  ParticipantDrawer({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.filterParticipants,
    required this.localParticipant,
    required this.allowedToTalk,
    required this.toggleParticipantForTalk,
  });

  @override
@override
Widget build(BuildContext context) {
  // Filtering participants who raised their hands and sorting them by hand raise order
  final handRaisedParticipants = filterParticipants(searchQuery)
      .where((track) {
        final metadata = track.participant.metadata;
        return metadata != null &&
            jsonDecode(metadata)['handraise'] == true;
      })
      .toList()
      ..sort((a, b) {
        final aMetadata = jsonDecode(a.participant.metadata!);
        final bMetadata = jsonDecode(b.participant.metadata!);
        return aMetadata['handraiseTime'].compareTo(bMetadata['handraiseTime']);
      });

  // Filtering participants who did not raise their hands
  final nonHandRaisedParticipants = filterParticipants(searchQuery)
      .where((track) {
        final metadata = track.participant.metadata;
        return metadata == null ||
            jsonDecode(metadata)['handraise'] != true &&
                jsonDecode(metadata)['role'] != Role.admin.toString();
      })
      .toList();

  return Drawer(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            style: TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Search participants',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              // Displaying the host first
              ...filterParticipants(searchQuery).where((track) {
                final metadata = track.participant.metadata;
                final role =
                    metadata != null ? jsonDecode(metadata)['role'] : null;
                return role == Role.admin.toString();
              }).map((track) {
                final isLocal = track.participant.identity ==
                    localParticipant?.identity;
                final participantName = track.participant.name ?? 'Unknown';
                final displayName = isLocal
                    ? '$participantName (you) (host)'
                    : '$participantName (host)';

                return ListTile(
                  title: Text(displayName),
                  trailing: null, // No checkbox for the host
                  onTap: null, // No action for the host
                );
              }).toList(),

              // Displaying participants with raised hands in order
              ...handRaisedParticipants.map((track) {
                final metadata = jsonDecode(track.participant.metadata!);
                final role = metadata['role'];

                final isLocal = track.participant.identity ==
                    localParticipant?.identity;
                final participantName = track.participant.name ?? 'Unknown';
                final displayName =
                    isLocal ? '$participantName (you)' : participantName;

                final index = handRaisedParticipants.indexOf(track) + 1;
                final handRaisedText = ' (#$index)';

                return ListTile(
                  title: Text(displayName + handRaisedText),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pan_tool, color: Colors.orange),
                      if (!isLocal && role != Role.admin.toString())
                        Checkbox(
                          value: allowedToTalk.contains(track.participant),
                          onChanged: (value) {
                            toggleParticipantForTalk(track.participant);
                          },
                        ),
                    ],
                  ),
                  onTap: isLocal || role == Role.admin.toString()
                      ? null
                      : () {
                          toggleParticipantForTalk(track.participant);
                        },
                );
              }).toList(),

              // Displaying non-admin and non-hand-raised participants
              ...nonHandRaisedParticipants.map((track) {
                final metadata = jsonDecode(track.participant.metadata!);
                final role = metadata['role'];

                final isLocal = track.participant.identity ==
                    localParticipant?.identity;
                final participantName = track.participant.name ?? 'Unknown';
                final displayName =
                    isLocal ? '$participantName (you)' : participantName;

                return ListTile(
                  title: Text(displayName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isLocal && role != Role.admin.toString())
                        Checkbox(
                          value: allowedToTalk.contains(track.participant),
                          onChanged: (value) {
                            toggleParticipantForTalk(track.participant);
                          },
                        ),
                    ],
                  ),
                  onTap: isLocal || role == Role.admin.toString()
                      ? null
                      : () {
                          toggleParticipantForTalk(track.participant);
                        },
                );
              }).toList(),
            ],
          ),
        )
      ],
    ),
  );
}
}
