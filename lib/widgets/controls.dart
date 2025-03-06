import 'dart:async';
import 'dart:convert';


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:get_it/get_it.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/services/room_data_manage_service.dart';

import '../exts.dart';

class ControlsWidget extends StatefulWidget {
  final Room room;
  final LocalParticipant participant;
  final void Function(bool) onToggleParticipants;
  final void Function(bool) onToggleRaiseHand;
  final String? role;
  final bool isHandleRaiseHand;
  final bool isHandleMuteAll;
  final List<ParticipantStatus> participantsStatusList;
  final VoidCallback openParticipantDrawer;
  final VoidCallback openCopyInviteLinkDialog;
  

  const ControlsWidget(
    this.onToggleParticipants,
    this.onToggleRaiseHand,
    this.openParticipantDrawer,
    this.openCopyInviteLinkDialog,
    this.isHandleMuteAll,
    this.isHandleRaiseHand,
    this.role,
    this.room,
    this.participant,
    this.participantsStatusList, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _ControlsWidgetState();
}

class _ControlsWidgetState extends State<ControlsWidget> {
  CameraPosition position = CameraPosition.front;

  List<MediaDevice>? _audioInputs;
  List<MediaDevice>? _audioOutputs;
  List<MediaDevice>? _videoInputs;

  StreamSubscription? _subscription;

  bool _speakerphoneOn = Hardware.instance.preferSpeakerOutput;
  bool _allMuted = true; // Track mute state for all participants
  bool _isHandRaised = false; // Track the "Raise Hand" state
  bool _showMoreControls = true;
  final RoomDataManageService _roomDataManageService = GetIt.instance<RoomDataManageService>();

  @override
  void initState() {
    super.initState();
    widget.participant.addListener(_onChange);
    _subscription = Hardware.instance.onDeviceChange.stream
        .listen((List<MediaDevice> devices) {
      _loadDevices(devices);
    });
    Hardware.instance.enumerateDevices().then(_loadDevices);
  }

  @override
  void didUpdateWidget(ControlsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHandleRaiseHand != oldWidget.isHandleRaiseHand) {
      if (!widget.isHandleRaiseHand) {
        setState(() {
          _isHandRaised =
              false; // Reset local state if isHandleRaiseHand is false
        });
      }
    }
    if (widget.isHandleMuteAll != oldWidget.isHandleMuteAll) {
      setState(() {
        _allMuted =
            widget.isHandleMuteAll; // Set local state to match parent state
      });
    }

