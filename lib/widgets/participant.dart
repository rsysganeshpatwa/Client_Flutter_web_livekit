// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/providers/PinnedParticipantProvider.dart';

import 'no_video.dart';
import 'participant_info.dart';

// Add track caching mixin
mixin TrackCacheMixin<T extends StatefulWidget> on State<T> {
  final Map<String, VideoTrack> _videoTrackCache = {};
  final Map<String, AudioTrack> _audioTrackCache = {};
  
  VideoTrack? getCachedVideoTrack(String key, VideoTrack? track) {
    if (track == null) {
      _videoTrackCache.remove(key);
      return null;
    }
    
    if (!_videoTrackCache.containsKey(key) || 
        _videoTrackCache[key] != track) {
      _videoTrackCache[key] = track;
    }
    return _videoTrackCache[key];
  }
  
  AudioTrack? getCachedAudioTrack(String key, AudioTrack? track) {
    if (track == null) {
      _audioTrackCache.remove(key);
      return null;
    }
    
    if (!_audioTrackCache.containsKey(key) || 
        _audioTrackCache[key] != track) {
      _audioTrackCache[key] = track;
    }
    return _audioTrackCache[key];
  }
  
  void clearTrackCache() {
    _videoTrackCache.clear();
    _audioTrackCache.clear();
  }
}

abstract class ParticipantWidget extends StatefulWidget {
  // Convenience method to return relevant widget for participant
  static ParticipantWidget widgetFor(
      ParticipantTrack participantTrack, ParticipantStatus participantStatus,
      {bool showStatsLayer = false,
      int participantIndex = 0,
      VoidCallback? handleExtractText,
      //onParticipantsStatusChanged
      required Function(ParticipantStatus) onParticipantsStatusChanged,
      bool isLocalHost = false,
      
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
          key: ValueKey(participantTrack.participant.sid),
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
          isLocalHost,
          key: ValueKey(participantTrack.participant.sid),
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
    extends State<T> with TrackCacheMixin {
  VideoTrack? get activeVideoTrack;
  AudioTrack? get activeAudioTrack;
  TrackPublication? get videoPublication;
  TrackPublication? get audioPublication;
  bool get isScreenShare => widget.type == ParticipantTrackType.kScreenShare;
  EventsListener<ParticipantEvent>? _listener;
  double _scaleFactor = 1.0;
  double _baseScaleFactor = 1.0;
  Offset _offset = Offset.zero;
  Offset _baseOffset = Offset.zero;
  Offset _initialFocalPoint = Offset.zero;
  
  final double _minScale = 1.0;
  final double _maxScale = 3.0;
  final double _zoomThreshold = 1.0;
  
  // Add state optimization variables
  bool _isDisposed = false;
  bool _isSpeaking = false;
  bool _needsRebuild = false;
  Timer? _debounceTimer;
  
  void _resetZoomAndPan() {
    setState(() {
      _scaleFactor = 1.0;
      _offset = Offset.zero;
    });
  }

  @override
  void initState() {
    super.initState();
    _setupListener();
    widget.participant.addListener(_onParticipantChanged);
    _onParticipantChanged();
  }

  void _setupListener() {
    _listener = widget.participant.createListener()
      ..on<TranscriptionEvent>((e) {
        // Handle transcription
      })
      ..on<SpeakingChangedEvent>((e) {
        // Only update state if the speaking status actually changed
        if (_isSpeaking != e.speaking) {
          _isSpeaking = e.speaking;
          _markNeedsRebuild();
        }
      });
  }

  // Use a debounced rebuild approach
  void _markNeedsRebuild() {
    if (_isDisposed) return;
    
    _needsRebuild = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (_needsRebuild && mounted && !_isDisposed) {
        setState(() {
          _needsRebuild = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    widget.participant.removeListener(_onParticipantChanged);
    _listener?.dispose();
    clearTrackCache();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.participant != widget.participant) {
      oldWidget.participant.removeListener(_onParticipantChanged);
      widget.participant.addListener(_onParticipantChanged);
      clearTrackCache();
      _onParticipantChanged();
    }
  }

  void _onParticipantChanged() {
    if (_isDisposed) return;
    _markNeedsRebuild();
  }

  // Use memoized widget building
  @override
  Widget build(BuildContext ctx) {
    return RepaintBoundary(
      child: _buildParticipantWidget(ctx),
    );
  }

Widget _buildParticipantWidget(BuildContext ctx) {
  return Consumer<PinnedParticipantProvider>(
    builder: (context, pinnedProvider, _) {
      final isPinned = pinnedProvider.isPinned(widget.participantStatus.identity);
      final isSpotlight = widget.participantStatus.isSpotlight;

      return MouseRegion(
        cursor: _scaleFactor > _zoomThreshold
            ? SystemMouseCursors.grab
            : SystemMouseCursors.basic,
        child: Container(
          foregroundDecoration: BoxDecoration(
            border: _isSpeaking &&
                    audioPublication?.subscribed == true &&
                    !isScreenShare
                ? Border.all(width: 5, color: Colors.green)
                : null,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF747474),
            border: Border.all(
              color: isSpotlight
                  ? Colors.orangeAccent
                  : isPinned
                      ? Colors.blueAccent
                      : Colors.transparent,
              width: 3.0,
            ),
          ),
          child: _buildStackContent(ctx, isPinned, isSpotlight),
        ),
      );
    },
  );
}

  Widget _buildStackContent(BuildContext ctx, bool isPinned, bool isSpotlight) {
    // Get cached video track for better performance
    final videoTrack = getCachedVideoTrack(
      '${widget.participant.identity}_${widget.type}',
      activeVideoTrack,
    );
    
    final hasVideo = videoTrack != null && !videoTrack.muted;
      
    return Stack(
      children: [
        // Optimize video renderer with conditional rendering
        GestureDetector(
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          child: ClipRect(
            child: Align(
              alignment: Alignment.center,
              child: hasVideo
                ? _buildVideoRenderer(videoTrack!)
                : const NoVideoWidget(),
            ),
          ),
        ),

        // Optimize conditionally rendered UI elements
        if (widget.handleExtractText != null) _buildControlButtons(),
        
        _buildParticipantInfo(isPinned, isSpotlight),
        
        if (widget.participant.identity == "streamer") _buildLiveBadge(),
        
        if (widget.participant is! LocalParticipant && 
            widget.participantStatus.isHandRaised) _buildHandRaisedIndicator(),
        
        _buildConnectionInfo(),
      ],
    );
  }

  // Extract methods to improve readability and reusability
  void _handleScaleStart(ScaleStartDetails details) {
    _baseScaleFactor = _scaleFactor;
    _baseOffset = _offset;
    _initialFocalPoint = details.focalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scaleFactor = (_baseScaleFactor * details.scale)
          .clamp(_minScale, _maxScale);

      if (_scaleFactor > _minScale) {
        final newFocalPoint = details.focalPoint;
        _offset = _baseOffset + (newFocalPoint - _initialFocalPoint);
      }
    });
  }

  // Optimize video renderer with transform caching
  Widget _buildVideoRenderer(VideoTrack track) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(_offset.dx, _offset.dy)
        ..scale(_scaleFactor),
      child: RepaintBoundary(
        child: VideoTrackRenderer(
          track,
          autoDisposeRenderer: true,
          mirrorMode: VideoViewMirrorMode.off,
        ),
      ),
    );
  }

