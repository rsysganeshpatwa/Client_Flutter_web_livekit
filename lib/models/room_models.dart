class ParticipantStatus {
   String identity = '';
   bool isAudioEnable = false;
   bool isVideoEnable = false;
   bool isHandRaised = false;
   bool isTalkToHostEnable = false;
   int handRaisedTimeStamp = 0;
   String role = '';

  ParticipantStatus({
    required this.identity,
    required this.isAudioEnable,
    required this.isVideoEnable,
    this.isHandRaised = false,
    required this.isTalkToHostEnable,
    this.handRaisedTimeStamp = 0,
    this.role = '',
  });

   ParticipantStatus copyWith({
        // Define the parameters for the copyWith method
        bool? isAudioEnable,
        bool? isVideoEnable,
        bool? isTalkToHostEnable,
        bool? isHandRaised,
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
      role: json['role'],

    );
  }
}


