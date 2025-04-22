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
  final VoidCallback? onTap;
  final double width;
  final double height;

  const MemoizedParticipantCard({
    Key? key,
    required this.track,
    required this.status,
    required this.index,
    required this.isLocalHost,
    required this.width,
    required this.height,
    this.onParticipantsStatusChanged,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4.0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.zero,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: SizedBox(
              width: width,
              height: height,
              child: ParticipantWidget.widgetFor(
                track,
                status,
                showStatsLayer: false,
                participantIndex: index,
                isLocalHost: isLocalHost,
                onParticipantsStatusChanged: onParticipantsStatusChanged!,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoizedParticipantCard &&
        other.track.participant.identity == track.participant.identity &&
        other.status == status &&
        other.index == index &&
        other.isLocalHost == isLocalHost &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode =>
      track.participant.identity.hashCode ^
      status.hashCode ^
      index.hashCode ^
      isLocalHost.hashCode ^
      width.hashCode ^
      height.hashCode;
}
