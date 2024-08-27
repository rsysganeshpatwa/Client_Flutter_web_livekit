import 'package:flutter/material.dart';
import 'package:video_meeting_room/widgets/participant.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';

class ParticipantGridView extends StatelessWidget {
  final List<ParticipantTrack> participantTracks;
  final int crossAxisCount;
  final int rowCount;
  final double screenWidth;
  final double screenHeight;

  ParticipantGridView({
    required this.participantTracks,
    required this.crossAxisCount,
    required this.rowCount,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: participantTracks.isNotEmpty
              ? GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 4.0,
                    mainAxisSpacing: 4.0,
                    childAspectRatio: (screenWidth / crossAxisCount) /
                        (screenHeight / rowCount),
                  ),
                  itemCount: participantTracks.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      child: Container(
                        child: ParticipantWidget.widgetFor(
                          participantTracks[index],
                          showStatsLayer: false,
                        ),
                      ),
                    );
                  },
                )
              : Container(),
        ),
      ],
    );
  }
}
