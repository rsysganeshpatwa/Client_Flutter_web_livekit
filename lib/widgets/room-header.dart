// ignore_for_file: file_names, deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/widgets/codec_stats.dart';
import 'dart:async';
import '../stats_repo.dart';

class RoomHeader extends StatefulWidget {
  final Room room;
  final List<ParticipantStatus> participantsStatusList;
  final void Function(bool) onToggleRaiseHand;
  final bool isHandRaisedStatusChanged;
  final bool isAdmin;
  final Function(int) onGridSizeChanged;
  final VoidCallback onOpenSidebar;
  final bool isSidebarOpen;
  final bool isSideBarShouldVisible;
  final Function(bool) onToggleFocusMode;
  final bool isFocusModeOn;

  const RoomHeader({
    super.key,
    required this.room,
    required this.participantsStatusList,
    required this.onToggleRaiseHand,
    required this.isHandRaisedStatusChanged,
    required this.onGridSizeChanged,
    required this.isAdmin,
    required this.onOpenSidebar,
    required this.isSidebarOpen,
    required this.isSideBarShouldVisible,
    required this.onToggleFocusMode,
    required this.isFocusModeOn,
  });

  @override
  State<RoomHeader> createState() => _RoomHeaderState();
}

class _RoomHeaderState extends State<RoomHeader> {
  List<MediaDevice>? _audioInputs;
  List<MediaDevice>? _videoInputs;
  bool _isHandRaised = false;
  LocalParticipant get participant => widget.room.localParticipant!;

