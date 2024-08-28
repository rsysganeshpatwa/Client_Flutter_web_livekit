import 'dart:convert';
import 'package:flutter/material.dart';
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
  final void Function(Participant,
      {bool? audioStatus, bool? videoStatus}) updateMetadataTogetherMode;

  ParticipantDrawer({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.filterParticipants,
    required this.localParticipant,
    required this.allowedToTalk,
    required this.toggleParticipantForTalk,
    required this.updateMetadataTogetherMode,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Drawer(
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
            TabBar(
              tabs: [
                Tab(text: 'Audio Manage'),
                Tab(text: 'Together Mode'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Audio Manage
                  ListView(
                    children: [
                      // Displaying the host first
                      ...filterParticipants(searchQuery).where((track) {
                        final metadata = track.participant.metadata;
                        final role = metadata != null
                            ? jsonDecode(metadata)['role']
                            : null;
                        return role == Role.admin.toString();
                      }).map((track) {
                        final isLocal = track.participant.identity ==
                            localParticipant?.identity;
                        final participantName =
                            track.participant.name ?? 'Unknown';
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
                      ..._buildHandRaisedParticipants(),

                      // Displaying non-admin and non-hand-raised participants
                      ..._buildNonHandRaisedParticipants(),
                    ],
                  ),

                  // Tab 2: Together Mode
                  ListView(
                    children: [
                      ...filterParticipants(searchQuery).map((track) {
                        final isLocal = track.participant.identity ==
                            localParticipant?.identity;
                        final participantName =
                            track.participant.name ?? 'Unknown';
                        final displayName = isLocal
                            ? '$participantName (you)'
                            : participantName;

                        // Extracting audio and video status from metadata
                        final metadata = track.participant.metadata != null
                            ? jsonDecode(track.participant.metadata!)
                            : {};
                        final isAudioOn = metadata['audio'] ?? false;
                        final isVideoOn = metadata['video'] ?? false;
                        print('isAudioOn metadata: $metadata');
                        return ListTile(
                          title: Text(displayName),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isAudioOn
                                      ? Icons.mic
                                      : Icons.mic_off,
                                  color: isAudioOn == true
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                onPressed: isLocal
                                    ? null
                                    : () async {
                                        updateMetadataTogetherMode(
                                          track.participant,
                                          audioStatus:
                                              !isAudioOn,
                                              videoStatus: isVideoOn
                                        );
                                        
                                      },
                              ),
                              IconButton(
                                icon: Icon(
                                  metadata['video'] == true
                                      ? Icons.videocam
                                      : Icons.videocam_off,
                                  color: isVideoOn == true
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                onPressed: isLocal
                                    ? null
                                    : () {
                                        updateMetadataTogetherMode(
                                          track.participant,
                                          videoStatus:
                                              !isVideoOn ,
                                              audioStatus: isAudioOn,
                                              
                                        );
                                      },
                              ),
                            ],
                          ),
                          onTap:
                              null, // No specific action for Together Mode participants
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHandRaisedParticipants() {
    final handRaisedParticipants = filterParticipants(searchQuery)
        .where((track) {
      final metadata = track.participant.metadata;
      return metadata != null && jsonDecode(metadata)['handraise'] == true;
    }).toList()
      ..sort((a, b) {
        final aMetadata = jsonDecode(a.participant.metadata!);
        final bMetadata = jsonDecode(b.participant.metadata!);
        return aMetadata['handraiseTime'].compareTo(bMetadata['handraiseTime']);
      });

    return handRaisedParticipants.map((track) {
      final metadata = jsonDecode(track.participant.metadata!);
      final role = metadata['role'];

      final isLocal = track.participant.identity == localParticipant?.identity;
      final participantName = track.participant.name ?? 'Unknown';
      final displayName = isLocal ? '$participantName (you)' : participantName;

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
    }).toList();
  }

  List<Widget> _buildNonHandRaisedParticipants() {
    final nonHandRaisedParticipants =
        filterParticipants(searchQuery).where((track) {
      final metadata = track.participant.metadata;
      return metadata == null ||
          jsonDecode(metadata)['handraise'] != true &&
              jsonDecode(metadata)['role'] != Role.admin.toString();
    }).toList();

    return nonHandRaisedParticipants.map((track) {
      final metadata = jsonDecode(track.participant.metadata!);
      final role = metadata['role'];

      final isLocal = track.participant.identity == localParticipant?.identity;
      final participantName = track.participant.name ?? 'Unknown';
      final displayName = isLocal ? '$participantName (you)' : participantName;

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
    }).toList();
  }
}
