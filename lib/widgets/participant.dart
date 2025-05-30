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

  Offset _offset = Offset.zero;

  
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

// Updated _buildStackContent method to fix nesting issues
Widget _buildStackContent(BuildContext ctx, bool isPinned, bool isSpotlight) {
  // Get cached video track for better performance
  final videoTrack = getCachedVideoTrack(
    '${widget.participant.identity}_${widget.type}',
    activeVideoTrack,
  );
  
  final hasVideo = videoTrack != null && !videoTrack.muted;
  final isAudioMuted = audioPublication?.subscribed == false;
    
  return Stack(
    fit: StackFit.expand,
    children: [
      // Main content (NO Positioned for main content!)
      ClipRect(
        child: Align(
          alignment: Alignment.center,
          child: GestureDetector(
            // onScaleStart: (details) {
            //   _offset = details.localFocalPoint;
            // },
            // onScaleUpdate: (details) {
            //   setState(() {
            //     _scaleFactor = (_scaleFactor * details.scale).clamp(_minScale, _maxScale);
            //     _offset = details.localFocalPoint;
            //   });
            // },
            child: hasVideo
              ? _buildVideoRenderer(videoTrack)
              : NoVideoWidget(name: widget.participant.name.isNotEmpty
                  ? widget.participant.name
                  : widget.participant.identity),
          ),
        ),
      ),

      // Top gradient overlay - now correctly in Stack
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 45,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.1),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),

      // Bottom gradient overlay - more subtle and shorter
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 45,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.1),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),

      // Top-left indicators
      if (widget.participantStatus.isHandRaised)
        _buildHandRaisedIndicator(),
        
      // Top-right indicators
      _buildConnectionInfo(),
      
      // Bottom section with participant info
      _buildParticipantInfo(isPinned, isSpotlight, isAudioMuted),
      
      // Controls (zoom and OCR)
      if (widget.handleExtractText != null || _scaleFactor > _minScale)
        _buildControlButtons(),
        
      // LIVE badge
      if (widget.participant.identity == "streamer")
        _buildLiveBadge(),
    ],
  );
}

Widget _buildConnectionInfo() {

    
    return Positioned(
      top: 8.0,
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

// Updated control buttons
Widget _buildControlButtons() {
  return Positioned(
    top: 8.0,
    left: widget.participantStatus.isHandRaised ? 48.0 : 8.0,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.handleExtractText != null)
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              onPressed: widget.handleExtractText,
              tooltip: 'Perform OCR',
              iconSize: 18.0,
              padding: const EdgeInsets.all(4.0),
              constraints: const BoxConstraints(
                minWidth: 28.0,
                minHeight: 28.0,
              ),
              splashRadius: 16.0,
            ),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white),
            onPressed: () => setState(() {
              _scaleFactor = (_scaleFactor + 0.1).clamp(_minScale, _maxScale);
            }),
            tooltip: 'Zoom In',
            iconSize: 18.0,
            padding: const EdgeInsets.all(4.0),
            constraints: const BoxConstraints(
              minWidth: 28.0,
              minHeight: 28.0,
            ),
            splashRadius: 16.0,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white),
            onPressed: () => setState(() {
              _scaleFactor = (_scaleFactor - 0.1).clamp(_minScale, _maxScale);
            }),
            tooltip: 'Zoom Out',
            iconSize: 18.0,
            padding: const EdgeInsets.all(4.0),
            constraints: const BoxConstraints(
              minWidth: 28.0,
              minHeight: 28.0,
            ),
            splashRadius: 16.0,
          ),
          if (_scaleFactor > _zoomThreshold || _offset != Offset.zero)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _resetZoomAndPan,
              tooltip: 'Reset Zoom',
              iconSize: 18.0,
              padding: const EdgeInsets.all(4.0),
              constraints: const BoxConstraints(
                minWidth: 28.0,
                minHeight: 28.0,
              ),
              splashRadius: 16.0,
            ),
        ],
      ),
    ),
  );
}

