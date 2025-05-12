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
  //onParticipantsStatusChanged
  final Function(ParticipantStatus) onParticipantsStatusChanged;
  final List<SyncedParticipant>? syncedParticipant;

  const ParticipantGridView({
    super.key,
    required this.syncedParticipant,
    required this.isLocalHost,
    required this.onParticipantsStatusChanged,
  });

  @override
  State<ParticipantGridView> createState() => _ParticipantGridViewState();
}

class _ParticipantGridViewState extends State<ParticipantGridView> {
  final PageController _pageController = PageController();
  int? previousStartIndex;
  int? previousEndIndex;
  int? previousNumParticipants;
  int _pag = 0;
  final int bufferSize = 4;
  final List<ParticipantTrack> participantTracks = [];
  final List<ParticipantStatus> participantStatuses = [];
    // Add subscription tracking

  bool _isDisposed = false;


// update state
  @override
  void initState() {
    super.initState();
    _isDisposed = false;
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
      int maxPage = (syncedParticipants.length / 4).ceil() - 1;
      _pag = _pag.clamp(0, maxPage);


      _handlePageChange(_pag);
    });
  }

  void subscribe(List<ParticipantTrack> pageParticipants) {
    if (_isDisposed) return;

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
    if (_isDisposed) return;
    
    setStateIfMounted(() {
      _pag = pageIndex;
    });

    _updateSubscriptions(pageIndex);
  }

  void _updateSubscriptions(int pageIndex) {
    const int itemsPerPage = 4;
    const int bufferSize = 2;
    final int numParticipants = participantTracks.length;

  // Clamp the pageIndex to a valid range
    int maxPage = (numParticipants / itemsPerPage).ceil() - 1;
    int safePageIndex = pageIndex.clamp(0, maxPage);

    const int bufferBefore = (bufferSize ~/ 2) * itemsPerPage;
    const int bufferAfter = (bufferSize - bufferSize ~/ 2) * itemsPerPage;

    final int startIndex =
        math.max(0, (safePageIndex * itemsPerPage) - bufferBefore);
    final int endIndex = math.min(numParticipants,
        (safePageIndex * itemsPerPage) + itemsPerPage + bufferAfter);


    // Unsubscribe from out-of-view participants
    final toUnsubscribe = participantTracks.where((track) {
      int index = participantTracks.indexOf(track);
      return index < startIndex || index >= endIndex;
    }).toList();

    // Subscribe to in-view participants
    final toSubscribe = participantTracks
        .sublist(startIndex, endIndex)
        .toList();

    unsubscribe(toUnsubscribe);
    subscribe(toSubscribe);
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Unsubscribe from all participants
    unsubscribe(participantTracks);
    _pageController.dispose();
    super.dispose();
  }

  // Helper method for safe setState
  void setStateIfMounted(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
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
          final int numParticipants = participantTracks.length;

          final bool hasPagination = numParticipants > 4;
          final double paginationWidth =
              hasPagination ? 50.0 : 0.0; // Adjust as needed
          const double paginationHeight = 50.0; // Adjust as needed

          final double adjustedGridWidth =
              gridWidth - 2 * paginationWidth - 16.0; // 16.0 for padding
          final double adjustedGridHeight =
              gridHeight - paginationHeight - 16.0; // 16.0 for padding

          if (numParticipants <= 4) {
            subscribe(participantTracks);
            return ParticipantGrid(
              participantTracks: participantTracks,
              gridWidth: adjustedGridWidth,
              gridHeight: adjustedGridHeight,
              participantStatuses: participantStatuses,
              isLocalHost: widget.isLocalHost,
              onParticipantsStatusChanged: widget.onParticipantsStatusChanged,
            );
          } else {
            const int itemsPerPage = 4;
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

                          // Calculate grid dimensions based on available space
                          final double gridWidth = availableWidth;
                          final double gridHeight = availableHeight;

                          return ParticipantGrid(
                            key: ValueKey(pageIndex),
                            participantTracks: pageParticipants,
                            gridWidth: gridWidth,
                            gridHeight: gridHeight,
                            participantStatuses: participantStatuses,
                            isLocalHost: widget.isLocalHost,
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
              ],
            );
            // add SmoothPageIndicator here
          }
        },
      ),
    );
  }
}

