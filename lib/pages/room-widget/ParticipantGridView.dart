import 'package:flutter/material.dart';
import 'package:video_meeting_room/widgets/participant.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';
import 'dart:math' as math;

class ParticipantGridView extends StatelessWidget {
  final List<ParticipantTrack> participantTracks;
  final int currentPage;
  final int participantsPerPage;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final bool participantScreenShared;
  final bool isScreenShareMode;

  const ParticipantGridView({
    super.key,
    required this.participantTracks,
    required this.currentPage,
    this.participantsPerPage = 6,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.participantScreenShared,
    required this.isScreenShareMode,
  });

  List<ParticipantTrack> _getParticipantsForCurrentPage() {
    final startIndex = currentPage * participantsPerPage;
    final endIndex = startIndex + participantsPerPage;
    return participantTracks.sublist(
      startIndex,
      endIndex > participantTracks.length ? participantTracks.length : endIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0), // Add padding here
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double gridWidth = constraints.maxWidth;
          final double gridHeight = constraints.maxHeight;
          final int numParticipants = participantTracks.length;
          final bool isMobile = gridWidth < 600;

          final int crossAxisCount = (isMobile && numParticipants == 2)
              ? 1
              : (numParticipants > 1)
                  ? (gridWidth / (gridWidth / math.sqrt(numParticipants))).ceil()
                  : 1;

          final int rowCount = (isMobile && numParticipants == 2)
              ? 2
              : (numParticipants / crossAxisCount).ceil();

          final double aspectRatio = (gridWidth / crossAxisCount) / (gridHeight / rowCount);

          return Column(
            children: [
              Expanded(
                child: participantTracks.isNotEmpty
                    ? GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: aspectRatio,
                           crossAxisSpacing: 8.0, // Space between items horizontally
              mainAxisSpacing: 8.0, // Space between items vertically
                        ),
                        itemCount: participantTracks.length,
                        itemBuilder: (context, index) {
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
                                    showStatsLayer: false,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Text(
                          'No Participants',
                          style: TextStyle(
                            fontSize: 18.0,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
