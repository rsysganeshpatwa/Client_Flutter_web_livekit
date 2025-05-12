// ignore_for_file: file_names

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/widgets/codec_stats.dart';
import 'dart:async';
import '../stats_repo.dart';

enum StatsType {
  kUnknown,
  kLocalAudioSender,
  kLocalVideoSender,
}



class RoomHeader extends StatefulWidget {
  final Room room;
  final List<ParticipantStatus> participantsStatusList;
  final void Function(bool) onToggleRaiseHand;
  final bool isHandRaisedStatusChanged;
  final bool isAdmin;

  const RoomHeader(
      {super.key, required this.room,
      required this.participantsStatusList,
      required this.onToggleRaiseHand,
      required this.isHandRaisedStatusChanged,
      required this.isAdmin});

  @override
  // ignore: library_private_types_in_public_api
  _RoomHeaderState createState() => _RoomHeaderState();
}

class _RoomHeaderState extends State<RoomHeader> {
  List<MediaDevice>? _audioInputs;
  List<MediaDevice>? _videoInputs;
  bool _isHandRaised = false; // Track the hand raise state
  List<EventsListener<TrackEvent>> listeners = [];
  StatsType statsType = StatsType.kUnknown;
  LocalParticipant get participant => widget.room.localParticipant!;
  bool isListenerSet = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void didUpdateWidget(covariant RoomHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHandRaisedStatusChanged !=
        oldWidget.isHandRaisedStatusChanged) {
      if (!widget.isHandRaisedStatusChanged) {
        setState(() {
          _isHandRaised =
              false; // Reset local state if isHandleRaiseHand is false
        });
      }
    }
  }

  Future<void> _loadDevices() async {
    final devices = await Hardware.instance.enumerateDevices();
    setState(() {
      _audioInputs = devices.where((d) => d.kind == 'audioinput').toList();
      _videoInputs = devices.where((d) => d.kind == 'videoinput').toList();
    });
  }

  void _selectAudioInput(MediaDevice device) async {
    await widget.room.setAudioInputDevice(device);
    setState(() {});
  }

  void _selectVideoInput(MediaDevice device) async {
    await widget.room.setVideoInputDevice(device);
    setState(() {});
  }

  Future<void> _showMicrophoneOptions(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      backgroundColor: Colors.grey[200],
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (_audioInputs != null)
                  ..._audioInputs!.map((device) {
                    return ListTile(
                      leading: (device.deviceId ==
                              widget.room.selectedAudioInputDeviceId)
                          ? const Icon(Icons.check_box_outlined,
                              color: Colors.indigo)
                          : const Icon(Icons.check_box_outline_blank,
                              color: Colors.black),
                      title: Text(
                        device.label,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                      onTap: () {
                        _selectAudioInput(device);
                        Navigator.pop(context);
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showVideoOptions(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      backgroundColor: Colors.grey[200],
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (_videoInputs != null)
                  ..._videoInputs!.map((device) {
                    return ListTile(
                      leading: (device.deviceId ==
                              widget.room.selectedVideoInputDeviceId)
                          ? const Icon(Icons.check_box_outlined,
                              color: Colors.indigo)
                          : const Icon(Icons.check_box_outline_blank,
                              color: Colors.black),
                      title: Text(
                        device.label,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                      onTap: () {
                        _selectVideoInput(device);
                        Navigator.pop(context);
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setUpTrackListeners() {
    // Dispose of any existing listeners
    for (var element in listeners) {
      element.dispose();
    }
    listeners.clear();

    // Function to check the status of microphone and camera continuously
    void checkMicrophoneAndCameraStatus() {
      if (participant.isMicrophoneEnabled() || participant.isCameraEnabled()) {
        // If either microphone or camera is enabled, allow entry and set up listeners
        for (var track in [
          ...participant.audioTrackPublications,
          ...participant.videoTrackPublications
        ]) {
          if (track.track != null) {
            _setUpListener(track.track!);
          }
        }
      }


    }
checkMicrophoneAndCameraStatus();
   
  }

  void _setUpListener(Track track) async {
    var listener = track.createListener();
    listeners.add(listener);
    if (track is LocalVideoTrack) {
      if(isListenerSet  ==false){
      await participant.setCameraEnabled(false);
      await participant.setCameraEnabled(true);
      }
      statsType = StatsType.kLocalVideoSender;
      listener.on<VideoSenderStatsEvent>((event) {
      
        setState(() {
          isListenerSet = true;
          StatsRepository().stats['video tx'] =
              '${event.currentBitrate.toInt()} kbps';
          var firstStats =
              event.stats['f'] ?? event.stats['h'] ?? event.stats['q'];
          if (firstStats != null) {
            StatsRepository().stats['video codec'] =
                '${firstStats.mimeType}, ${firstStats.clockRate}hz, pt: ${firstStats.payloadType}';
          }
          var selectedLayer =
              event.stats['f'] ?? event.stats['h'] ?? event.stats['q'];
          if (selectedLayer != null) {
            StatsRepository().stats['Resolution'] =
                '${selectedLayer.frameWidth ?? 0}x${selectedLayer.frameHeight ?? 0} ; ${selectedLayer.framesPerSecond?.toDouble() ?? 0} fps';
          }
        });
      });
    } else if (track is LocalAudioTrack) {
      if(isListenerSet ==false){
      await participant.setMicrophoneEnabled(false);
      await participant.setMicrophoneEnabled(true);

      }
      statsType = StatsType.kLocalAudioSender;
      listener.on<AudioSenderStatsEvent>((event) {
        setState(() {
           isListenerSet = true;
          StatsRepository().stats['audio tx'] =
              '${event.currentBitrate.toInt()} kbps';
          StatsRepository().stats['audio codec'] =
              '${event.stats.mimeType}, ${event.stats.clockRate}hz, ${event.stats.channels}ch, pt: ${event.stats.payloadType}';
        });
      });
    }
  }

  void showCodecStatsDialog(BuildContext context, Map<String, String> stats) {
    final isCameraEnabled = participant.isCameraEnabled();
    final isMicrophoneEnabled = participant.isMicrophoneEnabled();
    _setUpTrackListeners();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CodecStatsDialog(stats: stats,isVideoOn: isCameraEnabled || isMicrophoneEnabled);
      },
    ).then((value) {
      // Code to execute after the dialog is closed
     
      for (var element in listeners) {
        element.dispose();
      }
      listeners.clear();
      setState(() {
         StatsRepository().stats.clear();
      });
      // Do any other operation here
    });
    
  }

  void _toggleHandRaise() {
    setState(() {
      _isHandRaised = !_isHandRaised;

      widget.onToggleRaiseHand(_isHandRaised);
    });
  }

  @override
  Widget build(BuildContext context) {
    var totalHostCount = widget.room.remoteParticipants.values.where((p) {
      return p.metadata != null &&
          jsonDecode(p.metadata!)['role'] == Role.admin.toString();
    }).length;

    var totalParticipantCount = widget.room.remoteParticipants.values
        .where((p) =>
            p.metadata != null &&
            jsonDecode(p.metadata!)['role'] == Role.participant.toString())
        .length;



    totalHostCount = widget.isAdmin ? totalHostCount + 1 : totalHostCount;
    totalParticipantCount =
        !widget.isAdmin ? totalParticipantCount + 1 : totalParticipantCount;

    return Container(
      padding:const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: const Color(0xFF4A4A4A)
          // ignore: deprecated_member_use
          .withOpacity(0.8), // Use the actual hex code for var(--gray_700)
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Heading
          const Expanded(
            child: Text(
              'Leadership Conference',
              style: TextStyle(
                fontSize: 24, // Adjust font size as needed
                fontWeight: FontWeight.bold,
                color: Colors.white, // Text color
              ),
              overflow: TextOverflow.ellipsis, // Handles overflow
            ),
          ),


          const SizedBox(
              height:
                  16), // Add some spacing between the title and participant count
          if (widget.isAdmin)
            Text(
              'Total : ${widget.room.remoteParticipants.values.length +1}   ', // Display total participant count
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white, // Text color for participant count
              ),
            ),


          const SizedBox(
              height:
                  16), // Add some spacing between the title and participant count
          if (widget.isAdmin)
            Text(
              'Participants: $totalParticipantCount', // Display total participant count
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white, // Text color for participant count
              ),
            ),

          const SizedBox(
            width: 16,
          ), // Add some spacing between the participant count and host count
          if (widget.isAdmin)
            Text(
              'Hosts: $totalHostCount', // Display total host count
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white, // Text color for host count
              ),
            ),
          // Hand Raise Icon
          if (!widget.isAdmin)
            IconButton(
              icon: Icon(
                Icons.pan_tool,
                color: _isHandRaised
                    ? Colors.orange
                    : Colors.white, // Change color based on state
                size: 30,
              ),
              onPressed: _toggleHandRaise,
            ),
          // Settings Popup Menu
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.settings,
              color: Colors.white, // Icon color
              size: 30, // Adjust icon size as needed
            ),
            tooltip: 'Settings',
            onSelected: (String value) {
              if (value == 'Microphone') {
                _showMicrophoneOptions(context);
              } else if (value == 'Camera') {
                _showVideoOptions(context);
              } else if (value == 'codec') {
                showCodecStatsDialog(context, StatsRepository().stats);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'Microphone',
                  child: ListTile(
                    leading: Icon(Icons.mic, color: Colors.black),
                    title: Text(
                      'Microphone',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Camera',
                  child: ListTile(
                    leading: Icon(Icons.videocam, color: Colors.black),
                    title: Text(
                      'Camera',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'codec',
                  child: ListTile(
                    leading: Icon(Icons.info, color: Colors.black),
                    title: Text(
                      'Codec Stats',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}
