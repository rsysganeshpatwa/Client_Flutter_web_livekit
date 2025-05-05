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
  double _bottomPosition = 50.0; // Default vertical position
  double _rightPosition = 0.0; // Default horizontal position
  double _height = 150.0; // Fixed height of the widget
  double _width = 200.0; // Width of the widget
  final double _minWidth = 200;
  final double _maxWidth = 400;
  final double _minHeight = 200.0; // Minimum height
  final double _maxHeight = 400.0; // Maximum height

  bool _isExpanded = false; // Track whether the widget is expanded or not
  bool _isDragging = false;

    void _adjustPositionForBounds(double screenWidth, double screenHeight) {
    // Adjust position if expanding would push the widget out of bounds
    if (_isExpanded) {
      // Check and adjust for right edge
      if (screenWidth - _rightPosition - _width < 0) {
        _rightPosition = screenWidth - _width;
      }
      
      // Check and adjust for bottom edge
      if (screenHeight - _bottomPosition - _height < 0) {
        _bottomPosition = screenHeight - _height;
      }

      // Check and adjust for top edge
      double topPosition = screenHeight - _bottomPosition - _height;
      if (topPosition < 0) {
        _bottomPosition = screenHeight - _height;
      }
    }
  }

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
          _width, // Set the left position relative to righ
      child: Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          color: Colors.blueGrey,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
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
                  widget.updateParticipantsStatus(status);
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
                onPanStart: (_) {
                  setState(() {
                    _isDragging = true;
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _bottomPosition = (_bottomPosition - details.delta.dy)
                        .clamp(0.0, screenHeight - _height);
                    _rightPosition = (_rightPosition - details.delta.dx)
                        .clamp(0.0, screenWidth - _width);
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _isDragging = false;
                  });
                },
                child:  MouseRegion(
                  cursor: _isDragging
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.grab,
                  child:  Tooltip(
                    message: !_isDragging ? 'Drag to move' : '',
                    child: const Icon(
                      Icons.drag_handle,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
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
                          _adjustPositionForBounds(screenWidth, screenHeight);
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                child: Tooltip(
                    message: _isExpanded ? 'Minimize View' : 'Expand View',
                    child: const Icon(
                      Icons. open_in_full,
                      color: Colors.white,
                      size: 20,
                    ),
                    
              ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
