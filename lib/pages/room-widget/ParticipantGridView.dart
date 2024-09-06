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

  const ParticipantGridView({super.key, 
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final currentParticipants = _getParticipantsForCurrentPage();
    final int numParticipants = participantTracks.length;
    final bool isMobile = screenWidth < 600;
    final int totalPages = (numParticipants / participantsPerPage).ceil();
    final screenShareParticipants = participantTracks
      .where((track) => track.participant.isScreenShareEnabled())
      .toList();

    // Handle screen sharing cases
    if (participantScreenShared && isScreenShareMode) {
      return Center(
        child: Row(
          children: [
            for (var participant in screenShareParticipants)
              
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 2.0),
                  width: screenWidth / 2,
                  height: screenHeight,
                  child: ParticipantWidget.widgetFor(
                    participant,
                    showStatsLayer: false,
                  ),
                ),
              ),
          ],
        ),
      );
    } else if (participantScreenShared && !isScreenShareMode) {
        final visibleParticipants = math.min(6, currentParticipants.length);
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: screenWidth * 0.85,
              child: Row(
                children: [
                  for (var participant in screenShareParticipants)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 2.0),
                        height: screenHeight,
                        child: ParticipantWidget.widgetFor(
                          participant,
                          showStatsLayer: false,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: screenWidth * 0.15,
              child: Container(
                child: Column(
                  children: [
                    Expanded(
                      flex: 9,
                      child: ListView.builder(
                        itemCount: visibleParticipants,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          return Container(
                            height: ((screenHeight * .95) - 8.0 * (visibleParticipants - 1)) / visibleParticipants,
                            margin: EdgeInsets.only(bottom: index == visibleParticipants - 1 ? 0 : 4.0),
                            child: ParticipantWidget.widgetFor(
                              currentParticipants[index],
                              showStatsLayer: false,
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      height: screenHeight * 0.05,
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (numParticipants > 6 && currentPage > 0)
                              IconButton(
                                icon: Icon(Icons.arrow_back),
                                onPressed: onPreviousPage,
                                color: Colors.white,
                              ),
                            Text(
                              '${currentPage + 1} / $totalPages',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            if (numParticipants > 6 && (currentPage + 1) * participantsPerPage < numParticipants)
                              IconButton(
                                icon: Icon(Icons.arrow_forward),
                                onPressed: onNextPage,
                                color: Colors.white, // Arrow color
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      } else {
          final int crossAxisCount = (isMobile && numParticipants == 2)
              ? 1
              : (numParticipants > 1)
                  ? (screenWidth / (screenWidth / math.sqrt(numParticipants))).ceil()
                  : 1;

          final int rowCount = (isMobile && numParticipants == 2)
              ? 2
              : (numParticipants / crossAxisCount).ceil();

          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: currentParticipants.isNotEmpty
                        ? GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 4.0,
                              mainAxisSpacing: 4.0,
                              childAspectRatio: (screenWidth / crossAxisCount) /
                                  (screenHeight / rowCount),
                            ),
                            itemCount: currentParticipants.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                child: Container(
                                  child: ParticipantWidget.widgetFor(
                                    currentParticipants[index],
                                    showStatsLayer: false,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(),
                  ),
                ],
              ),
              if (currentPage > 0)
                Positioned(
                  left: 10,
                  top: MediaQuery.of(context).size.height / 2 - 40,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: onPreviousPage,
                  ),
                ),
              if ((currentPage + 1) * participantsPerPage < participantTracks.length)
                Positioned(
                  right: 10,
                  top: MediaQuery.of(context).size.height / 2 - 40,
                  child: IconButton(
                    icon: Icon(Icons.arrow_forward),
                    onPressed: onNextPage,
                  ),
                ),
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '${currentPage + 1}/$totalPages',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
  }
}
