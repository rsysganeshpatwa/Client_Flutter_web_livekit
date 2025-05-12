// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/pages/room-widget/PaginationControls.dart';
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
  // ignore: library_private_types_in_public_api
  _ParticipantListViewState createState() => _ParticipantListViewState();
}

class _ParticipantListViewState extends State<ParticipantListView> {
  final PageController _pageController = PageController();

  final List<ParticipantTrack> participantTracks = [];
  final List<ParticipantStatus> participantStatuses = [];
  final int itemsPerPage = 4;
  int bufferSize = 2; // 2 pages before and after
  int? previousStartIndex;
  int? previousEndIndex;
  int? previousNumParticipants;
  int _pag = 0;

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
    setState(() {
      participantTracks.clear();
      participantStatuses.clear();
      for (var syncedParticipant in syncedParticipants) {
        participantTracks.add(syncedParticipant.track!);
        participantStatuses.add(syncedParticipant.status!);
      }
      int maxPage = (syncedParticipants.length / 4).ceil() - 1;
      if (maxPage < 0) maxPage = 0;
      _pag = _pag.clamp(0, maxPage);

      _handlePageChange(_pag);
    });
  }

  void subscribe(List<ParticipantTrack> pageParticipants) {
    for (var i = 0; i < pageParticipants.length; i++) {
      final participant = pageParticipants[i].participant;

      if (participant is RemoteParticipant) {
        for (var publication in participant.videoTrackPublications) {
          if (!publication.subscribed) {
            publication.subscribe();
            publication.enable();
          }
        }
      }
    }
  }

  void unsubscribe(List<ParticipantTrack> pageParticipants) {
    for (var i = 0; i < pageParticipants.length; i++) {
      final participant = pageParticipants[i].participant;

      if (participant is RemoteParticipant) {
        for (var publication in participant.videoTrackPublications) {
          if (publication.subscribed) {
            publication.unsubscribe();
            publication.disable();
          }
        }
      }
    }
  }

  void _handlePageChange(int pageIndex) {
    setState(() {
      _pag = pageIndex;
    });

    final int numParticipants = participantTracks.length;

    // Clamp the pageIndex to a valid range
    int maxPage = (numParticipants / itemsPerPage).ceil() - 1;
    if (maxPage < 0) maxPage = 0;
    int safePageIndex = pageIndex.clamp(0, maxPage);

    int bufferBefore = (bufferSize ~/ 2) * itemsPerPage;
    int bufferAfter = (bufferSize - bufferSize ~/ 2) * itemsPerPage;

    final int startIndex =
        math.max(0, (safePageIndex * itemsPerPage) - bufferBefore);
    final int endIndex = math.min(numParticipants,
        (safePageIndex * itemsPerPage) + itemsPerPage + bufferAfter);

    final List<ParticipantTrack> bufferParticipants =
        participantTracks.sublist(startIndex, endIndex);

    final List<ParticipantTrack> toUnsubscribe =
        participantTracks.where((track) {
      int index = participantTracks.indexOf(track);
      return index < startIndex || index >= endIndex;
    }).toList();

    if (toUnsubscribe.isNotEmpty) {
      unsubscribe(toUnsubscribe);
    }

    if (bufferParticipants.isNotEmpty) {
      subscribe(bufferParticipants);
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
                    physics: const NeverScrollableScrollPhysics(),
                    scrollDirection: isMobile ? Axis.horizontal : Axis.vertical,
                    itemCount: numParticipants,
                    itemBuilder: (context, index) {
                      return MemoizedParticipantCard(
                        key: ValueKey(
                            participantTracks[index].participant.identity),
                        track: participantTracks[index],
                        status: participantStatuses.firstWhere(
                          (status) =>
                              status.identity ==
                              participantTracks[index].participant.identity,
                        ),
                        index: index,
                        isLocalHost: widget.isLocalHost,
                        width: isMobile
                            ? screenSize.width * 0.4
                            : screenSize.width * 0.9,
                        height: isMobile
                            ? screenSize.height * 0.15
                            : screenSize.height * 0.2,
                        onParticipantsStatusChanged:
                            widget.onParticipantsStatusChanged,
                      );
                    },
                  );
                } else {
                  final int pageCount = (numParticipants / itemsPerPage).ceil();

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: PageView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          scrollDirection:
                              isMobile ? Axis.horizontal : Axis.vertical,
                          controller: _pageController,
                          itemCount: pageCount,
                          onPageChanged: _handlePageChange,
                          itemBuilder: (context, pageIndex) {
                            final startIndex = pageIndex * itemsPerPage;
                            final endIndex = math.min(
                                startIndex + itemsPerPage, numParticipants);
                            final pageParticipants =
                                participantTracks.sublist(startIndex, endIndex);

                            return ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              scrollDirection:
                                  isMobile ? Axis.horizontal : Axis.vertical,
                              itemCount: pageParticipants.length,
                              itemBuilder: (context, index) {
                                return MemoizedParticipantCard(
                                  key: ValueKey(pageParticipants[index]
                                      .participant
                                      .identity),
                                  track: pageParticipants[index],
                                  status: participantStatuses[participantTracks
                                      .indexOf(pageParticipants[index])],
                                  index: index,
                                  isLocalHost: widget.isLocalHost,
                                  width: isMobile
                                      ? screenSize.width * 0.4
                                      : screenSize.width * 0.9,
                                  height: isMobile
                                      ? screenSize.height * 0.15
                                      : screenSize.height * 0.2,
                                  onParticipantsStatusChanged:
                                      widget.onParticipantsStatusChanged,
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
