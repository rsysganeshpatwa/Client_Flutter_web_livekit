// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:math' as math;

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get_it/get_it.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_meeting_room/exts.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/services/approval_service.dart';
import 'package:video_meeting_room/services/room_data_manage_service.dart';

import 'room.dart';

class JoinArgs {
  JoinArgs({
    required this.url,
    required this.token,
    this.e2ee = false,
    this.e2eeKey,
    this.simulcast = true,
    this.adaptiveStream = true,
    this.dynacast = true,
    this.preferredCodec = 'VP8',
    this.enableBackupVideoCodec = true,
    this.role = Role.participant,
    this.roomName = '',
    this.identity = '',
    this.roomId = '',
    this.muteByDefault = false,
    this.joinRequiresApproval = false,
    this.enableAudio = true,
    this.enableVideo = true,
  });
  final String url;
  final String token;
  final Role role;
  final bool e2ee;
  final String? e2eeKey;
  final bool simulcast;
  final bool adaptiveStream;
  final bool dynacast;
  final String preferredCodec;
  final bool enableBackupVideoCodec;
  final String roomName;
  final String identity;
  final String roomId;
  // Add other parameters as needed
  final bool muteByDefault;
  final bool joinRequiresApproval;
  final bool enableAudio;
  final bool enableVideo;
}

class PreJoinPage extends StatefulWidget {
  const PreJoinPage({
    required this.args,
    super.key,
  });
  final JoinArgs args;
  @override
  State<StatefulWidget> createState() => _PreJoinPageState();
}

class _PreJoinPageState extends State<PreJoinPage> {
  List<MediaDevice> _audioInputs = [];
  List<MediaDevice> _videoInputs = [];
  StreamSubscription? _subscription;

  bool _busy = false;
  bool _enableVideo = true;
  bool _enableAudio = true;
  LocalAudioTrack? _audioTrack;
  LocalVideoTrack? _videoTrack;

  MediaDevice? _selectedVideoDevice;
  MediaDevice? _selectedAudioDevice;
  VideoParameters _selectedVideoParameters = VideoParametersPresets.h720_169;
  final ApprovalService _approvalService = GetIt.instance<ApprovalService>();
  late SharedPreferences prefs;
  final RoomDataManageService _roomDataManageService =
      GetIt.instance<RoomDataManageService>();

  @override
  void initState() {
    super.initState();
    _subscription =
        Hardware.instance.onDeviceChange.stream.listen(_loadDevices);
    Hardware.instance.enumerateDevices().then(_loadDevices);
  }

  @override
  void deactivate() {
    _subscription?.cancel();
    super.deactivate();
  }

  void _loadDevices(List<MediaDevice> devices) async {
    // Request both camera and microphone permissions
    PermissionStatus cameraStatus = await Permission.camera.request();
    PermissionStatus microphoneStatus = await Permission.microphone.request();
    if (cameraStatus.isGranted || microphoneStatus.isGranted) {
      devices = await Hardware.instance.enumerateDevices();
    }
    _setEnableVideo(cameraStatus.isGranted);
    _setEnableAudio(microphoneStatus.isGranted);

    _audioInputs = microphoneStatus.isGranted
        ? devices.where((d) => d.kind == 'audioinput').toList()
        : [];
    _videoInputs = cameraStatus.isGranted
        ? devices.where((d) => d.kind == 'videoinput').toList()
        : [];

    if (_audioInputs.isNotEmpty) {
      if (_selectedAudioDevice == null) {
        _selectedAudioDevice = _audioInputs.first;
        Future.delayed(const Duration(milliseconds: 100), () async {
          await _changeLocalAudioTrack();
          setState(() {});
        });
      }
    }

    if (_videoInputs.isNotEmpty) {
      if (_selectedVideoDevice == null) {
        _selectedVideoDevice = _videoInputs.first;
        Future.delayed(const Duration(milliseconds: 100), () async {
          await _changeLocalVideoTrack();
          setState(() {});
        });
      }
    }
    setState(() {});
  }

  Future<void> _setEnableVideo(value) async {
    _enableVideo = value;
    if (!_enableVideo) {
      await _videoTrack?.stop();
      _videoTrack = null;
    } else {
      await _changeLocalVideoTrack();
    }
    setState(() {});
  }

  Future<void> _setEnableAudio(value) async {
    _enableAudio = value;
    if (!_enableAudio) {
      await _audioTrack?.stop();
      _audioTrack = null;
    } else {
      await _changeLocalAudioTrack();
    }
    setState(() {});
  }

  Future<void> _changeLocalAudioTrack() async {
    if (_audioTrack != null) {
      await _audioTrack!.stop();
      _audioTrack = null;
    }

    if (_selectedAudioDevice != null) {
      _audioTrack = await LocalAudioTrack.create(AudioCaptureOptions(
        deviceId: _selectedAudioDevice!.deviceId,
      ));
      await _audioTrack!.start();
    }
  }

