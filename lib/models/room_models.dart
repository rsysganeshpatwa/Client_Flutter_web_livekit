import 'package:video_meeting_room/widgets/participant_info.dart';

class ParticipantStatus {
   String identity = '';
   bool isAudioEnable = false;
   bool isVideoEnable = false;
   bool isHandRaised = false;
   bool isTalkToHostEnable = false;
   bool isPinned = false;
   bool isSpotlight = false;

   int handRaisedTimeStamp = 0;
    int lastShownAt = 0;
    int handRasiedIndex = 0;
   String role = '';

  ParticipantStatus({
    required this.identity,
    required this.isAudioEnable,
    required this.isVideoEnable,
    this.isHandRaised = false,
    required this.isTalkToHostEnable,
    this.isPinned = false,
    this.isSpotlight = false,
    this.handRaisedTimeStamp = 0,
    this.lastShownAt = 0,
    this.role = '',
  });

   ParticipantStatus copyWith({
        // Define the parameters for the copyWith method
        bool? isAudioEnable,
        bool? isVideoEnable,
        bool? isTalkToHostEnable,
        bool? isHandRaised,
        bool? isPinned,
        bool? isSpotlight,
        int? handRaisedTimeStamp,
        String? role
      }) {
        // Implement the copyWith method
        return ParticipantStatus(
          // Copy the existing values and update the specified ones
          identity: identity,
          isAudioEnable: isAudioEnable ?? this.isAudioEnable,
          isVideoEnable: isVideoEnable ?? this.isVideoEnable,
          isTalkToHostEnable: isTalkToHostEnable ?? this.isTalkToHostEnable,
          isHandRaised: isHandRaised ?? this.isHandRaised,
          isPinned: isPinned ?? this.isPinned,
          isSpotlight: isSpotlight ?? this.isSpotlight,
          handRaisedTimeStamp: handRaisedTimeStamp ?? this.handRaisedTimeStamp,
          role: role ?? this.role,
        );
      }

       // Convert the ParticipantStatus to a JSON-compatible map
  Map<String, dynamic> toJson() {
    return {
      'identity': identity,
      'isAudioEnable': isAudioEnable,
      'isVideoEnable': isVideoEnable,
      'isHandRaised': isHandRaised,
      'isTalkToHostEnable': isTalkToHostEnable,
      'isPinned': isPinned,
      'isSpotlight': isSpotlight,
      'handRaisedTimeStamp': handRaisedTimeStamp,      
      'role': role,
    };
  }

  // Optionally, create a fromJson factory method for decoding
  factory ParticipantStatus.fromJson(Map<String, dynamic> json) {
    return ParticipantStatus(
      identity: json['identity'],
      isAudioEnable: json['isAudioEnable'],
      isVideoEnable: json['isVideoEnable'],
      isHandRaised: json['isHandRaised'],
      isTalkToHostEnable: json['isTalkToHostEnable'],
      handRaisedTimeStamp: json['handRaisedTimeStamp'],
      isPinned: json['isPinned'],
      isSpotlight: json['isSpotlight'],
      role: json['role'],

    );
  }
}



enum StatsType {
  kUnknown,
  kLocalAudioSender,
  kLocalVideoSender,
}

class SyncedParticipant {
  final String identity;
  ParticipantTrack? track;
  ParticipantStatus? status;
  int lastShownAt = 0;
  int handRasiedIndex = 0;


  SyncedParticipant({
    required this.identity,
    this.track,
    this.status,
  });

  bool get isAudioEnabled => status?.isAudioEnable ?? false;
  bool get isVideoEnabled => status?.isVideoEnable ?? false;
  bool get isPinned => status?.isPinned ?? false;
  bool get isSpotlight => status?.isSpotlight ?? false;
  bool get isHandRaised => status?.isHandRaised ?? false;
  
  String get role => status?.role ?? '';
}

class PrioritizedTracksResult {
  final List<ParticipantTrack> tracks;
  final bool isPiP;
  final bool isSideBarShouldVisible;

  PrioritizedTracksResult(this.tracks, this.isPiP, this.isSideBarShouldVisible);
}