    if (widget.participantsStatusList != oldWidget.participantsStatusList) {
      setState(() {
        _allMuted = !_areAllParticipantMuted();
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    widget.participant.removeListener(_onChange);
    super.dispose();
  }

  LocalParticipant get participant => widget.participant;

  bool _areAllParticipantMuted() {
    return widget.participantsStatusList
        .every((status) => status.isTalkToHostEnable);
  }

  void _loadDevices(List<MediaDevice> devices) async {
    _audioInputs = devices.where((d) => d.kind == 'audioinput').toList();
    _audioOutputs = devices.where((d) => d.kind == 'audiooutput').toList();
    _videoInputs = devices.where((d) => d.kind == 'videoinput').toList();
    setState(() {});
  }

  void _onChange() {
    // trigger refresh
    setState(() {});
  }

  void _toggleRaiseHand() {
    setState(() {
      _isHandRaised = !_isHandRaised;
    });

    widget.onToggleRaiseHand(_isHandRaised); // Call the parent function
  }

  void _unpublishAll() async {
    final result = await context.showUnPublishDialog();
    if (result == true) await participant.unpublishAllTracks();
  }

  bool get isMuted => participant.isMuted;

  void _toggleMuteAll() async {
    widget.onToggleParticipants(!_allMuted);
    setState(() {
      _allMuted = !_allMuted;
    });
  }

  void _disableAudio() async {
    await participant.setMicrophoneEnabled(false);
  }

  Future<void> _enableAudio() async {
    await participant.setMicrophoneEnabled(true);
  }

  void _disableVideo() async {
    await participant.setCameraEnabled(false);
  }

  void _enableVideo() async {
    await participant.setCameraEnabled(true);
  }

  void _selectAudioOutput(MediaDevice device) async {
    await widget.room.setAudioOutputDevice(device);
    setState(() {});
  }

  void _selectAudioInput(MediaDevice device) async {
    await widget.room.setAudioInputDevice(device);
    setState(() {});
  }

  void _selectVideoInput(MediaDevice device) async {
    await widget.room.setVideoInputDevice(device);
    setState(() {});
  }

  void _setSpeakerphoneOn() {
    _speakerphoneOn = !_speakerphoneOn;
    Hardware.instance.setSpeakerphoneOn(_speakerphoneOn);
    setState(() {});
  }

  void _toggleCamera() async {
    final track = participant.videoTrackPublications.firstOrNull?.track;
    if (track == null) return;

    try {
      final newPosition = position.switched();
      await track.setCameraPosition(newPosition);
      setState(() {
        position = newPosition;
      });
    } catch (error) {
      print('could not restart track: $error');
      return;
    }
  }

  void _enableScreenShare() async {
	  int screenShareCount=widget.room.remoteParticipants.values.where((element) => element.isScreenShareEnabled()).length;
    if (screenShareCount < 2){
    if (lkPlatformIsDesktop()) {
      try {
        final source = await showDialog<DesktopCapturerSource>(
          context: context,
          builder: (context) => ScreenSelectDialog(),
        );
        if (source == null) {
          print('cancelled screenshare');
          return;
        }
        print('DesktopCapturerSource: ${source.id}');
        var track = await LocalVideoTrack.createScreenShareTrack(
          ScreenShareCaptureOptions(
            sourceId: source.id,
            maxFrameRate: 15.0,
          ),
        );
        await participant.publishVideoTrack(track);
      } catch (e) {
        print('could not publish video: $e');
      }
      return;
    }
    if (lkPlatformIs(PlatformType.android)) {
      bool hasCapturePermission = await Helper.requestCapturePermission();
      if (!hasCapturePermission) {
        return;
      }

      requestBackgroundPermission([bool isRetry = false]) async {
        try {
          bool hasPermissions = await FlutterBackground.hasPermissions;
          if (!isRetry) {
            const androidConfig = FlutterBackgroundAndroidConfig(
              notificationTitle: 'Screen Sharing',
              notificationText: 'LiveKit Example is sharing the screen.',
          //    notificationImportance: AndroidNotificationImportance.Default,
              notificationIcon: AndroidResource(
                  name: 'livekit_ic_launcher', defType: 'mipmap'),
            );
            hasPermissions = await FlutterBackground.initialize(
                androidConfig: androidConfig);
          }
          if (hasPermissions &&
              !FlutterBackground.isBackgroundExecutionEnabled) {
            await FlutterBackground.enableBackgroundExecution();
          }
        } catch (e) {
          if (!isRetry) {
            return await Future<void>.delayed(const Duration(seconds: 1),
                () => requestBackgroundPermission(true));
          }
          print('could not publish video: $e');
        }
      }

      await requestBackgroundPermission();
    }
    if (lkPlatformIs(PlatformType.iOS)) {
      var track = await LocalVideoTrack.createScreenShareTrack(
        const ScreenShareCaptureOptions(
          useiOSBroadcastExtension: true,
          maxFrameRate: 15.0,
        ),
      );
      await participant.publishVideoTrack(track);
      return;
    }

    if (lkPlatformIsWebMobile()) {
      await context
          .showErrorDialog('Screen share is not supported on mobile web');
      return;
    }

    await participant.setScreenShareEnabled(true, captureScreenAudio: true);
	} else {
      // Show a popup when screenShareCount is 2 or more
      showDialog(
        context: context,
        builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Screen Share Limit Reached"),
          content: Text(
            "${screenShareCount} Admins are already sharing their screens. You can't share your screen as the limit is 2."),
          actions: <Widget>[
          TextButton(
            child: Text("OK"),
            onPressed: () {
            Navigator.of(context).pop(); // Dismiss the dialog
            },
          ),
          ],
        );
        },
      );
      }
    }

  void _disableScreenShare() async {
    await participant.setScreenShareEnabled(false);
    if (lkPlatformIs(PlatformType.android)) {
      try {
        // await FlutterBackground.disableBackgroundExecution();
      } catch (error) {
        print('error disabling screen share: $error');
      }
    }
  }

  void _onTapDisconnect() async {
    final result = await context.showDisconnectDialog();
    if (result == true){
      final roomId = await widget.room.getSid();
      // Get local participant identity
      final localParticipant = widget.room.localParticipant;
      final identity = localParticipant?.identity;
      final roomName =  widget.room.name!;
      _roomDataManageService.removeParticipant(roomId,roomName,identity);
      await widget.room.disconnect();
    }
  }

