import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

enum ParticipantTrackType {
  kUserMedia,
  kScreenShare,
}

extension ParticipantTrackTypeExt on ParticipantTrackType {
  TrackSource get lkVideoSourceType => {
        ParticipantTrackType.kUserMedia: TrackSource.camera,
        ParticipantTrackType.kScreenShare: TrackSource.screenShareVideo,
      }[this]!;

  TrackSource get lkAudioSourceType => {
        ParticipantTrackType.kUserMedia: TrackSource.microphone,
        ParticipantTrackType.kScreenShare: TrackSource.screenShareAudio,
      }[this]!;
}

class ParticipantTrack {
  ParticipantTrack(
      {required this.participant, this.type = ParticipantTrackType.kUserMedia});
  Participant participant;
  final ParticipantTrackType type;
}

class ParticipantInfoWidget extends StatelessWidget {
  final String? title;
  final bool audioAvailable;
  final bool publicAudioDisabled;
  final ConnectionQuality connectionQuality;
  final bool isScreenShare;
  final bool enabledE2EE;

  const ParticipantInfoWidget({
    this.title,
    this.audioAvailable = true,
    this.publicAudioDisabled = false,
    this.connectionQuality = ConnectionQuality.unknown,
    this.isScreenShare = false,
    this.enabledE2EE = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Screen share indicator
          if (isScreenShare)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Tooltip(
                message: 'Screen sharing',
                child: Icon(
                  Icons.monitor,
                  color: Colors.white,
                  size: 18, 
                ),
              ),
              
            ),

          // Microphone status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Tooltip(
              message: audioAvailable ? 'Microphone on' : 'Microphone off',
              child: Icon(
                audioAvailable ? Icons.mic : Icons.mic_off,
                color: audioAvailable ? Colors.green : Colors.red,
                size: 18,
              ),
            ),
          ),

          // Public audio disabled (volume off)
          if (publicAudioDisabled)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Tooltip(
                message: 'Muted by host',
                child: Icon(
                  Icons.volume_off,
                  color: Colors.red,
                  size: 18,
                ),
              ),
            ),

          // Connection quality indicator
          // if (connectionQuality != ConnectionQuality.unknown)
          //   Padding(
          //     padding: const EdgeInsets.only(left: 6),
          //     child: Tooltip(
          //       message: 'Connection: ${connectionQuality.name}',
          //       child: Icon(
          //         connectionQuality == ConnectionQuality.poor
          //             ? Icons.signal_wifi_statusbar_connected_no_internet_4
          //             : Icons.network_wifi,
          //         color: {
          //           ConnectionQuality.excellent: Colors.green,
          //           ConnectionQuality.good: Colors.orange,
          //           ConnectionQuality.poor: Colors.red,
          //         }[connectionQuality],
          //         size: 16,
          //       ),
          //     ),
          //   ),

          // // End-to-end encryption indicator
          // if (enabledE2EE)
          //   Padding(
          //     padding: const EdgeInsets.only(left: 6),
          //     child: Tooltip(
          //       message: 'End-to-end encrypted',
          //       child: Icon(
          //         Icons.lock,
          //         color: Colors.white,
          //         size: 14,
          //       ),
          //     ),
          //   ),
        ],
      ),
    );
  }
}