  int _currentGridSize = 4;

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
          _isHandRaised = false;
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
    final Size screenSize = MediaQuery.of(context).size;
    final double dialogWidth =
        screenSize.width < 600 ? screenSize.width * 0.9 : 400.0;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Container(
            width: dialogWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              // Gradient background
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade100,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12.0),
                      topRight: Radius.circular(12.0),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.mic, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Select Microphone',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: _audioInputs == null || _audioInputs!.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'No microphones found',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _audioInputs!.length,
                          itemBuilder: (context, index) {
                            final device = _audioInputs![index];
                            final isSelected = device.deviceId ==
                                widget.room.selectedAudioInputDeviceId;

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              leading: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.indigo
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.indigo
                                        : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 18)
                                    : null,
                              ),
                              title: Text(
                                device.label,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: Colors.black87,
                                ),
                              ),
                              onTap: () {
                                _selectAudioInput(device);
                                Navigator.pop(context);
                              },
                              hoverColor: Colors.indigo.withOpacity(0.1),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.indigo,
                        ),
                        child: const Text('CANCEL'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showVideoOptions(BuildContext context) async {
    final Size screenSize = MediaQuery.of(context).size;
    final double dialogWidth =
        screenSize.width < 600 ? screenSize.width * 0.9 : 400.0;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Container(
            width: dialogWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              // Gradient background
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade100,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12.0),
                      topRight: Radius.circular(12.0),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.videocam, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Select Camera',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: _videoInputs == null || _videoInputs!.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'No cameras found',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _videoInputs!.length,
                          itemBuilder: (context, index) {
                            final device = _videoInputs![index];
                            final isSelected = device.deviceId ==
                                widget.room.selectedVideoInputDeviceId;

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              leading: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.indigo
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.indigo
                                        : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 18)
                                    : null,
                              ),
                              title: Text(
                                device.label,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: Colors.black87,
                                ),
                              ),
                              onTap: () {
                                _selectVideoInput(device);
                                Navigator.pop(context);
                              },
                              hoverColor: Colors.indigo.withOpacity(0.1),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.indigo,
                        ),
                        child: const Text('CANCEL'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showCodecStatsDialog(BuildContext context, Map<String, String> stats) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CodecStatsDialog(
          room: widget.room,
          isAdmin: widget.isAdmin,
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

  void _handleGridSizeChange(int size) {
    setState(() {
      _currentGridSize = size;
    });
    widget.onGridSizeChanged(size);
  }

  void _toggleFocusMode() {
    widget.onToggleFocusMode(!widget.isFocusModeOn);
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    required bool isMobile,
    Color activeColor = Colors.white,
    Color inactiveColor = Colors.white,
    String? tooltip,
  }) {
    final String effectiveTooltip =
        tooltip ?? (isActive ? 'Disable $label' : 'Enable $label');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 36,
            width: 36,
            alignment: Alignment.center,
            child: Tooltip(
              message: effectiveTooltip,
              preferBelow: true,
              verticalOffset: 20,
              showDuration: const Duration(seconds: 2),
              child: IconButton(
                icon: Icon(
                  icon,
                  color: isActive ? activeColor : inactiveColor,
                  size: isMobile ? 20 : 24,
                ),
                onPressed: onPressed,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tight(const Size(36, 36)),
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                tooltip: null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 16,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupMenuButton<T>({
    required IconData icon,
    required String label,
    required bool isMobile,
    required List<PopupMenuItem<T>> Function(BuildContext) popupMenuBuilder,
    required Function(T) onSelected,
    Color iconColor = Colors.white,
    T? initialValue,
    String? tooltip,
  }) {
    final String effectiveTooltip = tooltip ?? 'Open $label options';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 36,
            width: 36,
            alignment: Alignment.center,
            child: PopupMenuButton<T>(
              initialValue: initialValue,
              padding: EdgeInsets.zero,
              icon: Icon(
                icon,
                color: iconColor,
                size: isMobile ? 20 : 24,
              ),
              tooltip: effectiveTooltip,
              itemBuilder: popupMenuBuilder,
              onSelected: onSelected,
              iconSize: isMobile ? 20 : 24,
              splashRadius: 18,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 16,
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
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

    final bool isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile && _currentGridSize != 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleGridSizeChange(4);
      });
    }

    return Container(
      // Increase vertical padding for better spacing
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.black.withOpacity(0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title section
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              'Leadership Conference',
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          // Middle stats section (unchanged)
          if (!isMobile)
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isAdmin)
                    Text(
                      'Total: ${widget.room.remoteParticipants.values.length + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  if (widget.isAdmin) const SizedBox(width: 12),
                  if (widget.isAdmin)
                    Text(
                      'Participants: $totalParticipantCount',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  if (widget.isAdmin) const SizedBox(width: 12),
                  if (widget.isAdmin)
                    Text(
                      'Hosts: $totalHostCount',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),

          // Controls section with more spacing
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end, // Align to end for better spacing
              children: [
                if (!widget.isAdmin)
                  _buildControlButton(
                    icon: Icons.pan_tool,
                    label: _isHandRaised ? 'Lower Hand' : 'Raise Hand',
                    isActive: _isHandRaised,
                    activeColor: Colors.orange,
                    onPressed: _toggleHandRaise,
                    isMobile: isMobile,
                    tooltip: _isHandRaised ? 'Lower your hand' : 'Raise your hand to get attention',
                  ),
                _buildControlButton(
                  icon: widget.isFocusModeOn
                      ? Icons.center_focus_strong
                      : Icons.center_focus_weak,
                  label: widget.isFocusModeOn ? 'Focus On' : 'Focus Off',
                  isActive: widget.isFocusModeOn,
                  activeColor: Colors.green,
                  onPressed: _toggleFocusMode,
                  isMobile: isMobile,
                  tooltip: widget.isFocusModeOn 
                      ? 'Turn off focus mode (controls will remain visible)' 
                      : 'Turn on focus mode (controls will auto-hide)',
                ),
                if (!isMobile)
                  _buildPopupMenuButton<int>(
                    icon: Icons.grid_view,
                    label: '$_currentGridSize Tiles',
                    isMobile: isMobile,
                    tooltip: 'Change the number of visible video tiles',
                    popupMenuBuilder: (BuildContext context) => [
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
                _buildPopupMenuButton<String>(
                  icon: Icons.settings,
                  label: 'Settings',
                  isMobile: isMobile,
                  tooltip: 'Adjust audio, video, and other settings',
                  popupMenuBuilder: (BuildContext context) {
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

                    if (isMobile) {
                      menuItems.add(
                        const PopupMenuItem<String>(
                          value: 'grid',
                          child: ListTile(
                            leading: Icon(Icons.grid_view,
                                color: Colors.black),
                            title: Text(
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
                  onSelected: (String value) {
                    if (value == 'Microphone') {
                      _showMicrophoneOptions(context);
                    } else if (value == 'Camera') {
                      _showVideoOptions(context);
                    } else if (value == 'codec') {
                      showCodecStatsDialog(context, StatsRepository().stats);
                    } else if (value == 'grid' && isMobile) {
                      _handleGridSizeChange(4);
                    }
                  },
                ),
                if (widget.isSideBarShouldVisible)
                  _buildControlButton(
                    icon: Icons.groups,
                    label: 'Participants',
                    isActive: widget.isSidebarOpen,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.5),
                    onPressed: widget.onOpenSidebar,
                    isMobile: isMobile,
                    tooltip: widget.isSidebarOpen 
                        ? 'Close participants panel' 
                        : 'Show participants panel',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
