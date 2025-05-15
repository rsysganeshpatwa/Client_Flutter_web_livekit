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
  final Function(int) onGridSizeChanged;

  const RoomHeader(
      {super.key,
      required this.room,
      required this.participantsStatusList,
      required this.onToggleRaiseHand,
      required this.isHandRaisedStatusChanged,
      required this.onGridSizeChanged,
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
  int _currentGridSize = 4; // Track current grid size

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
      if (isListenerSet == false) {
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
      if (isListenerSet == false) {
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
        return CodecStatsDialog(
            stats: stats, isVideoOn: isCameraEnabled || isMicrophoneEnabled);
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

  void _handleGridSizeChange(int size) {
    setState(() {
      _currentGridSize = size;
    });
    widget.onGridSizeChanged(size);
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

    // Check if we're on a mobile device
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    // For mobile devices, ensure we're always using 4-tile grid
    if (isMobile && _currentGridSize != 4) {
      // Reset to 4 tiles for mobile
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleGridSizeChange(4);
      });
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: const Color(0xFF4A4A4A).withOpacity(0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Heading - make smaller on mobile
          Expanded(
            child: Text(
              'Leadership Conference',
              style: TextStyle(
                fontSize: isMobile ? 18 : 24, // Smaller on mobile
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Show fewer stats on mobile
          if (!isMobile && widget.isAdmin)
            Text(
              'Total : ${widget.room.remoteParticipants.values.length + 1}   ',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),

          if (!isMobile && widget.isAdmin)
            Text(
              'Participants: $totalParticipantCount',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),

          if (!isMobile && widget.isAdmin)
            const SizedBox(width: 16),

          if (!isMobile && widget.isAdmin)
            Text(
              'Hosts: $totalHostCount',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),

          // Hand Raise Icon
          if (!widget.isAdmin)
            IconButton(
              icon: Icon(
                Icons.pan_tool,
                color: _isHandRaised ? Colors.orange : Colors.white,
                size: isMobile ? 24 : 30, // Smaller on mobile
              ),
              onPressed: _toggleHandRaise,
            ),

          // Control buttons section
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grid view selector - only show on desktop
              if (!isMobile)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.transparent),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: PopupMenuButton<int>(
                    tooltip: 'Change grid layout',
                    initialValue: _currentGridSize,
                    // ignore: sort_child_properties_last
                    child:  Padding(
                      padding: const EdgeInsets.all(8.0),
                      child:  Row(
                        children: [
                          const Icon(Icons.grid_view,
                              color: Colors.white, size: 24),
                          const SizedBox(width: 4),
                          Text(
                            '$_currentGridSize',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 4,
                        child: Row(
                          children: [
                            Icon(
                              _currentGridSize == 4
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: _currentGridSize == 4
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            const Text('4 Tiles Grid'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 8,
                        child: Row(
                          children: [
                            Icon(
                              _currentGridSize == 8
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: _currentGridSize == 8
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            const Text('8 Tiles Grid'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: _handleGridSizeChange,
                  ),
                ),

              // Settings button - make smaller on mobile
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: isMobile ? 24 : 30,
                ),
                tooltip: 'Settings',
                onSelected: (String value) {
                  if (value == 'Microphone') {
                    _showMicrophoneOptions(context);
                  } else if (value == 'Camera') {
                    _showVideoOptions(context);
                  } else if (value == 'codec') {
                    showCodecStatsDialog(context, StatsRepository().stats);
                  } else if (value == 'grid' && isMobile) {
                    // Force grid to 4 on mobile
                    _handleGridSizeChange(4);
                  }
                },
                itemBuilder: (BuildContext context) {
                  final menuItems = <PopupMenuItem<String>>[
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

                  // Add grid selection inside settings menu for mobile
                  if (isMobile) {
                    menuItems.add(
                      PopupMenuItem<String>(
                        value: 'grid',
                        child: ListTile(
                          leading: const Icon(Icons.grid_view,
                              color: Colors.black),
                          title: const Text(
                            '4 Tiles Grid',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                          trailing: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    );
                  }

                  return menuItems;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
