// ignore_for_file: file_names

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/providers/PinnedParticipantProvider.dart';
import 'package:video_meeting_room/utils.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';
import 'package:video_meeting_room/helper_widgets/ParticipantControlIcon.dart';

class ParticipantDrawer extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final List<ParticipantTrack> Function(String) filterParticipants;
  final Participant? localParticipant;
  final List<ParticipantStatus> participantsStatusList;
  final void Function(List<ParticipantStatus>) onParticipantsStatusChanged;

  const ParticipantDrawer({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.filterParticipants,
    required this.localParticipant,
    required this.participantsStatusList,
    required this.onParticipantsStatusChanged,
  });

  @override
  // ignore: library_private_types_in_public_api
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
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ParticipantDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participantsStatusList != widget.participantsStatusList) {
      _selectAllAudio = _areAllParticipantsSelected('audio');
      _selectAllVideo = _areAllParticipantsSelected('video');
      _selectMuteAll = !_areAllParticipantsSelected('talkToHost');
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
    setState(() {
      if (type == 'audio') {
        _selectAllAudio = value;
        final updatedList = widget.participantsStatusList.map((status) {
          if (status.role != Role.admin.toString()) {
            return status.copyWith(
                isAudioEnable: _selectAllAudio, isTalkToHostEnable: _selectAllAudio);
          }
          return status;
        }).toList();
        widget.onParticipantsStatusChanged(updatedList);
      } else if (type == 'video') {
        _selectAllVideo = value;
        final updatedList = widget.participantsStatusList.map((status) {
          if (status.role != Role.admin.toString()) {
            return status.copyWith(isVideoEnable: _selectAllVideo);
          }
          return status;
        }).toList();
        widget.onParticipantsStatusChanged(updatedList);
      } else {
        _selectMuteAll = value;
        final updatedList = widget.participantsStatusList.map((status) {
          if (status.role != Role.admin.toString()) {
            return status.copyWith(isTalkToHostEnable: !_selectMuteAll);
          }
          return status;
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
      isTalkToHostEnable: isAudio,
    );
    _triggerParticipantsStatusUpdate(updatedStatus);
  }

  void updateSpotLightStatus(ParticipantStatus participantStatus, bool isSpotlight) {
    final updatedStatus = participantStatus.copyWith(
        isSpotlight: isSpotlight,
        isTalkToHostEnable: isSpotlight || participantStatus.isTalkToHostEnable,
        isAudioEnable: isSpotlight || participantStatus.isAudioEnable,
        isVideoEnable: isSpotlight || participantStatus.isVideoEnable);

    List<ParticipantStatus> updatedStatuses = updateSpotlightStatus(
      participantList: widget.participantsStatusList,
      updatedStatus: updatedStatus,
    );

    widget.onParticipantsStatusChanged(updatedStatuses);
  }

  void updateAllowToTalkStatus(
      ParticipantStatus participantStatus, bool isAllowToTalk) {
    final updatedStatus = participantStatus.copyWith(
      isTalkToHostEnable: isAllowToTalk,
      isHandRaised: false,
    );
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

    return DefaultTabController(
      length: 2,
      child: Container(
        width: 360,
        child: Drawer(
          backgroundColor: const Color(0xFF2C2C2C),
          child: ScrollbarTheme(
            data: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(Colors.grey[400]),
              trackColor: WidgetStateProperty.all(Colors.grey[800]),
              thickness: WidgetStateProperty.all(6.0),
              radius: const Radius.circular(4.0),
            ),
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF212121),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                color: Colors.grey[300],
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Participants',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.25,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A3A3A),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(context).pop(),
                              splashRadius: 20,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF4A4A4A),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search participants',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey[400],
                              size: 18,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                          ),
                          onChanged: widget.onSearchChanged,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFF3A3A3A),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TabBar(
                    labelColor: const Color(0xFF9FF5FF),
                    unselectedLabelColor: Colors.grey[400],
                    indicatorColor: const Color(0xFF9FF5FF),
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    tabs: const [
                      Tab(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Audio Manage'),
                        ),
                      ),
                      Tab(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Together Mode'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      Column(
                        children: [
                          if (isAnyParticipantRoleAvailableMoreThenOne)
                            _selectAllTalkToHostModeParticipants(),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: _buildAllParticipants('Audio Manage'),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          if (isAnyParticipantRoleAvailableMoreThenOne)
                            _selectAllTogetherModeParticipants(),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: _buildAllParticipants('Together Mode'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAllParticipants(String tabName) {
    final participants = widget.filterParticipants(widget.searchQuery);
    final pinnedProvider = Provider.of<PinnedParticipantProvider>(context);

    final participantInfoList = participants.map((track) {
      final metadata = track.participant.metadata;
      final role = metadata != null ? jsonDecode(metadata)['role'] : null;
      final status = _getParticipantStatus(track.participant.identity);
     
       print('Status  found for ${track.participant.identity}');
      

      return {
        'track': track,
        'role': role,
        'status': status,
      };
    }).toList();

    final handRaisedList = participantInfoList
        .where((info) =>
            info['status']?.isHandRaised == true &&
            info['status']?.handRaisedTimeStamp != null)
        .toList()
      ..sort((a, b) => a['status']
          .handRaisedTimeStamp
          .compareTo(b['status'].handRaisedTimeStamp));

    participantInfoList.sort((a, b) {
      final aStatus = a['status'];
      final bStatus = b['status'];

      int getRank(Map info) {
        final status = info['status'];
        final role = info['role'];
        if (status?.isSpotlight == true) return 0;
        if (pinnedProvider.isPinned(status?.identity) == true) return 1;
        if (status?.isHandRaised == true) return 2;
        if (role == Role.admin.toString()) return 3;
        return 4;
      }

      final rankA = getRank(a);
      final rankB = getRank(b);

      if (rankA != rankB) return rankA.compareTo(rankB);

      if (rankA == 2 &&
          aStatus?.handRaisedTimeStamp != null &&
          bStatus?.handRaisedTimeStamp != null) {
        return aStatus.handRaisedTimeStamp
            .compareTo(bStatus.handRaisedTimeStamp);
      }

      return 0;
    });

    return participantInfoList.map((info) {
      final track = info['track'];
      final status = info['status'];
      final participantName = track.participant.name.toString().isNotEmpty
          ? track.participant.name
          : track.participant.identity;

      int? handRaiseRank;
      if (status?.isHandRaised == true &&
          status?.handRaisedTimeStamp != null) {
        handRaiseRank = handRaisedList.indexWhere((e) =>
            e['track'].participant.identity ==
            track.participant.identity);
      }

      return _buildParticipantTile(
        context,
        name: participantName,
        participantStatus: status,
        tabName: tabName,
        handRaiseRank: handRaiseRank != -1 ? handRaiseRank : null,
      );
    }).toList();
  }

  Column _selectAllTalkToHostModeParticipants() {
    return Column(
      children: [
        ListTile(
          title: const Text(
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
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(1),
                    child: Icon(
                      _selectMuteAll ? Icons.mic_off : Icons.mic,
                      color: _selectMuteAll ? Colors.red : Colors.black,
                    ),
                  ),
                  onPressed: () {
                    _toggleSelectAll('talkToHost', !_selectMuteAll);
                  },
                ),
              ),
            ],
          ),
          onTap: null,
        ),
        const Divider(
          thickness: 0.2,
          color: Colors.white,
        ),
      ],
    );
  }

  Column _selectAllTogetherModeParticipants() {
    return Column(
      children: [
        ListTile(
          title: const Text(
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
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(1),
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
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(1),
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
        const Divider(
          thickness: 0.2,
          color: Colors.white,
        ),
      ],
    );
  }

  Widget _buildParticipantTile(
    BuildContext context, {
    required String name,
    ParticipantStatus? participantStatus,
    String? tabName,
    int? handRaiseRank,
    bool isFromHandRaised = false,
  }) {
    final pinnedProvider = Provider.of<PinnedParticipantProvider>(context);
    final isAdmin = participantStatus?.role == Role.admin.toString();
    final isLocal = participantStatus?.identity == widget.localParticipant?.identity;
      
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: participantStatus?.isSpotlight == true
            ? const Color(0xFF3D3D20) // Subtle highlight for spotlighted
            : pinnedProvider.isPinned(participantStatus!.identity)
                ? const Color(0xFF253342) // Subtle highlight for pinned
                : const Color(0xFF363636), // Regular tile background
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: participantStatus?.isSpotlight == true
              ? const Color(0xFFAA8800).withOpacity(0.4) // Spotlight border
              : pinnedProvider.isPinned(participantStatus!.identity)
                  ? const Color(0xFF4A88CF).withOpacity(0.4) // Pinned border
                  : const Color(0xFF4A4A4A), // Regular border
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isAdmin 
                        ? const Color(0xFF1E4D2B) // Host background 
                        : const Color(0xFF4A4A4A), // Regular background
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isAdmin
                          ? const Color(0xFF4CAF50) // Host border
                          : Colors.grey[600]!,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isAdmin ? Colors.greenAccent : Colors.white,
                      ),
                    ),
                  ),
                ),
                if (participantStatus?.isHandRaised == true)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF2C2C2C),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.pan_tool,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      fontSize: 15,
                      letterSpacing: isLocal ? 0.2 : 0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLocal)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF454545),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF606060),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'YOU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: () {
              List<Widget> labels = [];

              if (participantStatus?.isSpotlight == true) {
                labels.add(
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Spotlighted',
                      style: TextStyle(
                        color: Color(0xFFFFB74D),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }

              if (pinnedProvider.isPinned(participantStatus!.identity)) {
                labels.add(
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF2196F3).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Pinned',
                      style: TextStyle(
                        color: Color(0xFF64B5F6),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }

              if (isAdmin && !isLocal) {
                labels.add(
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Host',
                      style: TextStyle(
                        color: Color(0xFF81C784),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }

              if (isLocal && isAdmin) {
                labels.add(
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF009688).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF009688).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Host',
                      style: TextStyle(
                        color: Color(0xFF4DB6AC),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }

              if (handRaiseRank != null) {
                final rankLabel = ['1st', '2nd', '3rd'];
                final suffix = handRaiseRank < 3
                    ? rankLabel[handRaiseRank]
                    : '${handRaiseRank + 1}th';

                labels.add(
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Hand Raised ($suffix)',
                      style: const TextStyle(
                        color: Color(0xFFFFB74D),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }

              if (labels.isEmpty) return const SizedBox(height: 2);

              return Wrap(
                children: labels,
              );
            }(),
            trailing: tabName == 'Audio Manage'
                ? _getAudioManageTrailingIcons(participantStatus!, isFromHandRaised)
                : tabName == 'Together Mode'
                    ? _getTogetherModeTrailingIcons(participantStatus!)
                    : null,
          ),
        ],
      ),
    );
  }

  Row _getAudioManageTrailingIcons(
      ParticipantStatus participantStatus, bool isFromHandRaised) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParticipantControlIcon(
          isDisabled: participantStatus.role == Role.admin.toString(),
          isActive: participantStatus.isTalkToHostEnable,
          iconOn: Icons.mic,
          iconOff: Icons.mic_off,
          tooltipOn: 'Disallow to talk',
          tooltipOff: 'Allow to talk',
          colorActive: Colors.black,
          colorInactive: Colors.red,
          onTap: () {
            final newAllowToTalkStatus = !(participantStatus.isTalkToHostEnable);
            updateAllowToTalkStatus(participantStatus, newAllowToTalkStatus);
          },
        ),
        if (isFromHandRaised && participantStatus.isHandRaised)
          Tooltip(
            message: 'Raised hand',
            child: Container(
              padding: const EdgeInsets.all(1),
              child: const Icon(
                Icons.pan_tool,
                color: Colors.orange,
              ),
            ),
          ),
      ],
    );
  }

  Widget _getTogetherModeTrailingIcons(ParticipantStatus participantStatus) {
    final pinnedProvider = Provider.of<PinnedParticipantProvider>(context);
    final isPinned = pinnedProvider.isPinned(participantStatus.identity);
    final isLocalHost = participantStatus.role == Role.admin.toString();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParticipantControlIcon(
          isDisabled: isLocalHost,
          isActive: participantStatus.isAudioEnable,
          iconOn: Icons.volume_up,
          iconOff: Icons.volume_off,
          tooltipOn: 'Mute',
          tooltipOff: 'Unmute',
          colorActive: Colors.black,
          colorInactive: Colors.red,
          onTap: () {
            final newAudio = !(participantStatus.isAudioEnable);
            updateAudioVideoStatus(
                participantStatus, newAudio, participantStatus.isVideoEnable);
          },
        ),
        const SizedBox(width: 6),
        ParticipantControlIcon(
          isDisabled: isLocalHost,
          isActive: participantStatus.isVideoEnable,
          iconOn: Icons.videocam,
          iconOff: Icons.videocam_off,
          tooltipOn: 'Turn off video',
          tooltipOff: 'Turn on video',
          colorActive: Colors.black,
          colorInactive: Colors.red,
          onTap: () {
            final newVideo = !(participantStatus.isVideoEnable);
            updateAudioVideoStatus(
                participantStatus, participantStatus.isAudioEnable, newVideo);
          },
        ),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'pin',
              child: Row(
                children: [
                  Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: isPinned ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(isPinned ? 'Unpin' : 'Pin'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'spotlight',
              child: Row(
                children: [
                  Icon(
                    participantStatus.isSpotlight
                        ? Icons.highlight
                        : Icons.highlight_outlined,
                    color: participantStatus.isSpotlight
                        ? Colors.orange
                        : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(participantStatus.isSpotlight
                      ? 'Remove Spotlight'
                      : 'Spotlight'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'pin') {
              pinnedProvider.togglePin(participantStatus.identity);
            } else if (value == 'spotlight') {
              final newSpotlight = !(participantStatus.isSpotlight);
              updateSpotLightStatus(participantStatus, newSpotlight);
            }
          },
        )
      ],
    );
  }
}