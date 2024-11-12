import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/pages/room-widget/PaginationControls.dart';
import 'package:video_meeting_room/widgets/participant.dart';
import 'dart:math' as math;

import 'package:video_meeting_room/widgets/participant_info.dart';

class ParticipantListView extends StatefulWidget {
  final List<ParticipantTrack> participantTracks;
  final List<ParticipantStatus> participantStatuses;

  const ParticipantListView({
    super.key,
    required this.participantTracks,
    required this.participantStatuses,
  });

  @override
  _ParticipantListViewState createState() => _ParticipantListViewState();
}

class _ParticipantListViewState extends State<ParticipantListView> {
  final PageController _pageController = PageController();


  int? previousStartIndex;
  int? previousEndIndex;
  int? previousNumParticipants;
    int _pag = 0;

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
            print(
                'Unsubscribed from ${pageParticipants[i].participant.identity}\'s video track');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    final isMobile = screenSize.width < 600;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final int numParticipants = widget.participantTracks.length;
                final bool hasPagination = numParticipants > 4;
             
                if (numParticipants <= 4) {
                  subscribe(widget.participantTracks);
                  return ListView.builder(
                    scrollDirection: isMobile ? Axis.horizontal : Axis.vertical,
                    itemCount: numParticipants,
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
                              child: SizedBox(
                                width: isMobile
                                    ? screenSize.width * 0.4 // Smaller width for horizontal scroll on mobile
                                    : screenSize.width * 0.9, // Default width for vertical scroll
                                height: isMobile
                                    ? screenSize.height * 0.15 // Smaller height for horizontal scroll on mobile
                                    : screenSize.height * 0.2, // Default height for vertical scroll
                                child: ParticipantWidget.widgetFor(
                                  widget.participantTracks[index],
                                  widget.participantStatuses[index],
                                  showStatsLayer: false,
                                  participantIndex: index,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  final int itemsPerPage = 4;
                  final int pageCount = (numParticipants / itemsPerPage).ceil();

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: PageView.builder(
                          scrollDirection: isMobile ? Axis.horizontal : Axis.vertical,
                          controller: _pageController,
                          itemCount: pageCount,
                          
                          onPageChanged: (pageIndex) {
                            
                            final startIndex = pageIndex * itemsPerPage;
                            final endIndex = math.min(startIndex + itemsPerPage, numParticipants);
                            setState(() {
                              _pag = pageIndex;
                            });

                            // Define a buffer size for prefetching participants before and after the current page
                            int bufferSize = 4; // Adjust as needed

                            if (startIndex != previousStartIndex ||
                                endIndex != previousEndIndex ||
                                numParticipants != previousNumParticipants) {
                              // Determine the buffer range
                              int bufferStartIndex = (startIndex - bufferSize)
                                  .clamp(0, widget.participantTracks.length);
                              int bufferEndIndex = (endIndex + bufferSize)
                                  .clamp(0, widget.participantTracks.length);

                              final bufferParticipants = widget.participantTracks
                                  .sublist(bufferStartIndex, bufferEndIndex);

                              // Subscribe to current page participants and buffer participants
                              subscribe(bufferParticipants);

                              // Unsubscribe participants not in the buffer range
                              unsubscribe(widget.participantTracks
                                  .where((track) =>
                                      widget.participantTracks.indexOf(track) <
                                          bufferStartIndex ||
                                      widget.participantTracks.indexOf(track) >=
                                          bufferEndIndex)
                                  .toList());

                              // Update previous indices
                              previousStartIndex = startIndex;
                              previousEndIndex = endIndex;
                              previousNumParticipants = numParticipants;
                            }
                          },
                          itemBuilder: (context, pageIndex) {
                            final startIndex = pageIndex * itemsPerPage;
                            final endIndex = math.min(startIndex + itemsPerPage, numParticipants);
                            final pageParticipants = widget.participantTracks.sublist(startIndex, endIndex);

                            return ListView.builder(
                              scrollDirection: isMobile ? Axis.horizontal : Axis.vertical,
                              itemCount: pageParticipants.length,
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
                                        child: SizedBox(
                                          width: isMobile
                                              ? screenSize.width * 0.4 // Smaller width for horizontal scroll on mobile
                                              : screenSize.width * 0.9, // Default width for vertical scroll
                                          height: isMobile
                                              ? screenSize.height * 0.15 // Smaller height for horizontal scroll on mobile
                                              : screenSize.height * 0.2, // Default height for vertical scroll
                                          child: ParticipantWidget.widgetFor(
                                            pageParticipants[index],
                                            widget.participantStatuses[widget.participantTracks.indexOf(pageParticipants[index])],
                                            showStatsLayer: false,
                                            participantIndex: index,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      if (hasPagination)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: pageCount > 4
                        ? Text(
                            'Page ${_pag+ 1} of $pageCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        :  SmoothPageIndicator(
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
                      if (hasPagination)
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 0),
                            child: PaginationControls(
                              pageController: _pageController,
                              pageCount: pageCount,
                              position: PaginationPosition.left,
                            ),
                          ),
                        ),
                      if (hasPagination)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 0),
                            child: PaginationControls(
                              pageController: _pageController,
                              pageCount: pageCount,
                              position: PaginationPosition.right,
                            ),
                          ),
                        ),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