  Future<void> _changeLocalVideoTrack() async {
    if (_videoTrack != null) {
      await _videoTrack!.stop();
      _videoTrack = null;
    }

    if (_selectedVideoDevice != null) {
      _videoTrack =
          await LocalVideoTrack.createCameraTrack(CameraCaptureOptions(
        deviceId: _selectedVideoDevice!.deviceId,
        params: _selectedVideoParameters,
      ));
      await _videoTrack!.start();
    }
  }

  @override
  void dispose() {
    print("pre join dispose");
    _subscription?.cancel();
    super.dispose();
  }

  Future<bool> _waitForApproval(
      String participantName, String roomName, String roomId) async {
    try {
      // Request approval before joining
      if (!mounted) return false;
      final request = await _approvalService.createApprovalRequest(
          participantName, roomName);
      final requestId = request['id'];

      // Initialize timer for 30 seconds
      const int timeout = 30;
      int elapsedTime = 0;
      bool approved = false;

      while (elapsedTime < timeout) {
        await Future.delayed(const Duration(seconds: 5));
        elapsedTime += 5;
        final statusResponse =
            await _approvalService.getRequestStatus(requestId);
        final status = statusResponse['status'];

        if (status == 'approved') {
          approved = true;
          if (!mounted) return false;
          context.showApprovalStatusDialog('approved');
          await _approvalService.removeRequest(requestId);
          return true; // Approval was granted
        } else if (status == 'rejected') {
          if (!mounted) return false;
          context.showApprovalStatusDialog('rejected');
          await _approvalService.removeRequest(requestId);
          return false; // Approval was denied
        }
      }

      // If 30 seconds have passed and no approval was granted
      if (!approved) {
         if (!mounted) return false;
        context
            .showApprovalStatusDialog('No host available, please try again.');
        await _approvalService.removeRequest(requestId);
        return false;
      }
    } catch (error) {
      print('Error during approval process: $error');
      return false; // Approval was not granted or an error occurred
    }
    return false; // Fallback, in case nothing happened
  }

