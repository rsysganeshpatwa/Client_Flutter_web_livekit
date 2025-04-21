import 'package:flutter/material.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/widgets/participant.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';

class DraggableParticipantWidget extends StatefulWidget {
  final ParticipantTrack localParticipantTrack;
  final ParticipantStatus localParticipantStatus;
  final String localParticipantRole;
  final Function updateParticipantsStatus;

  const DraggableParticipantWidget({
    required this.localParticipantTrack,
    required this.localParticipantStatus,
    required this.localParticipantRole,
    required this.updateParticipantsStatus,
    Key? key,
  }) : super(key: key);

  @override
  _DraggableParticipantWidgetState createState() =>
      _DraggableParticipantWidgetState();
}

class _DraggableParticipantWidgetState
    extends State<DraggableParticipantWidget> {
  double _bottomPosition = 0.0; // Default vertical position
  double _rightPosition = 0.0; // Default horizontal position
  double _initialTopPosition = 0.0; // Initial top position when drag starts
  double _initialLeftPosition = 0.0; // Initial left position when drag starts
  double _height = 150.0; // Fixed height of the widget
  double _width = 200.0; // Width of the widget
  final double _minWidth = 200;
  final double _maxWidth = 400;
  final double _minHeight = 200.0; // Minimum height
  final double _maxHeight = 400.0; // Maximum height

  bool _isExpanded = false; // Track whether the widget is expanded or not

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      top: screenHeight -
          _bottomPosition -
          _height, // Set the top position relative to bottom
      left: screenWidth -
          _rightPosition -
          _width, // Set the left position relative to right
      child: GestureDetector(
        onPanStart: (details) {
          // Store initial position when the drag starts
          _initialTopPosition = _bottomPosition;
          _initialLeftPosition = _rightPosition;
        },
        onPanUpdate: (details) {},
        child: MouseRegion(
          onEnter: (_) {
            // Change the cursor to a drag icon when mouse enters the widget
            SystemMouseCursors.move;
          },
          child: Container(
            width: _width,
            height: _height,
            decoration: BoxDecoration(
              color: Colors.blueGrey,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Stack(
              children: [
                // Participant widget (Content of the participant)
                Positioned.fill(
                  child: ParticipantWidget.widgetFor(
                    widget.localParticipantTrack,
                    widget.localParticipantStatus,
                    showStatsLayer: false,
                    participantIndex: 0,
                    handleExtractText: null,
                    onParticipantsStatusChanged: (ParticipantStatus status) {
                      widget.updateParticipantsStatus([status]);
                    },
                    isLocalHost:
                        widget.localParticipantRole == Role.admin.toString(),
                  ),
                ),
                // Draggable Icon (top right)
                Positioned(
                  top: 0,
                  left: 8,
                  child: GestureDetector(
                    onPanStart: (details) {
                      // Store initial position when the drag starts
                      _initialTopPosition = _bottomPosition;
                      _initialLeftPosition = _rightPosition;
                    },
                    onPanUpdate: (details) {
                      // Calculate the new position based on the drag
                      setState(() {
                        _bottomPosition = (_initialTopPosition -
                                details.localPosition.dy)
                            .clamp(
                                0.0,
                                screenHeight -
                                    _height); // Keep it within screen bounds
                        _rightPosition =
                            (_initialLeftPosition - details.localPosition.dx)
                                .clamp(
                                    0.0,
                                    screenWidth -
                                        _width); // Keep it within screen bounds
                      });
                    },
                    child: Icon(
                      Icons.drag_indicator,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                // Expand/Collapse Icon (top right)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      // Toggle height when clicked
                      setState(() {
                        _isExpanded = !_isExpanded;
                        _height = _isExpanded ? _maxHeight : _minHeight;
                        _width = _isExpanded
                            ? _maxWidth
                            : _minWidth; // Toggle between max and min height
                      });
                    },
                    child: Icon(
                      _isExpanded ? Icons.open_in_new : Icons.open_in_new_off,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
