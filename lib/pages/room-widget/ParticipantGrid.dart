import 'package:flutter/material.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/widgets/participant.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';
import 'dart:math' as math;

class ParticipantGrid extends StatelessWidget {
  final List<ParticipantTrack> participantTracks;
  final double gridWidth;
  final double gridHeight;
  final List<ParticipantStatus> participantStatuses;

  const ParticipantGrid({
    super.key,
    required this.participantTracks,
    required this.gridWidth,
    required this.gridHeight,
    required this.participantStatuses,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = gridWidth < 600;
    final int numParticipants = participantTracks.length;

    final int crossAxisCount = (isMobile && numParticipants == 2)
        ? 1
        : (numParticipants > 1)
            ? (gridWidth / (gridWidth / math.sqrt(numParticipants))).ceil()
            : 1;

    final int rowCount = (isMobile && numParticipants == 2)
        ? 2
        : (numParticipants / crossAxisCount).ceil();

    final double aspectRatio = (gridWidth / crossAxisCount) / (gridHeight / rowCount);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 12.0, // Space between items horizontally
        mainAxisSpacing: 12.0, // Space between items vertically
      ),
      itemCount: participantTracks.length,
      itemBuilder: (context, index) {

        final status = participantStatuses.where((status) => status.identity == participantTracks[index].participant.identity).first;
        return GestureDetector(
          onTap: () {
            // Add interaction logic here
          },
          child: Card(
            elevation: 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: ParticipantWidget.widgetFor(
                  participantTracks[index],
                  status,
                                    showStatsLayer: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
