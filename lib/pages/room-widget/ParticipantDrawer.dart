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
  
    // print('initState Select Mute All: $_selectMuteAll');
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
     //sortParticipants();
   //   // print('didUpdateWidget Select Mute All: $_selectMuteAll');
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
    // print('Toggle select all: $type, $value');
    setState(() {
      if (type == 'audio') {
        _selectAllAudio = value;
        final updatedList = widget.participantsStatusList.map((status) {
          // Update only if the participant is not an admin
          if (status.role != Role.admin.toString()) {
             return status.copyWith(isAudioEnable: _selectAllAudio,isTalkToHostEnable: _selectAllAudio);
          }
          return status; // Leave admin participants unchanged
        }).toList();
        widget.onParticipantsStatusChanged(updatedList);
      } else if (type == 'video') {
        _selectAllVideo = value;
        final updatedList = widget.participantsStatusList.map((status) {
          // Update only if the participant is not an admin
          if (status.role != Role.admin.toString()) {
        return status.copyWith(isVideoEnable: _selectAllVideo);
          }
          return status; // Leave admin participants unchanged
        
        }).toList();
        widget.onParticipantsStatusChanged(updatedList);
      } else {
        _selectMuteAll = value;
        // print('Select Mute All: $_selectMuteAll');
        final updatedList = widget.participantsStatusList.map((status) {
          // Update only if the participant is not an admin
          if (status.role != Role.admin.toString()) {
            // print('Select Mute All: status: ${status.toJson()}');
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
      isTalkToHostEnable: isAudio, // Auto enable talk to host if audio is enabled
    );
    _triggerParticipantsStatusUpdate(updatedStatus);
  }

  void updateSpotLightStatus(ParticipantStatus participantStatus, bool isSpotlight) {
   

    final updatedStatus = participantStatus.copyWith(
      isSpotlight: isSpotlight,
      isTalkToHostEnable: isSpotlight || participantStatus.isTalkToHostEnable, // Auto enable talk to host if pinned
      isAudioEnable: isSpotlight || participantStatus.isAudioEnable,
      isVideoEnable: isSpotlight || participantStatus.isVideoEnable
    );
    // print('Pin and spotlight status updated: ${updatedStatus.toJson()}');
      
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
    // print('Allow to talk status updated: ${updatedStatus.toJson()}');
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
      // print("Error retrieving participant status: $e");
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
      child: ScrollbarTheme(
        data: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(Colors.white),
          // ignore: deprecated_member_use
          trackColor: WidgetStateProperty.all(Colors.white.withOpacity(0.5)),
          thickness: WidgetStateProperty.all(6.0),
          radius: const Radius.circular(4.0),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.8),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment
                          .spaceBetween, // To push items to opposite ends
                      children: [
                       const  Text(
                          'Participants',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search participants',
                        prefixIcon: const Icon(Icons.search, color: Colors.white),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey[800],
                      ),
                      onChanged: widget.onSearchChanged,
                    ),
                   const SizedBox(height: 16),
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor:  Color(0xFF9FF5FF),
                            unselectedLabelColor: Colors.grey,
                            indicatorColor:  Color(
                                0xFF9FF5FF), // Updated indicator color
                            tabs: [
                              Tab(text: 'Audio Manage'),
                              Tab(text: 'Together Mode'),
                            ],
                          ),
                          SizedBox(
                            // as per drawer height:   // Set the height or use MediaQuery for dynamic sizing
                            height: MediaQuery.of(context).size.height,
                            child: TabBarView(
                              children: [
                                // Tab 1: Audio Manage
                                ListView(
                                  children: [
                                    if (isAnyParticipantRoleAvailableMoreThenOne)
                                      _selectAllTalkToHostModeParticipants(),
                              
                                    ..._buildAllParticipants('Audio Manage'),
                                  ],
                                ),
                                // Tab 2: Together Mode
                                ListView(
                                  children: [
                                    if (isAnyParticipantRoleAvailableMoreThenOne)
                                      _selectAllTogetherModeParticipants(),
                                   
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
      ),
    );
}
List<Widget> _buildAllParticipants(String tabName) {
  final participants = widget.filterParticipants(widget.searchQuery);
  final pinnedProvider = Provider.of<PinnedParticipantProvider>(context);

  // Extract participant info
  final participantInfoList = participants.map((track) {
    final metadata = track.participant.metadata;
    final role = metadata != null ? jsonDecode(metadata)['role'] : null;
    final status = _getParticipantStatus(track.participant.identity);

    return {
      'track': track,
      'role': role,
      'status': status,
    };
  }).toList();

  // Prepare sorted list of hand raised participants (for ranking)
  final handRaisedList = participantInfoList
      .where((info) =>
          info['status']?.isHandRaised == true &&
          info['status']?.handRaisedTimeStamp != null)
      .toList()
    ..sort((a, b) => a['status']
        .handRaisedTimeStamp
        .compareTo(b['status'].handRaisedTimeStamp));

  // Apply primary sort logic
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

    // Tie-break: sort hand raised by timestamp
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
    final participantName = track.participant.name ?? 'Unknown';

    // Compute rank index for hand raised if applicable
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
                    color: Colors.white, // White circle background
                  ),
                  padding: const EdgeInsets.all(1), // Padding to make it a circle
                  child: Icon(
                    _selectMuteAll ? Icons.mic_off : Icons.mic,
                    color: _selectMuteAll ? Colors.red : Colors.black,
                  ),
                ),
                onPressed: () {
                  // print('onPressed Select Mute All: $_selectMuteAll');
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
        color: Colors.white, // Optional, to make the divider visible
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
                    color: Colors.white, // White circle background
                  ),
                  padding: const EdgeInsets.all(1), // Padding for circle size
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
                    color: Colors.white, // White circle background
                  ),
                  padding: const EdgeInsets.all(1), // Padding for circle size
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
        color: Colors.white, // Optional for better visibility
      ),
    ],
  );
}


