import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/pages/room-widget/PaginationControls.dart';
import 'package:video_meeting_room/widgets/participant.dart';
import 'package:video_meeting_room/widgets/MemoizedParticipantCard.dart';
import 'dart:math' as math;

import 'package:video_meeting_room/widgets/participant_info.dart';

class ParticipantListView extends StatefulWidget {
  //onParticipantsStatusChanged
  final List<SyncedParticipant>? syncedParticipant;
  final Function(ParticipantStatus)? onParticipantsStatusChanged;
  final bool isLocalHost;

  const ParticipantListView({
    super.key,
    this.syncedParticipant,
    required this.isLocalHost,
    this.onParticipantsStatusChanged,
  });

  @override
  _ParticipantListViewState createState() => _ParticipantListViewState();
}

class _ParticipantListViewState extends State<ParticipantListView> {
  final PageController _pageController = PageController();

  final List<ParticipantTrack> participantTracks = [];
  final List<ParticipantStatus> participantStatuses = [];

// update state
  @override
  void initState() {
    super.initState();
    if (widget.syncedParticipant != null) {
      updateState(widget.syncedParticipant!);
    }
  }

  @override
  void didUpdateWidget(ParticipantListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncedParticipant != null &&
        widget.syncedParticipant != oldWidget.syncedParticipant) {
      updateState(widget.syncedParticipant!);
    }
  }

  void updateState(List<SyncedParticipant> syncedParticipants) {
    final newTracks = <ParticipantTrack>[];
    final newStatuses = <ParticipantStatus>[];
    
    for (var participant in syncedParticipants) {
      newTracks.add(participant.track!);
      newStatuses.add(participant.status!);
    }
    
    setState(() {
      // Clear existing lists before adding new items
      participantTracks.clear();
      participantStatuses.clear();
      participantTracks.addAll(newTracks);
      participantStatuses.addAll(newStatuses);
    });
  }

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
                final int numParticipants = participantTracks.length;
                final bool hasPagination = numParticipants > 4;

                if (numParticipants <= 4) {
                  subscribe(participantTracks);
                  return ListView.builder(
                    scrollDirection: isMobile ? Axis.horizontal : Axis.vertical,
                    itemCount: numParticipants,
                    itemBuilder: (context, index) {
                      return MemoizedParticipantCard(
                        key: ValueKey(participantTracks[index].participant.identity),
                        track: participantTracks[index],
                        status: participantStatuses.firstWhere(
                          (status) => status.identity == participantTracks[index].participant.identity,
                        ),
                        index: index,
                        isLocalHost: widget.isLocalHost,
                        width: isMobile ? screenSize.width * 0.4 : screenSize.width * 0.9,
                        height: isMobile ? screenSize.height * 0.15 : screenSize.height * 0.2,
                        onParticipantsStatusChanged: widget.onParticipantsStatusChanged,
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
                          scrollDirection:
                              isMobile ? Axis.horizontal : Axis.vertical,
                          controller: _pageController,
                          itemCount: pageCount,
                          onPageChanged: (pageIndex) {
                            final startIndex = pageIndex * itemsPerPage;
                            final endIndex = math.min(
                                startIndex + itemsPerPage, numParticipants);
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
                                  .clamp(0, participantTracks.length);
                              int bufferEndIndex = (endIndex + bufferSize)
                                  .clamp(0, participantTracks.length);

                              final bufferParticipants = participantTracks
                                  .sublist(bufferStartIndex, bufferEndIndex);

                              // Subscribe to current page participants and buffer participants
                              subscribe(bufferParticipants);

                              // Unsubscribe participants not in the buffer range
                              unsubscribe(participantTracks
                                  .where((track) =>
                                      participantTracks.indexOf(track) <
                                          bufferStartIndex ||
                                      participantTracks.indexOf(track) >=
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
                            final endIndex = math.min(
                                startIndex + itemsPerPage, numParticipants);
                            final pageParticipants =
                                participantTracks.sublist(startIndex, endIndex);

                            return ListView.builder(
                              scrollDirection:
                                  isMobile ? Axis.horizontal : Axis.vertical,
                              itemCount: pageParticipants.length,
                              itemBuilder: (context, index) {
                                return MemoizedParticipantCard(
                                  key: ValueKey(pageParticipants[index].participant.identity),
                                  track: pageParticipants[index],
                                  status: participantStatuses[
                                      participantTracks.indexOf(
                                          pageParticipants[index])],
                                  index: index,
                                  isLocalHost: widget.isLocalHost,
                                  width: isMobile ? screenSize.width * 0.4 : screenSize.width * 0.9,
                                  height: isMobile ? screenSize.height * 0.15 : screenSize.height * 0.2,
                                  onParticipantsStatusChanged: widget.onParticipantsStatusChanged,
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
                                    'Page ${_pag + 1} of $pageCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : SmoothPageIndicator(
                                    controller: _pageController,
                                    count: pageCount,
                                    effect: const JumpingDotEffect(
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
    // Clean up all subscriptions
    for (var track in participantTracks) {
      if (track.participant is RemoteParticipant) {
        unsubscribe([track]);
      }
    }
    _pageController.dispose();
    super.dispose();
  }
}
