import 'dart:ui';

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
  final bool isHandRaised;
  final bool isScreenShare;
  final bool enabledE2EE;

  const ParticipantInfoWidget({
    this.title,
    this.audioAvailable = true,
    this.publicAudioDisabled = false,
    this.connectionQuality = ConnectionQuality.unknown,
    this.isScreenShare = false,
    this.isHandRaised = false,
    this.enabledE2EE = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Container(
  padding: const EdgeInsets.symmetric(
    vertical: 7,
    horizontal: 10,
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      if (isScreenShare)
        Padding(
          padding: EdgeInsets.only(left: 5),
          child: Icon(
            Icons.monitor,
            color: Colors.white,
            size: 25,
          ),
        ),

      Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Icon(
          audioAvailable ? Icons.mic : Icons.mic_off,
          color: audioAvailable ? Colors.white : Colors.red,
          size: 25,
        ),
      ),

      if (publicAudioDisabled)
        Padding(
          padding: EdgeInsets.only(left: 5),
          child: Icon(
            Icons.volume_off,
            color: Colors.red,
            size: 25,
          ),
        ),

      if (connectionQuality != ConnectionQuality.unknown)
        Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Icon(
            connectionQuality == ConnectionQuality.poor
                ? Icons.wifi_off_outlined
                : Icons.wifi,
            color: {
              ConnectionQuality.excellent: Colors.green,
              ConnectionQuality.good: Colors.orange,
              ConnectionQuality.poor: Colors.red,
            }[connectionQuality],
            size: 25,
          ),
        ),

      // if (enabledE2EE)
      //   Padding(
      //     padding: const EdgeInsets.only(left: 5),
      //     child: Icon(
      //       enabledE2EE ? Icons.lock : Icons.lock_open,
      //       color: enabledE2EE ? Colors.green : Colors.red,
      //       size: 16,
      //     ),
      //   ),
    ],
  ),
  

);

}
