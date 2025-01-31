import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/pages/room-widget/PaginationControls.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantGrid.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';
import 'dart:math' as math;

class ParticipantGridView extends StatefulWidget {
  final List<ParticipantTrack> participantTracks;
  final List<ParticipantStatus> participantStatuses;
  final bool isLocalHost;

  const ParticipantGridView({
    super.key,
    required this.participantTracks,
    required this.participantStatuses,
    required this.isLocalHost,
  });

  @override
  _ParticipantGridViewState createState() => _ParticipantGridViewState();
}

class _ParticipantGridViewState extends State<ParticipantGridView> {
  final PageController _pageController = PageController();
  int? previousStartIndex;
  int? previousEndIndex;
  int? previousNumParticipants;
  int _pag = 0;
  final int bufferSize = 4;

  void subscribe(List<ParticipantTrack> pageParticipants) {
    for (var i = 0; i < pageParticipants.length; i++) {
      final participant = pageParticipants[i].participant;

      if (participant is RemoteParticipant) {
        participant.videoTrackPublications.forEach((publication) {
          if (!publication.subscribed) {
            publication.subscribe();
            publication.enable();
          

            print(
                'Subscribed to ${pageParticipants[i].participant.identity}\'s video track');
          }
        });
      }
    }
  }

  void unsubscribe(List<ParticipantTrack> pageParticipants) {
    for (var i = 0; i < pageParticipants.length; i++) {
      final participant = pageParticipants[i].participant;

      if (participant is RemoteParticipant) {
        participant.videoTrackPublications.forEach((publication) {
          if (publication.subscribed) {
            publication.unsubscribe();
            publication.disable();
           // publication.dispose();
            print(
                'Unsubscribed from ${pageParticipants[i].participant.identity}\'s video track');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0), // Add padding here
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double gridWidth = constraints.maxWidth;
          final double gridHeight = constraints.maxHeight;
          final int numParticipants = widget.participantTracks.length;

          final bool hasPagination = numParticipants > 4;
          final double paginationWidth =
              hasPagination ? 50.0 : 0.0; // Adjust as needed
          final double paginationHeight = 50.0; // Adjust as needed

          final double adjustedGridWidth =
              gridWidth - 2 * paginationWidth - 16.0; // 16.0 for padding
          final double adjustedGridHeight =
              gridHeight - paginationHeight - 16.0; // 16.0 for padding
          print('number of participants: $numParticipants');
          if (numParticipants <= 4) {
            subscribe(widget.participantTracks);
            return ParticipantGrid(
              participantTracks: widget.participantTracks,
              gridWidth: adjustedGridWidth,
              gridHeight: adjustedGridHeight,
              participantStatuses: widget.participantStatuses,
              isLocalHost: widget.isLocalHost,
            );
          } else {
            const int itemsPerPage = 4;
            final int pageCount = (numParticipants / itemsPerPage).ceil();

            return Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pageCount,
                    onPageChanged: (pageIndex) {
                      setState(() {
                        _pag = pageIndex;
                      });

                      int startIndex =
                          math.max(0, (pageIndex - bufferSize) * itemsPerPage);
                      int endIndex = math.min(numParticipants,
                          (pageIndex + 1 + bufferSize) * itemsPerPage);

                      // Get participants to subscribe (current page + buffer)
                      final bufferParticipants = widget.participantTracks
                          .sublist(startIndex, endIndex);
                      print(
                          '🟢 Subscribing from index $startIndex to $endIndex');
                      subscribe(bufferParticipants);

                      // Get participants to unsubscribe (outside the buffer range)
                      final toUnsubscribe =
                          widget.participantTracks.where((track) {
                        int index = widget.participantTracks.indexOf(track);
                        return index < startIndex || index >= endIndex;
                      }).toList();
                      print(
                          '🔴 Unsubscribing outside index $startIndex to $endIndex');
                      unsubscribe(toUnsubscribe);
                    },
                    itemBuilder: (context, pageIndex) {
                      final startIndex = pageIndex * itemsPerPage;
                      final endIndex =
                          math.min(startIndex + itemsPerPage, numParticipants);

                      final pageParticipants = widget.participantTracks
                          .sublist(startIndex, endIndex);
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final double availableWidth = constraints.maxWidth;
                          final double availableHeight = constraints.maxHeight;

                          // Calculate grid dimensions based on available space
                          final double gridWidth = availableWidth;
                          final double gridHeight = availableHeight;

                          return ParticipantGrid(
                            participantTracks: pageParticipants,
                            gridWidth: gridWidth,
                            gridHeight: gridHeight,
                            participantStatuses: widget.participantStatuses,
                            isLocalHost: widget.isLocalHost,
                          );
                        },
                      );
                    },
                  ),
                ),
                if (hasPagination)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 0),
                      child: PaginationControls(
                        pageController: _pageController,
                        pageCount: pageCount,
                        position: PaginationPosition.left,
                      ),
                    ),
                  ),
                if (hasPagination)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: 0),
                      child: PaginationControls(
                        pageController: _pageController,
                        pageCount: pageCount,
                        position: PaginationPosition.right,
                      ),
                    ),
                  ),
                if (hasPagination) const SizedBox(height: 30),
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: pageCount > 4
                        ? Text(
                            'Page ${_pag + 1} of $pageCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : SmoothPageIndicator(
                            controller: _pageController,
                            count: pageCount,
                            effect: JumpingDotEffect(
                              dotWidth: 10.0,
                              dotHeight: 10.0,
                              spacing: 10.0,
                              dotColor: Colors.white,
                              activeDotColor: Colors.black,
                            ),
                          ),
                  ),
                ),
              ],
            );
            // add SmoothPageIndicator here
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
