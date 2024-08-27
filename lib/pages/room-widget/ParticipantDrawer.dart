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
  Widget build(BuildContext context) {
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

                // Displaying non-admin and non-host participants
                ...filterParticipants(searchQuery).where((track) {
                  final metadata = track.participant.metadata;
                  final role =
                      metadata != null ? jsonDecode(metadata)['role'] : null;
                  return role != Role.admin.toString();
                }).map((track) {
                  final isLocal = track.participant.identity ==
                      localParticipant?.identity;
                  final participantName = track.participant.name ?? 'Unknown';
                  final displayName =
                      isLocal ? '$participantName (you)' : participantName;

                  // Check if the hand is raised
                  final metadata = track.participant.metadata;
                  final isHandRaised = metadata != null
                      ? jsonDecode(metadata)['handraise'] == true
                      : false;

                  return ListTile(
                    title: Text(displayName),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isHandRaised)
                          Icon(Icons.pan_tool,
                              color: Colors.orange), // Hand raised icon
                        if (!isLocal)
                          Checkbox(
                            value: allowedToTalk.contains(track.participant),
                            onChanged: (value) {
                              toggleParticipantForTalk(track.participant);
                            },
                          ),
                      ],
                    ),
                    onTap: isLocal
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