  // Extract UI components to separate methods
  Widget _buildControlButtons() {
    return Positioned(
      top: 8.0,
      left: 8.0,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.black),
            onPressed: widget.handleExtractText,
            tooltip: 'Perform OCR',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.black),
            onPressed: () => setState(() {
              _scaleFactor = (_scaleFactor + 0.1).clamp(_minScale, _maxScale);
            }),
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.black),
            onPressed: () => setState(() {
              _scaleFactor = (_scaleFactor - 0.1).clamp(_minScale, _maxScale);
            }),
            tooltip: 'Zoom Out',
          ),
          if (_scaleFactor > _zoomThreshold || _offset != Offset.zero)
            IconButton(
              icon: const Icon(Icons.reset_tv, color: Colors.black),
              onPressed: _resetZoomAndPan,
              tooltip: 'Reset Zoom',
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantInfo(bool isPinned, bool isSpotlight) {
    return Positioned(
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
                  ? _formatName(widget.participant.name)
                  : widget.participant.identity,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(width: 2),
          if (widget.isLocalHost) _buildPopupMenu(),
          if (isSpotlight) _buildSpotlightBadge(),
          if (isPinned) _buildPinnedBadge(),
        ],
      ),
    );
  }
  
  Widget _buildPopupMenu() {
    return Consumer<PinnedParticipantProvider>(
      builder: (context, pinnedProvider, _) {
        final isPinned = pinnedProvider.isPinned(widget.participantStatus.identity);
        final isSpotlight = widget.participantStatus.isSpotlight;
        
        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
          color: Colors.grey[900],
          onSelected: (value) {
            switch (value) {
              case 'pin':
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
          itemBuilder: (BuildContext context) => [
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
          ],
        );
      },
    );
  }
  
  Widget _buildSpotlightBadge() {
    return Container(
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
    );
  }
  
  Widget _buildPinnedBadge() {
    return Container(
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
    );
  }

  Widget _buildLiveBadge() {
    return Positioned(
      bottom: 8.0,
      right: 8.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14.0,
          ),
        ),
      ),
    );
  }

  Widget _buildHandRaisedIndicator() {
    return Positioned(
      top: 8.0,
      left: 8.0,
      child: Row(
        children: [
          Text(
            (widget.participantIndex  ).toString(),
            style: const TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 8.0),
          const Icon(
            Icons.pan_tool,
            color: Colors.orange,
            size: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo() {

    
    return Positioned(
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
    );
  }

  String _formatName(String name) {
    if (name.isEmpty) return name;
    return name
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');
  }
  
  void updateSpotLightStatus(ParticipantStatus participantStatus, bool isSpotlight) {
    final updatedStatus = participantStatus.copyWith(
      isSpotlight: isSpotlight,
    );
    widget.onParticipantsStatusChanged(updatedStatus);
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
}
