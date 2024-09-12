import 'package:flutter/material.dart';
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
  bool _showParticipants = true;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double textScaleFactor = 1.0;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final int numParticipants = widget.participantTracks.length;
                final bool hasPagination = numParticipants > 4;
                final double paginationHeight = 50.0;
                final double adjustedListHeight = constraints.maxHeight - paginationHeight - 16.0;

                if (numParticipants <= 4) {
                  return ListView.builder(
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
                                width: screenSize.width * 0.9, // Use screen width dynamically
                                height: screenSize.height * 0.2, // Use screen height dynamically
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
                          controller: _pageController,
                          itemCount: pageCount,
                          itemBuilder: (context, pageIndex) {
                            final startIndex = pageIndex * itemsPerPage;
                            final endIndex = math.min(
                                startIndex + itemsPerPage, numParticipants);
                            final pageParticipants = widget.participantTracks
                                .sublist(startIndex, endIndex);

                            return ListView.builder(
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
                                          width: screenSize.width * 0.9, // Use screen width dynamically
                                          height: screenSize.height * 0.2, // Use screen height dynamically
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
                          },
                        ),
                      ),
                      if (hasPagination)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: SmoothPageIndicator(
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
