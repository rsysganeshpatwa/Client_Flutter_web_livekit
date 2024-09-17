import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';

class RoomHeader extends StatefulWidget {
  final Room room;
  final List<ParticipantStatus> participantsStatusList;
  final void Function(bool) onToggleRaiseHand;
  final bool isHandRaisedStatusChanged;
  final bool isAdmin;

  RoomHeader(
      {required this.room,
      required this.participantsStatusList,
      required this.onToggleRaiseHand,
      required this.isHandRaisedStatusChanged,
      required this.isAdmin});

  @override
  _RoomHeaderState createState() => _RoomHeaderState();
}

class _RoomHeaderState extends State<RoomHeader> {
  List<MediaDevice>? _audioInputs;
  List<MediaDevice>? _videoInputs;
  bool _isHandRaised = false; // Track the hand raise state

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
                  }).toList(),
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
                  }).toList(),
              ],
            ),
          ),
        );
      },
    );
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

    var totalParticipantCount = widget.room.remoteParticipants.values.where(
        (p) => p.metadata != null && jsonDecode(p.metadata!)['role'] == Role.participant.toString()).length;


    totalHostCount = widget.isAdmin ? totalHostCount + 1 : totalHostCount;
    totalParticipantCount = !widget.isAdmin ? totalParticipantCount + 1 : totalParticipantCount;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Color(0xFF4A4A4A)
          .withOpacity(0.8), // Use the actual hex code for var(--gray_700)
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Heading
          Expanded(
            child: Text(
              'Video Conference Room',
              style: TextStyle(
                fontSize: 24, // Adjust font size as needed
                fontWeight: FontWeight.bold,
                color: Colors.white, // Text color
              ),
              overflow: TextOverflow.ellipsis, // Handles overflow
            ),
          ),
        
          SizedBox(
              height:
                  4), // Add some spacing between the title and participant count
                    if(widget.isAdmin)
          Text(
            'Participants: ${totalParticipantCount}', // Display total participant count
            style: TextStyle(
              fontSize: 16,
              color: Colors.white, // Text color for participant count
            ),
          ),
           
          SizedBox(
            width: 16,
          ), // Add some spacing between the participant count and host count
          if(widget.isAdmin)
          Text(
            'Hosts: ${totalHostCount}', // Display total host count
            style: TextStyle(
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
            icon: Icon(
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
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
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
                PopupMenuItem<String>(
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
                PopupMenuItem<String>(
                  value: 'codec',
                  child: ListTile(
                    leading: Icon(Icons.info, color: Colors.black),
                    title: Text(
                      'Codec Stats (in testing)',
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
