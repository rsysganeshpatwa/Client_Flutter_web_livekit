import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_meeting_room/models/role.dart';

import '../exts.dart';

class ControlsWidget extends StatefulWidget {
  final Room room;
  final LocalParticipant participant;
  final void Function(bool) onToggleParticipants;
  final void Function(bool) onToggleRaiseHand;
  final String? role;
  final bool isHandleRaiseHand;
  final bool isHandleMuteAll;

  const ControlsWidget(
    this.onToggleParticipants,
    this.onToggleRaiseHand,
    this.isHandleMuteAll,
    this.isHandleRaiseHand,
    this.role,
    this.room,
    this.participant, {
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
  }

  @override
  void dispose() {
    _subscription?.cancel();
    widget.participant.removeListener(_onChange);
    super.dispose();
  }

  LocalParticipant get participant => widget.participant;

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
              notificationImportance: AndroidNotificationImportance.Default,
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
    if (result == true) await widget.room.disconnect();
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
      print('${result}');

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

  Future<void> _showMicrophoneOptions(BuildContext context) async {
	  showModalBottomSheet(
		context: context,
		builder: (BuildContext context) {
		  return SafeArea(
			child: Container(
			  width: MediaQuery.of(context).size.width * 0.2, // 20% of screen width
			  child: ListView(
				shrinkWrap: true, // Ensures ListView takes up as much space as it needs
				children: [
				  if (_audioInputs != null)
					..._audioInputs!.map((device) {
					  return ListTile(
						leading: (device.deviceId == widget.room.selectedAudioInputDeviceId)
							? const Icon(Icons.check_box_outlined, color: Colors.black)
							: const Icon(Icons.check_box_outline_blank, color: Colors.black),
						title: Text(device.label),
						onTap: () {
						  _selectAudioInput(device);
						  Navigator.pop(context); // Close the bottom sheet after selection
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
		builder: (BuildContext context) {
		  return SafeArea(
			child: Container(
			  width: MediaQuery.of(context).size.width * 0.2, // 20% of screen width
			  child: ListView(
				shrinkWrap: true, // Ensures ListView takes up as much space as it needs
				children: [
				  if (_videoInputs != null)
					..._videoInputs!.map((device) {
					  return ListTile(
						leading: (device.deviceId == widget.room.selectedVideoInputDeviceId)
							? const Icon(Icons.check_box_outlined, color: Colors.black)
							: const Icon(Icons.check_box_outline_blank, color: Colors.black),
						title: Text(device.label),
						onTap: () {
						  _selectVideoInput(device);
						  Navigator.pop(context); // Close the bottom sheet after selection
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
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 15,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 5,
        runSpacing: 5,
        children: [
          Visibility(
            visible: false,
            child: IconButton(
              onPressed: _unpublishAll,
              icon: const Icon(Icons.cancel),
              tooltip: 'Unpublish all',
            ),
          ),
          Visibility(
            visible: widget.role == Role.admin.toString() ? true : false,
            child: IconButton(
              onPressed: _toggleMuteAll,
              icon: Icon(
                _allMuted ? Icons.volume_off : Icons.volume_up,
              ),
              tooltip: _allMuted ? 'Unmute all' : 'Mute all',
            ),
          ),
          if (participant.isMicrophoneEnabled())
            Visibility(
                visible: true,
                child: IconButton(
                  onPressed: _disableAudio,
                  icon: const Icon(Icons.mic),
                  tooltip: 'mute audio',
                ),
              )
            else
            Visibility(
              visible: true,
              child: IconButton(
                onPressed: _enableAudio,
                icon: const Icon(Icons.mic_off),
                tooltip: 'un-mute audio',
              ),
            ),
          if (!lkPlatformIs(PlatformType.iOS))
            Visibility(
              visible: false,
              child: PopupMenuButton<MediaDevice>(
                icon: const Icon(Icons.volume_up),
                itemBuilder: (BuildContext context) {
                  return [
                    const PopupMenuItem<MediaDevice>(
                      value: null,
                      child: ListTile(
                        leading: Icon(
                          Icons.speaker,
                          color: Colors.white,
                        ),
                        title: Text('Select Audio Output'),
                      ),
                    ),
                    if (_audioOutputs != null)
                      ..._audioOutputs!.map((device) {
                        return PopupMenuItem<MediaDevice>(
                          value: device,
                          child: ListTile(
                            leading: (device.deviceId ==
                                    widget.room.selectedAudioOutputDeviceId)
                                ? const Icon(
                                    Icons.check_box_outlined,
                                    color: Colors.white,
                                  )
                                : const Icon(
                                    Icons.check_box_outline_blank,
                                    color: Colors.white,
                                  ),
                            title: Text(device.label),
                          ),
                          onTap: () => _selectAudioOutput(device),
                        );
                      })
                  ];
                },
              ),
            ),
          if (!kIsWeb && lkPlatformIs(PlatformType.iOS))
            Visibility(
              visible: false,
              child: IconButton(
                disabledColor: Colors.grey,
                onPressed: Hardware.instance.canSwitchSpeakerphone
                    ? _setSpeakerphoneOn
                    : null,
                icon: Icon(_speakerphoneOn
                    ? Icons.speaker_phone
                    : Icons.phone_android),
                tooltip: 'Switch SpeakerPhone',
              ),
            ),
          if (participant.isCameraEnabled())
            Visibility(
              visible: true,
              child: IconButton(
                onPressed: _disableVideo,
                icon: const Icon(Icons.videocam_sharp),
                tooltip: 'Mute video',
                
              ),
            )
          else
            Visibility(
              visible: true,
              child: IconButton(
                onPressed: _enableVideo,
                icon: const Icon(Icons.videocam_off),
                tooltip: 'un-mute video',
              ),
            ),
          Visibility(
            visible: false,
            child: IconButton(
              icon: Icon(position == CameraPosition.back
                  ? Icons.video_camera_back
                  : Icons.video_camera_front),
              onPressed: () => _toggleCamera(),
              tooltip: 'toggle camera',
            ),
          ),
          if (participant.isScreenShareEnabled())
            Visibility(
              visible: false,
              child: IconButton(
                icon: const Icon(Icons.monitor_outlined),
                onPressed: () => _disableScreenShare(),
                tooltip: 'unshare screen (experimental)',
              ),
            )
          else
            Visibility(
              visible: false,
              child: IconButton(
                icon: const Icon(Icons.monitor),
                onPressed: () => _enableScreenShare(),
                tooltip: 'share screen (experimental)',
              ),
            ),
          Visibility(
            visible: true,
            child: IconButton(
              onPressed: _onTapDisconnect,
              icon: const Icon(Icons.close_sharp),
              tooltip: 'disconnect',
            ),
          ),
          Visibility(
            visible: false,
            child: IconButton(
              onPressed: _onTapSendData,
              icon: const Icon(Icons.message),
              tooltip: 'send demo data',
            ),
          ),
          Visibility(
            visible: false,
            child: IconButton(
              onPressed: _onTapUpdateSubscribePermission,
              icon: const Icon(Icons.settings),
              tooltip: 'Subscribe permission',
            ),
          ),
          Visibility(
            visible: false,
            child: IconButton(
              onPressed: _onTapSimulateScenario,
              icon: const Icon(Icons.bug_report),
              tooltip: 'Simulate scenario',
            ),
          ),
          Visibility(
            visible: widget.role == Role.admin.toString() ? false : true,
            child: // New Raise Hand Button
                IconButton(
              icon: Icon(
                _isHandRaised ? Icons.pan_tool : Icons.pan_tool_outlined,
                color: _isHandRaised ? Colors.amber : Colors.white,
              ),
              onPressed: _toggleRaiseHand,
            ),
          ),
          Visibility(
            visible: true,
            child: PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
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
              const PopupMenuItem<String>(
                value: 'Microphone',
                child: ListTile(
                leading: Icon(Icons.mic),
                title: Text('Microphone'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'Camera',
                child: ListTile(
                leading: Icon(Icons.videocam),
                title: Text('Camera'),
                ),
                    ),
                  ];
                },
              ),
            ),
        ],
      ),
    );
  }
}
