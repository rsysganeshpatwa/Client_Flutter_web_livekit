// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/widgets/participant.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';

class MemoizedParticipantCard extends StatelessWidget {
  final ParticipantTrack track;
  final ParticipantStatus status;
  final int index;
  final bool isLocalHost;
  final Function(ParticipantStatus)? onParticipantsStatusChanged;
  // Function to handle participant status changes
  final VoidCallback? onTap;
  final double width;
  final double height;


  const MemoizedParticipantCard({
    super.key,
    required this.track,
    required this.status,
    required this.index,
    required this.isLocalHost,
    required this.width,
    required this.height,
    this.onParticipantsStatusChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
         key: ValueKey(track.participant.sid),
      child: Card(
           key: ValueKey(track.participant.sid),
        elevation: 4.0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        child: Container(
             key: ValueKey(track.participant.sid),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.zero,
          ),
          child: ClipRRect(
            key: ValueKey(track.participant.sid),
            borderRadius: BorderRadius.zero,
            child: SizedBox(
                 key: ValueKey(track.participant.sid),
              width: width,
              height: height,
              child: ParticipantWidget.widgetFor(
                track,
                status,
                showStatsLayer: false,
                participantIndex: index,
                isLocalHost: isLocalHost,
                onParticipantsStatusChanged: onParticipantsStatusChanged!,
                handleExtractText: isLocalHost ? onTap : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
@override
// ignore: invalid_override_of_non_virtual_member
bool operator ==(Object other) =>
    identical(this, other) ||
    other is MemoizedParticipantCard &&
        other.track.participant.identity == track.participant.identity &&
        other.status == status &&
        other.index == index &&
        other.isLocalHost == isLocalHost &&
        other.width == width &&
        other.height == height;

@override
// ignore: invalid_override_of_non_virtual_member
int get hashCode => Object.hash(
      track.participant.identity,
      status,
      index,
      isLocalHost,
      width,
      height,
    );
}
