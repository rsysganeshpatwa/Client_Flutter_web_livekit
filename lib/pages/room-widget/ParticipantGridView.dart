import 'package:flutter/material.dart';
import 'package:video_meeting_room/widgets/participant.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';
import 'dart:math' as math;

class ParticipantGridView extends StatelessWidget {
  final List<ParticipantTrack> participantTracks;

  const ParticipantGridView({super.key, 
    required this.participantTracks,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final int numParticipants = participantTracks.length;
    final bool isMobile = screenWidth < 600;

    final int crossAxisCount = (isMobile && numParticipants == 2)
        ? 1
        : (numParticipants > 1)
            ? (screenWidth / (screenWidth / math.sqrt(numParticipants))).ceil()
            : 1;

    final int rowCount = (isMobile && numParticipants == 2)
        ? 2
        : (numParticipants / crossAxisCount).ceil();

    return Column(
      children: [
        Expanded(
          child: participantTracks.isNotEmpty
              ? GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: (screenWidth / crossAxisCount) /
                        (screenHeight / rowCount),
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
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Container(
                          decoration: BoxDecoration(                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
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
  }
}
