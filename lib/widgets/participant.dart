import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/providers/PinnedParticipantProvider.dart';

import 'no_video.dart';
import 'participant_info.dart';

abstract class ParticipantWidget extends StatefulWidget {
  // Convenience method to return relevant widget for participant
  static ParticipantWidget widgetFor(
      ParticipantTrack participantTrack, ParticipantStatus participantStatus,
      {bool showStatsLayer = false,
      int participantIndex = 0,
      VoidCallback? handleExtractText,
      //onParticipantsStatusChanged
      required Function(ParticipantStatus) onParticipantsStatusChanged,
      bool isLocalHost =false,
      }) {
    if (participantTrack.participant is LocalParticipant) {
      return LocalParticipantWidget(
          participantTrack.participant as LocalParticipant,
          participantTrack.type,
          showStatsLayer,
          participantStatus,
          participantIndex,
          handleExtractText,
          onParticipantsStatusChanged,
          isLocalHost,
          );
    } else if (participantTrack.participant is RemoteParticipant) {
      return RemoteParticipantWidget(
          participantTrack.participant as RemoteParticipant,
          participantTrack.type,
          showStatsLayer,
          participantStatus,
          participantIndex,
          handleExtractText,
          onParticipantsStatusChanged,
          isLocalHost
          );
    }
    throw UnimplementedError('Unknown participant type');
  }

  // Must be implemented by child class
  abstract final Participant participant;
  abstract final ParticipantTrackType type;
  abstract final bool showStatsLayer;
  final VideoQuality quality;
  abstract final ParticipantStatus participantStatus;
  abstract final int participantIndex;
  abstract final VoidCallback? handleExtractText;
  abstract final Function(ParticipantStatus) onParticipantsStatusChanged;
  abstract final bool isLocalHost;

  const ParticipantWidget({
    this.quality = VideoQuality.MEDIUM,
    super.key,
  });
}

class LocalParticipantWidget extends ParticipantWidget {
  @override
  final LocalParticipant participant;
  @override
  final ParticipantTrackType type;
  @override
  final bool showStatsLayer;
  @override
  final int participantIndex;
  @override
  final VoidCallback? handleExtractText;

  @override
  final ParticipantStatus participantStatus;

  @override
  final Function(ParticipantStatus) onParticipantsStatusChanged;

  @override
  final bool isLocalHost;