// Updated participant info
Widget _buildParticipantInfo(bool isPinned, bool isSpotlight, bool isAudioMuted) {
  return Positioned(
    bottom: 8.0,
    left: 8.0,
    right: 8.0,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Name with container
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name container
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name text
                      Flexible(
                        child: Text(
                          widget.participant.name.isNotEmpty
                              ? _formatName(widget.participant.name)
                              : widget.participant.identity,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Spotlight badge after name
              if (isSpotlight)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Spotlighted',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        
        // Right side badges and menu
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pin badge
            if (isPinned)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Pinned',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            
            // Menu for admins
            if (widget.isLocalHost)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                  color: const Color(0xFF353535),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  tooltip: 'More options',
                  splashRadius: 16,
                  onSelected: (value) {
                    switch (value) {
                      case 'pin':
                      case 'unpin':
                        Provider.of<PinnedParticipantProvider>(context, listen: false)
                            .togglePin(widget.participantStatus.identity);
                        break;
                      case 'spotlight':
                        updateSpotLightStatus(widget.participantStatus, true);
                        break;
                      case 'unspotlight':
                        updateSpotLightStatus(widget.participantStatus, false);
                        break;
                      case 'mute':
                        if (audioPublication != null) {
                          updateIsAbleToTalkStatus(
                            widget.participantStatus,
                            !widget.participantStatus.isTalkToHostEnable,
                          );
                        }
                        break;
                      default:
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    final isPinnedLocal = Provider.of<PinnedParticipantProvider>(context, listen: false)
                        .isPinned(widget.participantStatus.identity);
                    final isSpotlightLocal = widget.participantStatus.isSpotlight;
                    
                    return [
                      PopupMenuItem<String>(
                        value: isPinnedLocal ? 'unpin' : 'pin',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(
                              isPinnedLocal ? Icons.push_pin : Icons.push_pin_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPinnedLocal ? 'Unpin' : 'Pin for Me',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: isSpotlightLocal ? 'unspotlight' : 'spotlight',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(
                              isSpotlightLocal ? Icons.highlight_off : Icons.highlight,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isSpotlightLocal ? 'Remove Spotlight' : 'Spotlight for Everyone',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      // PopupMenuItem<String>(
                      //   value: 'mute',
                      //   height: 36,
                      //   child: Row(
                      //     children: [
                      //       Icon(
                      //         isAudioMuted ? Icons.mic_off : Icons.mic,
                      //         color: Colors.white,
                      //         size: 16,
                      //       ),
                      //       const SizedBox(width: 8),
                      //       Text(
                      //         isAudioMuted ? 'Unmute' : 'Mute',
                      //         style: const TextStyle(color: Colors.white),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ];
                  },
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

// Updated hand raised indicator with cleaner design
Widget _buildHandRaisedIndicator() {
  return Positioned(
    top: 8.0,
    left: 8.0,
    child: Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.pan_tool,
            color: Color(0xFFFF9800),
            size: 24,
          ),
          if (widget.participantIndex > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFF44336),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Center(
                  child: Text(
                    widget.participantIndex.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

// Updated LIVE badge
Widget _buildLiveBadge() {
  return Positioned(
    top: 8.0,
    left: 0,
    right: 0,
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF44336),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12.0,
          ),
        ),
      ),
    ),
  );
}

Widget _buildVideoRenderer(VideoTrack track) {
  return ClipRect(
    child: Transform(
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

  // update is able to talk host 
  void updateIsAbleToTalkStatus(ParticipantStatus participantStatus, bool isAbleToTalk) {
    final updatedStatus = participantStatus.copyWith(
      isTalkToHostEnable: isAbleToTalk,
      isAudioEnable: participantStatus.isAudioEnable ?
          isAbleToTalk
          : participantStatus.isAudioEnable,
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