Widget _buildParticipantTile(
  BuildContext context, {
  required String name,
  ParticipantStatus? participantStatus,
  String? tabName,
  int? handRaiseRank, // NEW
  bool isFromHandRaised = false,
}) {
   final pinnedProvider = Provider.of<PinnedParticipantProvider>(context);
    
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Stack(
  clipBehavior: Clip.none,
  children: [
    const Icon(Icons.account_circle, size: 36, color: Colors.white),
    if (participantStatus?.isHandRaised == true)
      const Positioned(
        right: -2,
        top: -2,
        child: Icon(
          Icons.pan_tool,
          size: 20,
          color: Colors.orangeAccent,
        ),
      ),
  ],
),
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.normal,
              color: Colors.white,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: () {
            List<Widget> labels = [];

            if (participantStatus?.isSpotlight == true) {
              labels.add(const Text(
                'Spotlighted',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ));
            }

            if (pinnedProvider.isPinned(participantStatus!.identity)) {
              labels.add(const Text(
                'Pinned',
                style: TextStyle(color: Colors.blueAccent, fontSize: 12),
              ));
            }

            if (participantStatus.role == Role.admin.toString() &&
                participantStatus.identity != widget.localParticipant?.identity) {
              labels.add(const Text(
                'Host',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ));
            }

            if (participantStatus.identity == widget.localParticipant?.identity &&
                participantStatus.role == Role.admin.toString()) {
              labels.add(const Text(
                'You (Host)',
                style: TextStyle(color: Colors.tealAccent, fontSize: 12),
              ));
            }

            if (handRaiseRank != null) {
              final rankLabel = ['1st', '2nd', '3rd'];
              final suffix = handRaiseRank < 3
                  ? rankLabel[handRaiseRank]
                  : '${handRaiseRank + 1}th';

              labels.add(Text(
                'Hand Raised ($suffix)',
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ));
            }

            if (labels.isEmpty) return null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: labels,
            );
          }(),
          trailing: tabName == 'Audio Manage'
              ? _getAudioManageTrailingIcons(participantStatus!, isFromHandRaised)
              : tabName == 'Together Mode'
                  ? _getTogetherModeTrailingIcons(participantStatus!)
                  : null,
        ),
        const Divider(thickness: 0.2, color: Colors.white30),
      ],
    ),
  );
}

Row _getAudioManageTrailingIcons(ParticipantStatus participantStatus,bool isFromHandRaised) {
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
          updateAllowToTalkStatus(
              participantStatus, newAllowToTalkStatus);
        },
      ),
      if (isFromHandRaised && participantStatus.isHandRaised )
        Tooltip(
          message: 'Raised hand',
          child: Container(
           
            padding: const EdgeInsets.all(1), // Padding to make it a circle
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
  final pinnedProvider =
      Provider.of<PinnedParticipantProvider>(context);
  final isPinned = pinnedProvider.isPinned(participantStatus.identity);
  final isLocalHost = participantStatus.role == Role.admin.toString() ;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      
      ParticipantControlIcon(
        isDisabled: isLocalHost,
        isActive: participantStatus.isAudioEnable ,
        iconOn: Icons.volume_up,
        iconOff: Icons.volume_off,
        tooltipOn: 'Mute',
        tooltipOff: 'Unmute',
        colorActive: Colors.black,
        colorInactive: Colors.red,
        onTap: () {
          final newAudio = !(participantStatus.isAudioEnable );
          updateAudioVideoStatus(
              participantStatus, newAudio, participantStatus.isVideoEnable);
        },
      ),
      const SizedBox(width: 6),
    
      ParticipantControlIcon(
        isDisabled: isLocalHost,
        isActive: participantStatus.isVideoEnable ,
        iconOn: Icons.videocam,
        iconOff: Icons.videocam_off,
        tooltipOn: 'Turn off video',
        tooltipOff: 'Turn on video',
        colorActive: Colors.black,
        colorInactive: Colors.red,
        onTap: () {
          final newVideo = !(participantStatus.isVideoEnable );
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
                  isPinned 
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  color: isPinned 
                      ? Colors.blue
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(isPinned  ? 'Unpin' : 'Pin'),
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
            final newSpotlight = !(participantStatus.isSpotlight );
            updateSpotLightStatus(
                participantStatus, newSpotlight);
          }
        },
      )
    ],
  );
}

}