  const LocalParticipantWidget(
    this.participant,
    this.type,
    this.showStatsLayer,
    this.participantStatus,
    this.participantIndex,
    this.handleExtractText,
    this.onParticipantsStatusChanged,
    this.isLocalHost,
          
     {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _LocalParticipantWidgetState();
}

class RemoteParticipantWidget extends ParticipantWidget {
  @override
  final RemoteParticipant participant;
  @override
  final ParticipantTrackType type;
  @override
  final bool showStatsLayer;
  @override
  final ParticipantStatus participantStatus;
  @override
  final int participantIndex;
  @override
  final VoidCallback? handleExtractText;
  @override
  final Function(ParticipantStatus) onParticipantsStatusChanged;
  @override
  final bool isLocalHost;

  const RemoteParticipantWidget(
    this.participant,
    this.type,
    this.showStatsLayer,
    this.participantStatus,
    this.participantIndex,
    this.handleExtractText, 
    this.onParticipantsStatusChanged,
    this.isLocalHost,
    {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _RemoteParticipantWidgetState();
}

abstract class _ParticipantWidgetState<T extends ParticipantWidget>
    extends State<T> {
  bool _visible = true;
  VideoTrack? get activeVideoTrack;
  AudioTrack? get activeAudioTrack;
  TrackPublication? get videoPublication;
  TrackPublication? get audioPublication;
  bool get isScreenShare => widget.type == ParticipantTrackType.kScreenShare;
  EventsListener<ParticipantEvent>? _listener;
  double _scaleFactor = 1.0; // Default scale factor
  double _baseScaleFactor = 1.0;
  Offset _offset = Offset.zero; // Current translation of the video
  Offset _baseOffset = Offset.zero; // Offset when scaling starts
  Offset _initialFocalPoint = Offset.zero; // Point of contact for panning

  final double _minScale = 1.0; // Minimum zoom level
  final double _maxScale = 3.0; // Maximum zoom level
  final double _zoomThreshold = 1.0; // Zoom threshold for displaying hand mark

  void _resetZoomAndPan() {
    setState(() {
      _scaleFactor = 1.0; // Reset scale to 1
      _offset = Offset.zero; // Reset offset to origin
    });
  }

  @override
  void initState() {
    super.initState();
    _listener = widget.participant.createListener();
    _listener?.on<TranscriptionEvent>((e) {
     
    });
    
    widget.participant.addListener(_onParticipantChanged);
    _onParticipantChanged();
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onParticipantChanged);
    _listener?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    oldWidget.participant.removeListener(_onParticipantChanged);
    widget.participant.addListener(_onParticipantChanged);
    _onParticipantChanged();
    super.didUpdateWidget(oldWidget);
  
  }

  void _onParticipantChanged() => setState(() {});
 void updateSpotLightStatus(ParticipantStatus participantStatus, bool isSpotlight) {
     
    final updatedStatus = participantStatus.copyWith(
      isSpotlight: isSpotlight,
    );
    widget.onParticipantsStatusChanged(updatedStatus);

  }


  List<Widget> extraWidgets(bool isScreenShare) => [];

  @override
  Widget build(BuildContext ctx) {
    

   final pinnedProvider = Provider.of<PinnedParticipantProvider>(ctx);
   final bool isPinned = pinnedProvider.isPinned(widget.participantStatus.identity);
     
    String formatName(String name) {
      if (name.isEmpty) return name;
      return name
          .split(' ')
          .map((word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1).toLowerCase()
              : '')
          .join(' ');
    }

    return MouseRegion(
      cursor: _scaleFactor > _zoomThreshold
          ? SystemMouseCursors.grab // Change cursor to pan icon
          : SystemMouseCursors.basic, // Default cursor
      child: Container(
        foregroundDecoration: BoxDecoration(
          border: widget.participant.isSpeaking &&
                  audioPublication?.subscribed == true &&
                  !isScreenShare
              ? Border.all(width: 5, color: Colors.green)
              : null,
        ),
       decoration: BoxDecoration(
  color  : const Color(0xFF747474), // Default gray
  border: Border.all(
    color: widget.participantStatus.isSpotlight
        ? Colors.orangeAccent
        : isPinned
            ? Colors.blueAccent
            : Colors.transparent,
    width: 3.0,
  ),
 
),
        child: Stack(
          children: [
            // GestureDetector for scaling and panning
            GestureDetector(
              onScaleStart: (ScaleStartDetails details) {
                // Capture the current scale factor and initial drag offset when the gesture starts
                _baseScaleFactor = _scaleFactor;
                _baseOffset = _offset;
                _initialFocalPoint = details.focalPoint;
              },
              onScaleUpdate: (ScaleUpdateDetails details) {
                setState(() {
                  // Multiply the base scale factor with the incremental scale
                  _scaleFactor = (_baseScaleFactor * details.scale)
                      .clamp(_minScale, _maxScale);

                  // Calculate the new offset based on the focal point, allow panning if zoomed in
                  if (_scaleFactor > _minScale) {
                    final newFocalPoint = details.focalPoint;
                    _offset =
                        _baseOffset + (newFocalPoint - _initialFocalPoint);
                  }
                });
              },
              child: ClipRect(
                child: Align(
                  alignment: Alignment.center,
                  child: activeVideoTrack != null && !activeVideoTrack!.muted
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..translate(_offset.dx, _offset.dy)
                            ..scale(_scaleFactor),
                          child: VideoTrackRenderer(
                            activeVideoTrack!,
                            fit: MediaQuery.of(ctx).size.width < 600
                                ? RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover
                                : RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitContain,
                            mirrorMode: VideoViewMirrorMode.off,
                          ),
                        )
                      : const NoVideoWidget(),
                ),
              ),
            ),

           

            // OCR Button
            if (widget.handleExtractText != null)
              Positioned(
                top: 8.0,
                left: 8.0,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        // Call OCR
                        widget.handleExtractText!();
                      },
                      tooltip: 'Perform OCR',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.zoom_in,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          // Increase the scale factor for zooming in, clamp to max scale
                          _scaleFactor =
                              (_scaleFactor + 0.1).clamp(_minScale, _maxScale);
                        });
                      },
                      tooltip: 'Zoom In',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.zoom_out,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          // Decrease the scale factor for zooming out, clamp to min scale
                          _scaleFactor =
                              (_scaleFactor - 0.1).clamp(_minScale, _maxScale);
                        });
                      },
                      tooltip: 'Zoom Out',
                    ),
                    if(_scaleFactor > _zoomThreshold || _offset != Offset.zero)
                    IconButton(
                      icon: Icon(
                        Icons.reset_tv,
                        color: Colors.black,
                      ),
                      onPressed: _resetZoomAndPan,
                      tooltip: 'Reset Zoom',
                    ),
                  ],
                ),
              ),

            // Participant Name Overlay
         Positioned(
  bottom: 8.0,
  left: 8.0,
  child: Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: const Color(0xFF000000).withOpacity(0.5),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(
          widget.participant.name.isNotEmpty
              ? formatName(widget.participant.name)
              : widget.participant.identity,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      
      const SizedBox(width: 2),
      if (widget.isLocalHost)
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
        color: Colors.grey[900],
        onSelected: (value) {
        
          switch (value) {
            case 'pin':
              pinnedProvider.togglePin(widget.participantStatus.identity);
              break;
            case 'unpin':
            pinnedProvider.togglePin(widget.participantStatus.identity);
              break;
            case 'spotlight':
              updateSpotLightStatus(widget.participantStatus, true);
              break;
            case 'unspotlight':
              updateSpotLightStatus(widget.participantStatus, false);
              break;
          }
        },
        itemBuilder: (BuildContext context) {
          final status = widget.participantStatus;
          final isPinned = pinnedProvider.isPinned(widget.participantStatus.identity);
          final isSpotlight = status?.isSpotlight ?? false;

          return [
            PopupMenuItem<String>(
              value: isPinned ? 'unpin' : 'pin',
              child: Text(
                isPinned ? 'Unpin' : 'Pin for Me',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            PopupMenuItem<String>(
              value: isSpotlight ? 'unspotlight' : 'spotlight',
              child: Text(
                isSpotlight ? 'Remove Spotlight' : 'Spotlight for Everyone',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            
          ];
        },
      ),
        if (widget.participantStatus.isSpotlight)
        Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Spotlighted',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      if (isPinned)
        Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Pinned',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
    ],
  ),
),

            // Live Badge for Streamer
            if (widget.participant.identity == "streamer")
              Positioned(
                bottom: 8.0,
                right: 8.0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              ),

            // Hand Raised Indicator
            if (!(widget.participant is LocalParticipant) &&
                widget.participantStatus.isHandRaised)
              Positioned(
                top: 8.0,
                left: 8.0,
                child: Row(
                  children: [
                    Text(
                      (widget.participantIndex + 1).toString(),
                      style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Icon(
                      Icons.pan_tool,
                      color: Colors.orange,
                      size: 30,
                    ),
                  ],
                ),
              ),

            // Participant Info
            Positioned(
              top: 0,
              right: 8.0,
              child: ParticipantInfoWidget(
                title: widget.participant.name.isNotEmpty
                    ? '${widget.participant.name} (${widget.participant.identity})'
                    : widget.participant.identity,
                audioAvailable: widget.participant.isMicrophoneEnabled(),
                publicAudioDisabled: audioPublication?.subscribed == false,
                connectionQuality: widget.participant.connectionQuality,
                isScreenShare: isScreenShare,
                enabledE2EE: widget.participant.isEncrypted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalParticipantWidgetState
    extends _ParticipantWidgetState<LocalParticipantWidget> {
  @override
  LocalTrackPublication<LocalVideoTrack>? get videoPublication =>
      widget.participant.videoTrackPublications
          .where((element) => element.source == widget.type.lkVideoSourceType)
          .firstOrNull;

  @override
  LocalTrackPublication<LocalAudioTrack>? get audioPublication =>
      widget.participant.audioTrackPublications
          .where((element) => element.source == widget.type.lkAudioSourceType)
          .firstOrNull;

  @override
  VideoTrack? get activeVideoTrack => videoPublication?.track;

  @override
  AudioTrack? get activeAudioTrack => audioPublication?.track;
}

class _RemoteParticipantWidgetState
    extends _ParticipantWidgetState<RemoteParticipantWidget> {
  @override
  RemoteTrackPublication<RemoteVideoTrack>? get videoPublication =>
      widget.participant.videoTrackPublications
          .where((element) => element.source == widget.type.lkVideoSourceType)
          .firstOrNull;

  @override
  RemoteTrackPublication<RemoteAudioTrack>? get audioPublication =>
      widget.participant.audioTrackPublications
          .where((element) => element.source == widget.type.lkAudioSourceType)
          .firstOrNull;

  @override
  VideoTrack? get activeVideoTrack => videoPublication?.track;

  @override
  AudioTrack? get activeAudioTrack => audioPublication?.track;

  @override
  List<Widget> extraWidgets(bool isScreenShare) => [
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Menu for RemoteTrackPublication<RemoteAudioTrack>
            if (audioPublication != null)
              RemoteTrackPublicationMenuWidget(
                pub: audioPublication!,
                icon: Icons.volume_up,
              ),
            // Menu for RemoteTrackPublication<RemoteVideoTrack>
            if (videoPublication != null)
              RemoteTrackPublicationMenuWidget(
                pub: videoPublication!,
                icon: isScreenShare ? Icons.monitor : Icons.videocam,
              ),
            if (videoPublication != null)
              RemoteTrackFPSMenuWidget(
                pub: videoPublication!,
                icon: Icons.menu,
              ),
            if (videoPublication != null)
              RemoteTrackQualityMenuWidget(
                pub: videoPublication!,
                icon: Icons.monitor_outlined,
              ),
          ],
        ),
      ];
}

class RemoteTrackPublicationMenuWidget extends StatelessWidget {
  final IconData icon;
  final RemoteTrackPublication pub;
  const RemoteTrackPublicationMenuWidget({
    required this.pub,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withOpacity(0.3),
        child: PopupMenuButton<Function>(
          tooltip: 'Subscribe menu',
          icon: Icon(icon,
              color: {
                TrackSubscriptionState.notAllowed: Colors.red,
                TrackSubscriptionState.unsubscribed: Colors.grey,
                TrackSubscriptionState.subscribed: Colors.green,
              }[pub.subscriptionState]),
          onSelected: (value) => value(),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<Function>>[
            // Subscribe/Unsubscribe
            if (pub.subscribed == false)
              PopupMenuItem(
                child: const Text('Subscribe'),
                value: () => pub.subscribe(),
              )
            else if (pub.subscribed == true)
              PopupMenuItem(
                child: const Text('Un-subscribe'),
                value: () => pub.unsubscribe(),
              ),
          ],
        ),
      );
}

class RemoteTrackFPSMenuWidget extends StatelessWidget {
  final IconData icon;
  final RemoteTrackPublication pub;
  const RemoteTrackFPSMenuWidget({
    required this.pub,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withOpacity(0.3),
        child: PopupMenuButton<Function>(
          tooltip: 'Preferred FPS',
          icon: Icon(icon, color: Colors.white),
          onSelected: (value) => value(),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<Function>>[
            PopupMenuItem(
              child: const Text('30'),
              value: () => pub.setVideoFPS(30),
            ),
            PopupMenuItem(
              child: const Text('15'),
              value: () => pub.setVideoFPS(15),
            ),
            PopupMenuItem(
              child: const Text('8'),
              value: () => pub.setVideoFPS(8),
            ),
          ],
        ),
      );
}

class RemoteTrackQualityMenuWidget extends StatelessWidget {
  final IconData icon;
  final RemoteTrackPublication pub;
  const RemoteTrackQualityMenuWidget({
    required this.pub,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withOpacity(0.3),
        child: PopupMenuButton<Function>(
          tooltip: 'Preferred Quality',
          icon: Icon(icon, color: Colors.white),
          onSelected: (value) => value(),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<Function>>[
            PopupMenuItem(
              child: const Text('HIGH'),
              value: () => pub.setVideoQuality(VideoQuality.HIGH),
            ),
            PopupMenuItem(
              child: const Text('MEDIUM'),
              value: () => pub.setVideoQuality(VideoQuality.MEDIUM),
            ),
            PopupMenuItem(
              child: const Text('LOW'),
              value: () => pub.setVideoQuality(VideoQuality.LOW),
            ),
          ],
        ),
      );
}
