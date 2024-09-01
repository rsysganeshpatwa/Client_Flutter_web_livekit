import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';

class ParticipantDrawer extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final List<ParticipantTrack> Function(String) filterParticipants;
  final Participant? localParticipant;
  final List<ParticipantStatus> participantsStatusList;
  final void Function(List<ParticipantStatus>) onParticipantsStatusChanged;
  ParticipantDrawer({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.filterParticipants,
    required this.localParticipant,
    required this.participantsStatusList,
    required this.onParticipantsStatusChanged,
  });

  _ParticipantDrawerState createState() => _ParticipantDrawerState();
}

class _ParticipantDrawerState extends State<ParticipantDrawer> {
  late bool _selectAllAudio;
  late bool _selectAllVideo;

  @override
  void initState() {
    super.initState();
    _selectAllAudio = _areAllParticipantsSelected('audio');
    _selectAllVideo = _areAllParticipantsSelected('video');
  }

  @override
  void didUpdateWidget(covariant ParticipantDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participantsStatusList != widget.participantsStatusList) {
      _selectAllAudio = _areAllParticipantsSelected('audio');
      _selectAllVideo = _areAllParticipantsSelected('video');
    }
  }

  bool _areAllParticipantsSelected( String type) {
    if (type == 'audio') {
      return widget.participantsStatusList
          .every((status) => status.isAudioEnable);
    } else {
      return widget.participantsStatusList
          .every((status) => status.isVideoEnable);
    }
  }

  void _toggleSelectAll(String type, bool value) {
    setState(() {
      if (type == 'audio') {
        _selectAllAudio = value;
        final updatedList = widget.participantsStatusList.map((status) {
          return status.copyWith(isAudioEnable: _selectAllAudio);
        }).toList();
        widget.onParticipantsStatusChanged(updatedList);
      } else {
        _selectAllVideo = value;
        final updatedList = widget.participantsStatusList.map((status) {
          return status.copyWith(isVideoEnable: _selectAllVideo);
        }).toList();
        widget.onParticipantsStatusChanged(updatedList);
      }
    });
  }

  // Function to update audio and video status
  void updateAudioVideoStatus(
      ParticipantStatus participantStatus, bool isAudio, bool isVideo) {
    final updatedStatus = participantStatus.copyWith(
      isAudioEnable: isAudio,
      isVideoEnable: isVideo,
    );
    _triggerParticipantsStatusUpdate(updatedStatus);
  }

  // Function to update 'Allow to Talk' status
  void updateAllowToTalkStatus(
      ParticipantStatus participantStatus, bool isAllowToTalk) {
    final updatedStatus = participantStatus.copyWith(
      isTalkToHostEnable: isAllowToTalk,
      isHandRaised: false,
    );
    print('rohit Allow to talk status updated: ${updatedStatus.toJson()}');
    _triggerParticipantsStatusUpdate(updatedStatus);
  }

  // Function to trigger participants status update and call the callback
  void _triggerParticipantsStatusUpdate(ParticipantStatus updatedStatus) {
    // Check if the identity already exists in the participantsStatusList
    bool exists = false;
    final updatedList = widget.participantsStatusList.map((status) {
      if (status.identity == updatedStatus.identity) {
        exists = true;
        return updatedStatus;
      }
      return status;
    }).toList();

    // If the identity does not exist, add the new status
    if (!exists) {
      updatedList.add(updatedStatus);
    }

    // Trigger the callback with the updated list
    widget.onParticipantsStatusChanged(updatedList);
  }

  // Function to retrieve participant status safely
  // Utility function to get participant status
  ParticipantStatus? _getParticipantStatus(String identity) {
    try {
      return widget.participantsStatusList.firstWhere(
        (status) => status.identity == identity,
        orElse: () => ParticipantStatus(
          identity: identity,
          isAudioEnable: false,
          isVideoEnable: false,
          isTalkToHostEnable: false,
          isHandRaised: false,
          handRaisedTimeStamp: 0,
        ),
      );
    } catch (e) {
      print("Error retrieving participant status: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
  final nonAdminParticipants = widget
    .filterParticipants(widget.searchQuery)
    .where((track) => track.participant.metadata != null &&
        jsonDecode(track.participant.metadata!)['role'] !=
            Role.admin.toString())
    .toList();

final isAnyParticipantRoleAvailableMoreThenOne = nonAdminParticipants.length >= 2;
    return DefaultTabController(
      length: 2,
      child: Drawer(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Search participants',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: widget.onSearchChanged,
              ),
            ),
            TabBar(
              tabs: [
                Tab(text: 'Audio Manage'),
                Tab(text: 'Together Mode'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Audio Manage
                  ListView(
                    children: [
                      ..._buildHostParticipants(),
                      ..._buildHandRaisedParticipants(),
                      ..._buildNonHandRaisedParticipants(),
                    ],
                  ),

                  // Tab 2: Together Mode
                  ListView(
                    children: [
                      if(isAnyParticipantRoleAvailableMoreThenOne)
                      ListTile(
                        title: Text('Select All',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: _selectAllAudio
                                  ? 'Toggle audio off for all participants'
                                  : 'Toggle audio on for all participants',
                              child: IconButton(
                                icon: Icon(
                                  _selectAllAudio
                                      ? Icons.volume_up
                                      : Icons.volume_off,
                                  color: _selectAllAudio
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                onPressed: () {
                                  _toggleSelectAll('audio', !_selectAllAudio);
                                },
                              ),
                            ),
                            Tooltip(
                              message: _selectAllVideo
                                  ? 'Toggle video off for all participants'
                                  : 'Toggle video on for all participants',
                              child: IconButton(
                                icon: Icon(
                                  _selectAllVideo
                                      ? Icons.videocam
                                      : Icons.videocam_off,
                                  color: _selectAllVideo
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                onPressed: () {
                                  _toggleSelectAll('video', !_selectAllVideo);
                                },
                              ),
                            ),
                          ],
                        ),
                        onTap: null,
                      ),
                      ..._buildHostParticipants(),
                      ..._buildTogetherModeParticipants()
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHostParticipants() {
    return widget.filterParticipants(widget.searchQuery).where((track) {
      final metadata = track.participant.metadata;
      final role = metadata != null ? jsonDecode(metadata)['role'] : null;
      return role == Role.admin.toString();
    }).map((track) {
      final isLocal =
          track.participant.identity == widget.localParticipant?.identity;
      final participantName = track.participant.name ?? 'Unknown';
      final displayName =
          isLocal ? '$participantName (you) (host)' : '$participantName (host)';

      return ListTile(
        title: Text(displayName),
        trailing: null,
        onTap: null,
      );
    }).toList();
  }

  List<Widget> _buildHandRaisedParticipants() {
    final handRaisedParticipants =
        widget.filterParticipants(widget.searchQuery).where((track) {
      final participantStatus =
          _getParticipantStatus(track.participant.identity);
      return participantStatus?.isHandRaised ?? false;
    }).toList()
          ..sort((a, b) {
            final aStatus = _getParticipantStatus(a.participant.identity);
            final bStatus = _getParticipantStatus(b.participant.identity);
            return (aStatus?.handRaisedTimeStamp ?? 0)
                .compareTo(bStatus?.handRaisedTimeStamp ?? 0);
          });

    return handRaisedParticipants.map((track) {
      final participantStatus =
          _getParticipantStatus(track.participant.identity);

      print('rohit Participant status drawer: ${participantStatus?.toJson()}');
      final isLocal =
          track.participant.identity == widget.localParticipant?.identity;
      final participantName = track.participant.name ?? 'Unknown';
      final displayName = isLocal ? '$participantName (you)' : participantName;

      final index = handRaisedParticipants.indexOf(track) + 1;
      final handRaisedText = ' (#$index)';
      final isAdmin = isLocal &&
          track.participant.metadata != null &&
          jsonDecode(track.participant.metadata!)['role'] ==
              Role.admin.toString();

      return ListTile(
        title: Text(displayName + handRaisedText),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pan_tool, color: Colors.orange),
            if (!isLocal && !isAdmin)
              Checkbox(
                value: participantStatus?.isTalkToHostEnable,
                onChanged: (value) {
                  if (participantStatus != null) {
                    updateAllowToTalkStatus(
                      participantStatus,
                      value ?? false,
                    );
                  }
                },
              ),
          ],
        ),
        onTap: isLocal || isAdmin
            ? null
            : () {
                if (participantStatus != null) {
                  updateAllowToTalkStatus(
                    participantStatus,
                    !participantStatus.isTalkToHostEnable,
                  );
                }
              },
      );
    }).toList();
  }

  List<Widget> _buildNonHandRaisedParticipants() {
    return widget.filterParticipants(widget.searchQuery).where((track) {
      final participantStatus =
          _getParticipantStatus(track.participant.identity);
      return !(participantStatus?.isHandRaised ?? false) &&
          track.participant.metadata != null &&
          jsonDecode(track.participant.metadata!)['role'] !=
              Role.admin.toString();
    }).map((track) {
      final participantStatus =
          _getParticipantStatus(track.participant.identity);

      final isLocal =
          track.participant.identity == widget.localParticipant?.identity;
      final participantName = track.participant.name ?? 'Unknown';
      final displayName = isLocal ? '$participantName (you)' : participantName;

      return ListTile(
        title: Text(displayName),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLocal)
              Checkbox(
                value: participantStatus?.isTalkToHostEnable,
                onChanged: (value) {
                  if (participantStatus != null) {
                    updateAllowToTalkStatus(
                      participantStatus,
                      value ?? false,
                    );
                  }
                },
              ),
          ],
        ),
        onTap: isLocal
            ? null
            : () {
                if (participantStatus != null) {
                  updateAllowToTalkStatus(
                    participantStatus,
                    !participantStatus.isTalkToHostEnable,
                  );
                }
              },
      );
    }).toList();
  }

  List<Widget> _buildTogetherModeParticipants() {
    return widget.filterParticipants(widget.searchQuery).where((track) {
      final metadata = track.participant.metadata;
      final role = metadata != null ? jsonDecode(metadata)['role'] : null;
      return role != Role.admin.toString();
    }).map((track) {
      final participantStatus =
          _getParticipantStatus(track.participant.identity);
      if (participantStatus == null) return Container();

      final isLocal =
          track.participant.identity == widget.localParticipant?.identity;
      final participantName = track.participant.name ?? 'Unknown';
      final displayName = isLocal ? '$participantName (you)' : participantName;

      final isAudioOn = participantStatus.isAudioEnable;
      final isVideoOn = participantStatus.isVideoEnable;
      final role = track.participant.metadata != null
          ? jsonDecode(track.participant.metadata!)['role']
          : null;

      final isAdmin = isLocal && role == Role.admin.toString();

      return ListTile(
        title: Text(displayName),
        trailing: !isAdmin
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isAudioOn ? Icons.volume_up : Icons.volume_off,
                      color: isAudioOn ? Colors.green : Colors.red,
                    ),
                    onPressed: isLocal
                        ? null
                        : () {
                            updateAudioVideoStatus(
                              participantStatus,
                              !isAudioOn,
                              isVideoOn,
                            );
                          },
                  ),
                  IconButton(
                    icon: Icon(
                      isVideoOn ? Icons.videocam : Icons.videocam_off,
                      color: isVideoOn ? Colors.green : Colors.red,
                    ),
                    onPressed: isLocal
                        ? null
                        : () {
                            updateAudioVideoStatus(
                              participantStatus,
                              isAudioOn,
                              !isVideoOn,
                            );
                          },
                  ),
                ],
              )
            : null,
        onTap: null,
      );
    }).toList();
  }
}
