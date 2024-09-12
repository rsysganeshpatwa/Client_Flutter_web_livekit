import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/theme.dart';

import 'no_video.dart';
import 'participant_info.dart';
import 'participant_stats.dart';

abstract class ParticipantWidget extends StatefulWidget {
  // Convenience method to return relevant widget for participant
  static ParticipantWidget widgetFor(ParticipantTrack participantTrack,ParticipantStatus participantStatus,
      {bool showStatsLayer = false}) {
    if (participantTrack.participant is LocalParticipant) {
      return LocalParticipantWidget(
          participantTrack.participant as LocalParticipant,
          participantTrack.type,
          showStatsLayer,
          participantStatus,
        
          );
    } else if (participantTrack.participant is RemoteParticipant) {
      return RemoteParticipantWidget(
          participantTrack.participant as RemoteParticipant,
          participantTrack.type,
          showStatsLayer,
          participantStatus
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
  final ParticipantStatus participantStatus;

  const LocalParticipantWidget(
    this.participant,
    this.type,
    this.showStatsLayer, 
    this.participantStatus,
    {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _LocalParticipantWidgetState();
}

class RemoteParticipantWidget extends ParticipantWidget{
  @override
  final RemoteParticipant participant;
  @override
  final ParticipantTrackType type;
  @override
  final bool showStatsLayer;
  @override
  final ParticipantStatus participantStatus;

  const RemoteParticipantWidget(
    this.participant,
    this.type,
    this.showStatsLayer, 
    this.participantStatus,
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
  Participant<TrackPublication<Track>>? get localParticipant =>
      widget.participant is LocalParticipant ? widget.participant : null;
 
  @override
  void initState() {
    super.initState();
    _listener = widget.participant.createListener();
    _listener?.on<TranscriptionEvent>((e) {
      for (var seg in e.segments) {
        print('Transcription: ${seg.text} ${seg.isFinal}');
      }
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

  List<Widget> extraWidgets(bool isScreenShare) => [];

  @override
  Widget build(BuildContext ctx) {
      print(widget.participantStatus.toJson());
    String formatName(String name) {
      if (name.isEmpty) return name;
      return name
          .split(' ')
          .map((word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1).toLowerCase()
              : '')
          .join(' ');
    }

    return Container(
      foregroundDecoration: BoxDecoration(
        
        border: widget.participant.isSpeaking &&
                audioPublication?.subscribed == true &&
                !isScreenShare
            ? Border.all(width: 5, color: Colors.green)
            
            : null,

          
      ),
      decoration: BoxDecoration(
        color: Color(0xFF747474),
       
      ),
    
      child: Stack(
      
        children: [
        
            // Display the regular video

            InkWell(
              onTap: () => setState(() => _visible = !_visible),
              child: activeVideoTrack != null && !activeVideoTrack!.muted
                  ? VideoTrackRenderer(
                      activeVideoTrack!,
                      fit: MediaQuery.of(ctx).size.width < 600
                          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
                          : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    )
                  : const NoVideoWidget(),
            ),
          if (widget.showStatsLayer)
            Positioned(
                top: 30,
                right: 30,
                child: ParticipantStatsWidget(
                  participant: widget.participant,
                )),

          // Overlay with text and button

          Positioned(
            bottom: 8.0,
            left: 8.0,
            child: Container(
              padding: EdgeInsets.all(8.0), // Equivalent to var(--space-sm)
              decoration: BoxDecoration(
                color: Color(0xFF000000)
                    .withOpacity(0.5), // Equivalent to var(--black_900_7f)
                borderRadius: BorderRadius.circular(
                    4.0), // Equivalent to var(--radius-xs)
              ),
              child: Text(
                widget.participant.name.isNotEmpty
                    ? formatName(widget.participant.name)
                    : widget.participant.identity,
                style: TextStyle(
                  fontSize:  20 * 0.65, // Equivalent to var(--text-lg)
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          if (!(widget.participant is LocalParticipant) && widget.participantStatus.isHandRaised)
          Positioned(
            top: 8.0,
            left: 8.0,
            child: Icon(Icons.pan_tool, color: Colors.orange ,size: 30,),),

          // Positioned(
          //   top: 0,
          //   right: 8.0,
          //   child: Row(
          //     children: [
          //      ElevatedButton(
          //         style: ElevatedButton.styleFrom(
          //           backgroundColor: Colors.grey,
          //           shape: CircleBorder(),
          //           padding: EdgeInsets.all(8),
          //           minimumSize: Size(48, 48),
          //         ),
          //         onPressed: () {},
          //         child: Icon(
          //           Icons.push_pin,
          //           color: Colors.white,
          //         ),
          //       ),
          //       SizedBox(width: 8.0),
          //       ElevatedButton(
          //         style: ElevatedButton.styleFrom(
          //           backgroundColor: Colors.deepOrange,
          //           shape: CircleBorder(),
          //           padding: EdgeInsets.all(8),
          //           minimumSize: Size(48, 48),
          //         ),
          //         onPressed: () {},
          //         child: Icon(
          //           Icons.mic_off,
          //           color: Colors.white,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),

          Positioned(
        
            top: 0,
            right: 8.0,
            child: 
                  ParticipantInfoWidget(
                    title: widget.participant.name.isNotEmpty
                        ? '${widget.participant.name} (${widget.participant.identity})'
                        : widget.participant.identity,
                    audioAvailable: audioPublication?.muted == false,
                    publicAudioDisabled: audioPublication?.subscribed == false,
                    connectionQuality: widget.participant.connectionQuality,
                    isScreenShare: isScreenShare,
                    enabledE2EE: widget.participant.isEncrypted,
                  ),
             
          ),
          //    Optionally, you could add other participants' video feeds here if needed
        ],
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