  _join(BuildContext context) async {
    if (!mounted) return;
    _busy = true;

    setState(() {});

    var args = widget.args;

    try {
      // Wait for approval before proceeding
      // final isLoggedIn = prefs.getBool('isLoggedIn');
      if (args.role == Role.participant && args.joinRequiresApproval) {
        bool isApproved =
            await _waitForApproval(args.identity, args.roomName, args.roomId);
        if (!isApproved) {
          return;
        }
      }
      E2EEOptions? e2eeOptions;
      if (args.e2ee && args.e2eeKey != null) {
        final keyProvider = await BaseKeyProvider.create();
        e2eeOptions = E2EEOptions(keyProvider: keyProvider);
        await keyProvider.setKey(args.e2eeKey!);
      }

      //create new room
      final room = Room(
        roomOptions: RoomOptions(
          defaultCameraCaptureOptions: CameraCaptureOptions(
            maxFrameRate: 30,
            params: _selectedVideoParameters,
          ),
          defaultAudioCaptureOptions: AudioCaptureOptions(
            deviceId: _selectedAudioDevice?.deviceId,
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
          defaultScreenShareCaptureOptions: const ScreenShareCaptureOptions(
            useiOSBroadcastExtension: true,
            params: VideoParameters(
              dimensions: VideoDimensionsPresets.h1080_169,
              encoding: VideoEncoding(
                maxBitrate: 3 * 1000 * 1000,
                maxFramerate: 15,
              ),
            ),
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: args.simulcast,
            videoCodec: args.preferredCodec,
            backupVideoCodec: BackupVideoCodec(
              codec: 'VP8',
              enabled: args.enableBackupVideoCodec,
            ),
          ),
          defaultAudioPublishOptions: const AudioPublishOptions(
            name: 'custom_audio_track_name',
          ),
          adaptiveStream: args.adaptiveStream,
          dynacast: args.dynacast,
          e2eeOptions: e2eeOptions,
        ),
      );

      // Create a Listener before connecting
      final listener = room.createListener();
    
      // Try to connect to the room
      // This will throw an Exception if it fails for any reason.
      await room
          .connect(
        args.url,
        args.token,
        connectOptions: const ConnectOptions(
          autoSubscribe: false,
        ),
        fastConnectOptions: FastConnectOptions(
          microphone: TrackOption(track: _audioTrack),
          camera: TrackOption(track: _videoTrack),
        ),
      )
          .catchError((error) async {
        print('Could not connect $error');
        _roomDataManageService.removeParticipant(
            '', args.roomName, args.identity);
        await room.disconnect();
        if (!mounted || !context.mounted) return;
        context.showErrorDialog(error);
      });

      if (!mounted || !context.mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => RoomPage(room, listener, widget.args.muteByDefault,
                widget.args.enableAudio, widget.args.enableVideo)),
      );
    } catch (error) {
      print('Could not connect $error');
      if (!mounted || !context.mounted) return;
      await context.showErrorDialog(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
        ),
        body: Container(
            alignment: Alignment.center,
            color: Colors.white,
            // decoration: BoxDecoration(border:Border.all(color: Colors.black,width: 1) ),

            child: SingleChildScrollView(
                child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          '      Select Devices',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        )),
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                            width: 320,
                            height: 240,
                            child: Container(
                              alignment: Alignment.center,
                              color: Colors.black54,
                              child: _videoTrack != null
                                  ? VideoTrackRenderer(
                                      _videoTrack!,
                                      fit: RTCVideoViewObjectFit
                                          .RTCVideoViewObjectFitContain,
                                    )
                                  : Container(
                                      alignment: Alignment.center,
                                      child: LayoutBuilder(
                                        builder: (ctx, constraints) => Icon(
                                          Icons.videocam_off,
                                          color: Colors.white,
                                          size: math.min(constraints.maxHeight,
                                                  constraints.maxWidth) *
                                              0.5,
                                        ),
                                      ),
                                    ),
                            ))),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Camera:',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _enableVideo,
                            onChanged: (value) => _setEnableVideo(value),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2<MediaDevice>(
                          isExpanded: true,
                          disabledHint: const Text('Disable Camera'),
                          hint: const Text(
                            'Select Camera',
                          ),
                          items: _videoInputs
                              .map((MediaDevice item) =>
                                  DropdownMenuItem<MediaDevice>(
                                    value: item,
                                    child: Text(
                                      item.label,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          value: _selectedVideoDevice,
                          onChanged: (MediaDevice? value) async {
                            if (value != null) {
                              _selectedVideoDevice = value;
                              await _changeLocalVideoTrack();
                              setState(() {});
                            }
                          },
                          buttonStyleData: const ButtonStyleData(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            height: 40,
                            width: 140,
                          ),
                          menuItemStyleData: const MenuItemStyleData(
                            height: 40,
                          ),
                          dropdownStyleData: const DropdownStyleData(
                            decoration: BoxDecoration(
                              color: Colors
                                  .white, // Set the dropdown background color to white
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_enableVideo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 25),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton2<VideoParameters>(
                            isExpanded: true,
                            hint: const Text(
                              'Select Video Dimensions',
                              style: TextStyle(color: Colors.black),
                            ),
                            items: [
                              VideoParametersPresets.h480_43,
                              VideoParametersPresets.h540_169,
                              VideoParametersPresets.h720_169,
                              VideoParametersPresets.h1080_169,
                            ]
                                .map((VideoParameters item) =>
                                    DropdownMenuItem<VideoParameters>(
                                      value: item,
                                      child: Text(
                                        '${item.dimensions.width}x${item.dimensions.height}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            value: _selectedVideoParameters,
                            onChanged: (VideoParameters? value) async {
                              if (value != null) {
                                _selectedVideoParameters = value;
                                await _changeLocalVideoTrack();
                                setState(() {});
                              }
                            },
                            buttonStyleData: const ButtonStyleData(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              height: 40,
                              width: 140,
                            ),
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 16,
                            ),
                            menuItemStyleData: const MenuItemStyleData(
                              height: 40,
                            ),
                            dropdownStyleData: const DropdownStyleData(
                              decoration: BoxDecoration(
                                color: Colors
                                    .white, // Set the dropdown background color to white
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Microphone:',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _enableAudio,
                            onChanged: (value) => _setEnableAudio(value),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2<MediaDevice>(
                          isExpanded: true,
                          disabledHint: const Text(
                            'Disable Microphone',
                            style: TextStyle(color: Colors.black),
                          ),
                          hint: const Text(
                            'Select Micriphone',
                            style: TextStyle(color: Colors.black),
                          ),
                          items: _enableAudio
                              ? _audioInputs
                                  .map((MediaDevice item) =>
                                      DropdownMenuItem<MediaDevice>(
                                        value: item,
                                        child: Text(
                                          item.label,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ))
                                  .toList()
                              : [],
                          value: _selectedAudioDevice,
                          onChanged: (MediaDevice? value) async {
                            if (value != null) {
                              _selectedAudioDevice = value;
                              await _changeLocalAudioTrack();
                              setState(() {});
                            }
                          },
                          buttonStyleData: const ButtonStyleData(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            height: 40,
                            width: 140,
                          ),
                          menuItemStyleData: const MenuItemStyleData(
                            height: 40,
                          ),
                          dropdownStyleData: const DropdownStyleData(
                            decoration: BoxDecoration(
                              color: Colors
                                  .white, // Set the dropdown background color to white
                            ),
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _busy ? null : () => _join(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_busy)
                            const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: SizedBox(
                                height: 15,
                                width: 15,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          const Text(
                            'JOIN',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ]),
            ))));
  }
}
