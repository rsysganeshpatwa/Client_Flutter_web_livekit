// ignore_for_file: file_names

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
    super.key,
  });

  @override
  State<DraggableParticipantWidget> createState() =>
      _DraggableParticipantWidgetState();
}

class _DraggableParticipantWidgetState extends State<DraggableParticipantWidget> with WidgetsBindingObserver {
  double _bottomPosition = 50.0;
  double _rightPosition = 0.0;
  double _height = 150.0;
  double _width = 200.0;

  final double _minWidth = 200;
  final double _maxWidth = 400;
  final double _minHeight = 200.0;
  final double _maxHeight = 400.0;

  bool _isExpanded = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Called when screen size changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureWithinBounds();
    });
  }

  void _ensureWithinBounds() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    setState(() {
      _bottomPosition = _bottomPosition.clamp(0.0, screenHeight - _height);
      _rightPosition = _rightPosition.clamp(0.0, screenWidth - _width);
    });
  }

  void _adjustPositionForBounds(double screenWidth, double screenHeight) {
    if (_isExpanded) {
      if (screenWidth - _rightPosition - _width < 0) {
        _rightPosition = screenWidth - _width;
      }
      if (screenHeight - _bottomPosition - _height < 0) {
        _bottomPosition = screenHeight - _height;
      }
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
      top: screenHeight - _bottomPosition - _height,
      left: screenWidth - _rightPosition - _width,
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
            Positioned(
              top: 0,
              left: 8,
              child: GestureDetector(
                onPanStart: (_) {
                  setState(() => _isDragging = true);
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
                  setState(() => _isDragging = false);
                },
                child: MouseRegion(
                  cursor: _isDragging
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.grab,
                child: !_isDragging
    ? const Tooltip(
        message: 'Drag to move',
        child:  Icon(Icons.drag_handle, color: Colors.white),
      )
    : const Icon(Icons.drag_handle, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                    _height = _isExpanded ? _maxHeight : _minHeight;
                    _width = _isExpanded ? _maxWidth : _minWidth;
                    _adjustPositionForBounds(screenWidth, screenHeight);
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(
                    message: _isExpanded ? 'Minimize View' : 'Expand View',
                    child: const Icon(Icons.open_in_full, color: Colors.white),
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
