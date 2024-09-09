import 'dart:convert';
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

  const ParticipantDrawer({
    Key? key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.filterParticipants,
    required this.localParticipant,
    required this.participantsStatusList,
    required this.onParticipantsStatusChanged,
  }) : super(key: key);

  @override
  _ParticipantDrawerState createState() => _ParticipantDrawerState();
}

class _ParticipantDrawerState extends State<ParticipantDrawer> {
  late bool _selectAllAudio;
  late bool _selectAllVideo;
  late bool _selectMuteAll;

  @override
  void initState() {
    super.initState();
    _selectAllAudio = _areAllParticipantsSelected('audio');
    _selectAllVideo = _areAllParticipantsSelected('video');
    _selectMuteAll = !_areAllParticipantsSelected('talkToHost');
    print('initState Select Mute All: $_selectMuteAll');
  }

  @override
  void didUpdateWidget(covariant ParticipantDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participantsStatusList != widget.participantsStatusList) {
      _selectAllAudio = _areAllParticipantsSelected('audio');
      _selectAllVideo = _areAllParticipantsSelected('video');
     _selectMuteAll = !_areAllParticipantsSelected('talkToHost');
   //   print('didUpdateWidget Select Mute All: $_selectMuteAll');
    }
  }

  bool _areAllParticipantsSelected(String type) {
    if (type == 'audio') {
      return widget.participantsStatusList
          .every((status) => status.isAudioEnable);
    } else if (type == 'video') {
      return widget.participantsStatusList
          .every((status) => status.isVideoEnable);
    } else {
      return widget.participantsStatusList
      .where((status) => status.role != Role.admin.toString())
          .every((status) => status.isTalkToHostEnable);
    }
  }

  void _toggleSelectAll(String type, bool value) {
    print('Toggle select all: $type, $value');
    setState(() {
      if (type == 'audio') {
        _selectAllAudio = value;
        final updatedList = widget.participantsStatusList.map((status) {
          return status.copyWith(isAudioEnable: _selectAllAudio);
        }).toList();
        widget.onParticipantsStatusChanged(updatedList);
      } else if (type == 'video') {
        _selectAllVideo = value;
        final updatedList = widget.participantsStatusList.map((status) {
          return status.copyWith(isVideoEnable: _selectAllVideo);
        }).toList();
        widget.onParticipantsStatusChanged(updatedList);
      } else {
        _selectMuteAll = value;
        print('Select Mute All: $_selectMuteAll');
        final updatedList = widget.participantsStatusList.map((status) {
          // Update only if the participant is not an admin
          if (status.role != Role.admin.toString()) {
            print('Select Mute All: status: ${status.toJson()}');
            return status.copyWith(isTalkToHostEnable: !_selectMuteAll);
          }
          return status; // Leave admin participants unchanged
        }).toList();
        widget.onParticipantsStatusChanged(updatedList);
      }
    });
  }

  void updateAudioVideoStatus(
      ParticipantStatus participantStatus, bool isAudio, bool isVideo) {
    final updatedStatus = participantStatus.copyWith(
      isAudioEnable: isAudio,
      isVideoEnable: isVideo,
    );
    _triggerParticipantsStatusUpdate(updatedStatus);
  }

  void updateAllowToTalkStatus(
      ParticipantStatus participantStatus, bool isAllowToTalk) {
    final updatedStatus = participantStatus.copyWith(
      isTalkToHostEnable: isAllowToTalk,
      isHandRaised: false,
    );
    print('Allow to talk status updated: ${updatedStatus.toJson()}');
    _triggerParticipantsStatusUpdate(updatedStatus);
  }

  void _triggerParticipantsStatusUpdate(ParticipantStatus updatedStatus) {
    bool exists = false;
    final updatedList = widget.participantsStatusList.map((status) {
      if (status.identity == updatedStatus.identity) {
        exists = true;
        return updatedStatus;
      }
      return status;
    }).toList();

    if (!exists) {
      updatedList.add(updatedStatus);
    }

    widget.onParticipantsStatusChanged(updatedList);
  }

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
        .where((track) =>
            track.participant.metadata != null &&
            jsonDecode(track.participant.metadata!)['role'] !=
                Role.admin.toString())
        .toList();

    final isAnyParticipantRoleAvailableMoreThenOne =
        nonAdminParticipants.length >= 2;

    return Drawer(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: Colors.black.withOpacity(0.8),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment
                        .spaceBetween, // To push items to opposite ends
                    children: [
                      Text(
                        'Participants',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search participants',
                      prefixIcon: Icon(Icons.search, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.blueGrey[800],
                    ),
                    onChanged: widget.onSearchChanged,
                  ),
                  SizedBox(height: 16),
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: const Color(0xFF9FF5FF),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: const Color(
                              0xFF9FF5FF), // Updated indicator color
                          tabs: [
                            Tab(text: 'Audio Manage'),
                            Tab(text: 'Together Mode'),
                          ],
                        ),
                        Container(
                          // as per drawer height:   // Set the height or use MediaQuery for dynamic sizing
                          height: MediaQuery.of(context).size.height,
                          child: TabBarView(
                            children: [
                              // Tab 1: Audio Manage
                              ListView(
                                children: [
                                  if (isAnyParticipantRoleAvailableMoreThenOne)
                                    _selectAllTalkToHostModeParticipants(),
                                  ..._buildHostParticipants(),
                                  ..._getHandRaisedParticipants(),
                                  ..._buildAllParticipants('Audio Manage'),
                                ],
                              ),
                              // Tab 2: Together Mode
                              ListView(
                                children: [
                                  if (isAnyParticipantRoleAvailableMoreThenOne)
                                    _selectAllTogetherModeParticipants(),
                                  ..._buildHostParticipants(),
                                  ..._buildAllParticipants('Together Mode'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAllParticipants(tabName) {
    return widget.filterParticipants(widget.searchQuery).where((track) {
      final metadata = track.participant.metadata;
      final role = metadata != null ? jsonDecode(metadata)['role'] : null;
      return role != Role.admin.toString();
    }).map((track) {
      final participantStatus =
          _getParticipantStatus(track.participant.identity);
      final participantName = track.participant.name ?? 'Unknown';

      return _buildParticipantTile(context,
          name: participantName,
          participantStatus: participantStatus,
          tabName: tabName);
    }).toList();
  }

  List<Widget> _buildHostParticipants() {
    return widget.filterParticipants(widget.searchQuery).where((track) {
      final metadata = track.participant.metadata;
      final role = metadata != null ? jsonDecode(metadata)['role'] : null;
      return role == Role.admin.toString();
    }).map((track) {
      final isLocal =
          track.participant.identity == widget.localParticipant?.identity;
      final participantStatus =
          _getParticipantStatus(track.participant.identity);
      final participantName = track.participant.name ?? 'Unknown';
      final displayName =
          isLocal ? '$participantName (you) (host)' : '$participantName (host)';

      return _buildParticipantTile(context,
          name: displayName, participantStatus: participantStatus, tabName: '');
    }).toList();
  }

Column _selectAllTalkToHostModeParticipants() {
  return Column(
    children: [
      ListTile(
        title: Text(
          'Select all',
          style: TextStyle(color: Colors.white),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: _selectMuteAll
                  ? 'Allow all to talk to host'
                  : 'Disallow all to talk to host',
              child: IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white, // White circle background
                  ),
                  padding: EdgeInsets.all(1), // Padding to make it a circle
                  child: Icon(
                    _selectMuteAll ? Icons.mic_off : Icons.mic,
                    color: _selectMuteAll ? Colors.red : Colors.black,
                  ),
                ),
                onPressed: () {
                  print('onPressed Select Mute All: $_selectMuteAll');
                  _toggleSelectAll('talkToHost', !_selectMuteAll);
                },
              ),
            ),
          ],
        ),
        onTap: null,
      ),
      Divider(
        thickness: 0.2,
        color: Colors.white, // Optional, to make the divider visible
      ),
    ],
  );
}

  Column _selectAllTogetherModeParticipants() {
  return Column(
    children: [
      ListTile(
        title: Text(
          'Select all',
          style: TextStyle(color: Colors.white),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: _selectAllAudio ? 'Mute All' : 'Unmute All',
              child: IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white, // White circle background
                  ),
                  padding: EdgeInsets.all(1), // Padding for circle size
                  child: Icon(
                    _selectAllAudio ? Icons.volume_up : Icons.volume_off,
                    color: _selectAllAudio ? Colors.black : Colors.red,
                  ),
                ),
                onPressed: () {
                  _toggleSelectAll('audio', !_selectAllAudio);
                },
              ),
            ),
            Tooltip(
              message: _selectAllVideo
                  ? 'Turn off video for all'
                  : 'Turn on video for all',
              child: IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white, // White circle background
                  ),
                  padding: EdgeInsets.all(1), // Padding for circle size
                  child: Icon(
                    _selectAllVideo ? Icons.videocam : Icons.videocam_off,
                    color: _selectAllVideo ? Colors.black : Colors.red,
                  ),
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
      Divider(
        thickness: 0.2,
        color: Colors.white, // Optional for better visibility
      ),
    ],
  );
}

  List<Widget> _getHandRaisedParticipants() {
    final handRaisedParticipants =
        widget.filterParticipants(widget.searchQuery).where((track) {
      final participantStatus =
          _getParticipantStatus(track.participant.identity);
      return participantStatus?.isHandRaised ?? false;
    }).toList()
          ..sort((a, b) {
            final statusA = _getParticipantStatus(a.participant.identity);
            final statusB = _getParticipantStatus(b.participant.identity);
            return (statusB?.handRaisedTimeStamp ?? 0) -
                (statusA?.handRaisedTimeStamp ?? 0);
          });

    return handRaisedParticipants.map((track) {
      final participantStatus =
          _getParticipantStatus(track.participant.identity);
      final participantName = track.participant.name ?? 'Unknown';

      final index = handRaisedParticipants.indexOf(track) + 1;
      final handRaisedText = '$participantName (#$index)';

      return _buildParticipantTile(context,
          name: handRaisedText, participantStatus: participantStatus, tabName: 'Audio Manage', isFromHandRaised: true);
    }).toList();
  }

  Widget _buildParticipantTile(BuildContext context,
      {required String name, ParticipantStatus? participantStatus, tabName, bool isFromHandRaised = false}) {
    print('Participant Status: ${participantStatus?.toJson()}');
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle,
              size: 40, color: Colors.white), // Black icon for contrast
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.normal,
              color: Colors.white, // Adjusted for light background
            ),
          ),

          trailing: tabName == 'Audio Manage'
              ? _getAudioManageTrailingIcons(participantStatus!, isFromHandRaised)
              : tabName == 'Together Mode'
                  ? _getTogetherModeTrailingIcons(participantStatus!)
                  : null,
        ),
        Divider(
          thickness: 0.2,
        ),
      ],
    );
  }

