// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/pages/room-widget/PaginationControls.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantGrid.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';
import 'dart:math' as math;

class ParticipantGridView extends StatefulWidget {
  final bool isLocalHost;
  final Function(ParticipantStatus) onParticipantsStatusChanged;
  final List<SyncedParticipant>? syncedParticipant;
  final List<ParticipantStatus> handRaisedList;
  final int gridSize; // Add this parameter - either 4 or 8

  const ParticipantGridView({
    super.key,
    required this.syncedParticipant,
    required this.isLocalHost,
    required this.onParticipantsStatusChanged,
    required this.handRaisedList,
    this.gridSize = 4, // Default to 4 if not specified
  }) : assert(gridSize == 4 || gridSize == 8, 'gridSize must be either 4 or 8');

  @override
  State<ParticipantGridView> createState() => _ParticipantGridViewState();
}

class _ParticipantGridViewState extends State<ParticipantGridView> {
  final PageController _pageController = PageController();
  int? previousStartIndex;
  int? previousEndIndex;
  int? previousNumParticipants;
  int _pag = 0;
  
  final List<ParticipantTrack> participantTracks = [];
  final List<ParticipantStatus> participantStatuses = [];

  @override
  void initState() {
    super.initState();
    if (widget.syncedParticipant != null) {
      updateState(widget.syncedParticipant!);
    }
  }

  @override
  void didUpdateWidget(ParticipantGridView oldWidget) {
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
      int maxPage = (syncedParticipants.length / widget.gridSize).ceil() - 1;
      _pag = _pag.clamp(0, maxPage);

      _handlePageChange(_pag);
    });
  }

  void subscribe(List<ParticipantTrack> pageParticipants) {

    for (var participantTrack in pageParticipants) {
      final participant = participantTrack.participant;
      if (participant is! RemoteParticipant) continue;

      for (var publication in participant.videoTrackPublications) {
        if (!publication.subscribed) {
          publication.subscribe();
          publication.enable();
        }
      }
    }
  }

  void unsubscribe(List<ParticipantTrack> pageParticipants) {
    for (var participantTrack in pageParticipants) {
      final participant = participantTrack.participant;
      if (participant is! RemoteParticipant) continue;

      for (var publication in participant.videoTrackPublications) {
        if (publication.subscribed) {
          publication.unsubscribe();
          publication.disable();
        }
      }
    }
  }

  void _handlePageChange(int pageIndex) {
  
    setStateIfMounted(() {
      _pag = pageIndex;
    });

    _updateSubscriptions(pageIndex);
  }

  void _updateSubscriptions(int pageIndex) {
    final int itemsPerPage = widget.gridSize; // Use gridSize instead of hardcoded value
    final int bufferSize =(itemsPerPage/2) as int;
    final int numParticipants = participantTracks.length;

    int maxPage = (numParticipants / itemsPerPage).ceil() - 1;
    int safePageIndex = pageIndex.clamp(0, maxPage);

    final int bufferBefore = (bufferSize ~/ 2) * itemsPerPage;
    final int bufferAfter = (bufferSize - bufferSize ~/ 2) * itemsPerPage;

    final int startIndex =
        math.max(0, (safePageIndex * itemsPerPage) - bufferBefore);
    final int endIndex = math.min(numParticipants,
        (safePageIndex * itemsPerPage) + itemsPerPage + bufferAfter);

    final toUnsubscribe = participantTracks.where((track) {
      int index = participantTracks.indexOf(track);
      return index < startIndex || index >= endIndex;
    }).toList();

    final toSubscribe = participantTracks.sublist(startIndex, endIndex).toList();

    unsubscribe(toUnsubscribe);
    subscribe(toSubscribe);
  }

  @override
  void dispose() {
    
    unsubscribe(participantTracks);
    _pageController.dispose();
    super.dispose();
  }

  void setStateIfMounted(VoidCallback fn) {
    if ( mounted) {
      setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double gridWidth = constraints.maxWidth;
          final double gridHeight = constraints.maxHeight;
          final int numParticipants = participantTracks.length;

          final bool hasPagination = numParticipants > widget.gridSize;
          final double paginationWidth =
              hasPagination ? 50.0 : 0.0;
          const double paginationHeight = 50.0;

          final double adjustedGridWidth =
              gridWidth - 2 * paginationWidth - 16.0;
          final double adjustedGridHeight =
              gridHeight - paginationHeight - 16.0;

          if (numParticipants <= widget.gridSize) {
            subscribe(participantTracks);
            return ParticipantGrid(
              participantTracks: participantTracks,
              handRaisedList: widget.handRaisedList,
              gridWidth: adjustedGridWidth,
              gridHeight: adjustedGridHeight,
              participantStatuses: participantStatuses,
              isLocalHost: widget.isLocalHost,
              onParticipantsStatusChanged: widget.onParticipantsStatusChanged,
              gridSize: widget.gridSize, // Pass the grid size
            );
          } else {
            final int itemsPerPage = widget.gridSize;
            final int pageCount = (numParticipants / itemsPerPage).ceil();

            return Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _pageController,
                    itemCount: pageCount,
                    onPageChanged: (pageIndex) {
                      _handlePageChange(pageIndex);
                    },
                    itemBuilder: (context, pageIndex) {
                      final startIndex = pageIndex * itemsPerPage;
                      final endIndex =
                          math.min(startIndex + itemsPerPage, numParticipants);

                      final pageParticipants =
                          participantTracks.sublist(startIndex, endIndex);
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final double availableWidth = constraints.maxWidth;
                          final double availableHeight = constraints.maxHeight;

                          final double gridWidth = availableWidth;
                          final double gridHeight = availableHeight;

                          return ParticipantGrid(
                            key: ValueKey(pageIndex),
                            participantTracks: pageParticipants,
                            handRaisedList: widget.handRaisedList,
                            gridWidth: gridWidth,
                            gridHeight: gridHeight,
                            participantStatuses: participantStatuses,
                            isLocalHost: widget.isLocalHost,
                            onParticipantsStatusChanged:
                                widget.onParticipantsStatusChanged,
                            gridSize: widget.gridSize, // Pass the grid size
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
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 0),
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
                    child: pageCount > widget.gridSize/2
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
              ],
            );
          }
        },
      ),
    );
  }
}