  void _onTapUpdateSubscribePermission() async {
    final result = await context.showSubscribePermissionDialog();
    if (result != null) {
      try {
        widget.room.localParticipant?.setTrackSubscriptionPermissions(
          allParticipantsAllowed: result,
        );
      } catch (error) {
        await context.showErrorDialog(error);
      }
    }
  }

  void _onTapSimulateScenario() async {
    final result = await context.showSimulateScenarioDialog();
    if (result != null) {
      print('$result');

      if (SimulateScenarioResult.e2eeKeyRatchet == result) {
        await widget.room.e2eeManager?.ratchetKey();
      }

      if (SimulateScenarioResult.participantMetadata == result) {
        widget.room.localParticipant?.setMetadata(
            'new metadata ${widget.room.localParticipant?.identity}');
      }

      if (SimulateScenarioResult.participantName == result) {
        widget.room.localParticipant
            ?.setName('new name for ${widget.room.localParticipant?.identity}');
      }

      await widget.room.sendSimulateScenario(
        speakerUpdate:
            result == SimulateScenarioResult.speakerUpdate ? 3 : null,
        signalReconnect:
            result == SimulateScenarioResult.signalReconnect ? true : null,
        fullReconnect:
            result == SimulateScenarioResult.fullReconnect ? true : null,
        nodeFailure: result == SimulateScenarioResult.nodeFailure ? true : null,
        migration: result == SimulateScenarioResult.migration ? true : null,
        serverLeave: result == SimulateScenarioResult.serverLeave ? true : null,
        switchCandidate:
            result == SimulateScenarioResult.switchCandidate ? true : null,
      );
    }
  }

  void _onTapSendData() async {
    final result = await context.showSendDataDialog();
    if (result == true) {
      await widget.participant.publishData(
        utf8.encode('This is a sample data message'),
      );
    }
  }

  void _handleParticipantDrawer() {
    widget.openParticipantDrawer();
  }

  void _handleCopyInviteLink() {
    widget.openCopyInviteLinkDialog();
  }