Row _getAudioManageTrailingIcons(ParticipantStatus participantStatus,bool isFromHandRaised) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Tooltip(
        message: (participantStatus.isTalkToHostEnable ?? false)
            ? 'Disallow to talk'
            : 'Allow to talk',
        child: IconButton(
          icon: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white, // White circle background
            ),
            padding: EdgeInsets.all(1), // Padding to make it a circle
            child: Icon(
              (participantStatus.isTalkToHostEnable ?? false)
                  ? Icons.mic
                  : Icons.mic_off,
              color: (participantStatus.isTalkToHostEnable ?? false)
                  ? Colors.black
                  : Colors.red,
            ),
          ),
          onPressed: () {
            final newAllowToTalkStatus =
                !(participantStatus.isTalkToHostEnable ?? false);
            updateAllowToTalkStatus(participantStatus, newAllowToTalkStatus);
          },
        ),
      ),
      if (isFromHandRaised && participantStatus.isHandRaised ?? false)
        Tooltip(
          message: 'Raised hand',
          child: Container(
           
            padding: EdgeInsets.all(1), // Padding to make it a circle
            child: const Icon(
              Icons.pan_tool,
              color: Colors.orange,
            ),
          ),
        ),
    ],
  );
}

Row _getTogetherModeTrailingIcons(ParticipantStatus participantStatus) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Tooltip(
        message: (participantStatus.isAudioEnable ?? false) ? 'Mute' : 'Unmute',
        child: IconButton(
          icon: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white, // White circle background
            ),
            padding: EdgeInsets.all(1), // Add some padding to make it a circle
            child: Icon(
              (participantStatus.isAudioEnable ?? false)
                  ? Icons.volume_up
                  : Icons.volume_off,
              color: participantStatus.isAudioEnable ?? false
                  ? Colors.black
                  : Colors.red,
            ),
          ),
          onPressed: () {
            final newAudioStatus = !(participantStatus.isAudioEnable ?? false);
            updateAudioVideoStatus(
                participantStatus, newAudioStatus, participantStatus.isVideoEnable);
          },
        ),
      ),
      Tooltip(
        message: (participantStatus.isVideoEnable ?? false)
            ? 'Turn off video'
            : 'Turn on video',
        child: IconButton(
          icon: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white, // White circle background
            ),
            padding: EdgeInsets.all(1), // Add some padding to make it a circle
            child: Icon(
              (participantStatus.isVideoEnable ?? false)
                  ? Icons.videocam
                  : Icons.videocam_off,
               color: participantStatus.isVideoEnable ?? false
                  ? Colors.black
                  : Colors.red,
                  
            ),
          ),
          onPressed: () {
            final newVideoStatus = !(participantStatus.isVideoEnable ?? false);
            updateAudioVideoStatus(participantStatus,
                participantStatus.isAudioEnable, newVideoStatus);
          },
        ),
      ),
    ],
  );
}
}