  Future<void> _showMicrophoneOptions(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            width:
                MediaQuery.of(context).size.width * 0.2, // 20% of screen width
            child: ListView(
              shrinkWrap:
                  true, // Ensures ListView takes up as much space as it needs
              children: [
                if (_audioInputs != null)
                  ..._audioInputs!.map((device) {
                    return ListTile(
                      leading: (device.deviceId ==
                              widget.room.selectedAudioInputDeviceId)
                          ? const Icon(Icons.check_box_outlined,
                              color: Colors.black)
                          : const Icon(Icons.check_box_outline_blank,
                              color: Colors.black),
                      title: Text(device.label),
                      onTap: () {
                        _selectAudioInput(device);
                        Navigator.pop(
                            context); // Close the bottom sheet after selection
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
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            width:
                MediaQuery.of(context).size.width * 0.2, // 20% of screen width
            child: ListView(
              shrinkWrap:
                  true, // Ensures ListView takes up as much space as it needs
              children: [
                if (_videoInputs != null)
                  ..._videoInputs!.map((device) {
                    return ListTile(
                      leading: (device.deviceId ==
                              widget.room.selectedVideoInputDeviceId)
                          ? const Icon(Icons.check_box_outlined,
                              color: Colors.black)
                          : const Icon(Icons.check_box_outline_blank,
                              color: Colors.black),
                      title: Text(device.label),
                      onTap: () {
                        _selectVideoInput(device);
                        Navigator.pop(
                            context); // Close the bottom sheet after selection
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

  @override
Widget build(BuildContext context) {
  bool isMobile = MediaQuery.of(context).size.width < 600; // Example breakpoint for mobile

  return Container(
    padding: EdgeInsets.all(8),
    color: Colors.black.withOpacity(0.8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left-aligned button
        Tooltip(
          message: 'Disconnect',
          child: _buildControlButton(
            Icons.call_end,
            Colors.deepOrange,
            _onTapDisconnect,
            Colors.white,
             isMobile: isMobile
          ),
        ),
        // Center-aligned buttons
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: Wrap(
              spacing: 8, // Horizontal space between buttons
              runSpacing: 8, // Vertical space between rows of buttons
              alignment: WrapAlignment.center, // Center buttons within this area
              children: [
                if (widget.role == Role.admin.toString())
                  Tooltip(
                    message: _allMuted ? 'Unmute All Participants' : 'Mute All Participants',
                    child: _buildControlButton(
                      _allMuted ? Icons.volume_off : Icons.volume_up,
                      Colors.white,
                      _toggleMuteAll,
                      Colors.black,
                      isMobile: isMobile
                    ),
                  ),
                Tooltip(
                  message: participant.isMicrophoneEnabled()
                      ? 'Mute Microphone'
                      : 'Unmute Microphone',
                  child: _buildControlButton(
                    participant.isMicrophoneEnabled()
                        ? Icons.mic
                        : Icons.mic_off,
                    !participant.isMicrophoneEnabled()
                        ? Colors.deepOrange
                        : Colors.white,
                    participant.isMicrophoneEnabled()
                        ? _disableAudio
                        : _enableAudio,
                    !participant.isMicrophoneEnabled()
                        ? Colors.white
                        : Colors.black,
                         isMobile: isMobile
                  ),
                ),
                Tooltip(
                  message: participant.isCameraEnabled()
                      ? 'Turn Off Camera'
                      : 'Turn On Camera',
                  child: _buildControlButton(
                    participant.isCameraEnabled()
                        ? Icons.videocam
                        : Icons.videocam_off,
                    !participant.isCameraEnabled()
                        ? Colors.deepOrange
                        : Colors.white,
                    participant.isCameraEnabled()
                        ? _disableVideo
                        : _enableVideo,
                    !participant.isCameraEnabled()
                        ? Colors.white
                        : Colors.black,
                         isMobile: isMobile
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right-aligned buttons or More Controls icon
        if (!isMobile) ...[
          // Always visible on non-mobile devices
          if (widget.role == Role.admin.toString()) ...[
            Tooltip(
              message: participant.isScreenShareEnabled()
                  ? 'Stop Screen Share'
                  : 'Start Screen Share',
              child: _buildControlButton(
                participant.isScreenShareEnabled()
                    ? Icons.stop_screen_share
                    : Icons.screen_share,
                Colors.white,
                participant.isScreenShareEnabled()
                    ? _disableScreenShare
                    : _enableScreenShare,
                Colors.black,
              ),
            ),
            SizedBox(width: 8),
            Tooltip(
              message: 'View Participants',
              child: _buildControlButton(
                Icons.people_alt,
                Colors.white,
                () => _handleParticipantDrawer(),
                Colors.black,
              ),
            ),
            SizedBox(width: 8),
            Tooltip(
              message: 'Copy Invite Link',
              child: _buildControlButton(
                Icons.link,
                Colors.white,
                () => _handleCopyInviteLink(),
                Colors.black,
              ),
            ),
          ],
        ] else ...[
          // Mobile-specific More Controls icon
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'ScreenShare':
                  participant.isScreenShareEnabled()
                      ? _disableScreenShare()
                      : _enableScreenShare();
                  break;
                case 'ViewParticipants':
                  _handleParticipantDrawer();
                  break;
                case 'CopyLink':
                  _handleCopyInviteLink();
                  break;
                case 'AnotherAction1':
                  // Handle another action
                  break;
                case 'AnotherAction2':
                  // Handle another action
                  break;
              }
            },
            itemBuilder: (context) => [
              if (widget.role == Role.admin.toString()) ...[
                PopupMenuItem(
                  value: 'ScreenShare',
                  child: ListTile(
                    leading: Icon(participant.isScreenShareEnabled()
                        ? Icons.stop_screen_share
                        : Icons.screen_share),
                    title: Text(participant.isScreenShareEnabled()
                        ? 'Stop Screen Share'
                        : 'Start Screen Share'),
                  ),
                ),
                PopupMenuItem(
                  value: 'ViewParticipants',
                  child: ListTile(
                    leading: Icon(Icons.people_alt),
                    title: Text('View Participants'),
                  ),
                ),
                PopupMenuItem(
                  value: 'CopyLink',
                  child: ListTile(
                    leading: Icon(Icons.link),
                    title: Text('Copy Invite Link'),
                  ),
                ),
              ],
             
            ],
              icon: Container(
                 width: 40, // Set the desired width
  height: 40, // Set the desired height
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.more_horiz_rounded, color: Colors.black),
              ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildControlButton(IconData iconImage, Color color,
      VoidCallback onPressed, Color iconColor,{bool isMobile=false}) {
      
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: CircleBorder(),
        padding: EdgeInsets.all(8),
        minimumSize:isMobile ? Size(40, 40) : Size(50, 50),
      ),
      onPressed: onPressed,
      child: Icon(
        iconImage,
        color: iconColor,
      ),
    );
  }
 
}
