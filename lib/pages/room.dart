import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/method_channels/replay_kit_channel.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/pages/room-widget/CopyInviteLinkDialog.dart';
import 'package:video_meeting_room/pages/room-widget/FloatingActionButtonBar.dart';
import 'package:video_meeting_room/pages/room-widget/HandRaiseNotification.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantDrawer.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantGridView.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantSelectionDialog.dart';

import '../exts.dart';
import '../utils.dart';
import '../widgets/controls.dart';
import '../widgets/participant.dart';
import '../widgets/participant_info.dart';

class RoomPage extends StatefulWidget {
  final Room room;
  final EventsListener<RoomEvent> listener;

  const RoomPage(
    this.room,
    this.listener, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  List<ParticipantTrack> participantTracks = [];
  EventsListener<RoomEvent> get _listener => widget.listener;
  bool get fastConnection => widget.room.engine.fastConnectOptions != null;
  bool _flagStartedReplayKit = false;
  bool _muteAll = true;
  bool _isHandleRaiseHand = false;
  String searchQuery = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? localParticipantRole;
  List<ParticipantStatus> participantsManager = [];
  bool _isScreenShareMode = false; // State to toggle view mode

  @override
  void initState() {
    super.initState();
    widget.room.addListener(_onRoomDidUpdate);
    _setUpListeners();
    // Set up role for the local participant
    _initializeLocalParticipantRole();
    _sortParticipants();
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      if (!fastConnection) {
        _askPublish();
      }
    });

    if (lkPlatformIs(PlatformType.android)) {
      Hardware.instance.setSpeakerphoneOn(true);
    }

    if (lkPlatformIs(PlatformType.iOS)) {
      ReplayKitChannel.listenMethodChannel(widget.room);
    }

    if (lkPlatformIsDesktop()) {
      onWindowShouldClose = () async {
        unawaited(widget.room.disconnect());
        await _listener.waitFor<RoomDisconnectedEvent>(
            duration: const Duration(seconds: 5));
      };
    }
  }

  @override
  void dispose() {
    (() async {
      if (lkPlatformIs(PlatformType.iOS)) {
        ReplayKitChannel.closeReplayKit();
      }
      widget.room.removeListener(_onRoomDidUpdate);
      await _listener.dispose();
      await widget.room.dispose();
    })();
    onWindowShouldClose = null;
    super.dispose();
  }

  void _initializeLocalParticipantRole() {
    final localParticipant = widget.room.localParticipant;
    if (localParticipant != null) {
      final metadata = localParticipant.metadata;
      final role = metadata != null ? jsonDecode(metadata)['role'] : null;
      setState(() {
        localParticipantRole = role.toString();
        _initializeParticipantStatuses();
      });
    }
  }

  void _setUpListeners() => _listener
    ..on<RoomDisconnectedEvent>((event) async {
      if (event.reason != null) {
        // print('Room disconnected: reason => ${event.reason}');
      }
      WidgetsBinding.instance?.addPostFrameCallback(
          (timeStamp) => Navigator.popUntil(context, (route) => route.isFirst));
    })
    ..on<ParticipantEvent>((event) {
      // print('Participant event');
      _sortParticipants();
    })
    ..on<RoomRecordingStatusChanged>((event) {
      context.showRecordingStatusChangedDialog(event.activeRecording);
    })
    ..on<RoomAttemptReconnectEvent>((event) {
      print(
          'Attempting to reconnect ${event.attempt}/${event.maxAttemptsRetry}, '
          '(${event.nextRetryDelaysInMs}ms delay until next attempt)');
    })
    ..on<LocalTrackPublishedEvent>((_) => _sortParticipants())
    ..on<LocalTrackUnpublishedEvent>((_) => _sortParticipants())
    // ignore: unnecessary_set_literal
    ..on<TrackSubscribedEvent>((event) {
      _sortParticipants();
      //  _trackSubscribed(event);
    })
    ..on<TrackUnsubscribedEvent>((event) {
      _sortParticipants();
      //   _trackUnsubscribed(event);
    })
    ..on<ParticipantNameUpdatedEvent>((event) {
      _sortParticipants();
    })
    ..on<DataReceivedEvent>((event) {
      try {
        _receivedHandRaiseRequest(utf8.decode(event.data));
        updateParticipantStatusFromMetadata(utf8.decode(event.data));
      } catch (_) {
        print('Failed to decode: $_');
      }
    })
    ..on<ParticipantConnectedEvent>((event) {
      _addNewParticipantStatus(event);
    })
    ..on<ParticipantDisconnectedEvent>((event) {
      removeParticipantStatus(event);
    })
    ..on<AudioPlaybackStatusChanged>((event) async {
      if (!widget.room.canPlaybackAudio) {
        bool? yesno = await context.showPlayAudioManuallyDialog();
        if (yesno == true) {
          await widget.room.startAudio();
        }
      }
    });

  void _askPublish() async {
    final result = await context.showPublishDialog();
    if (result != true) return;
    try {
      await widget.room.localParticipant?.setCameraEnabled(true);
    } catch (error) {
      print('could not publish video: $error');
      await context.showErrorDialog(error);
    }
    try {
      await widget.room.localParticipant?.setMicrophoneEnabled(true);
    } catch (error) {
      print('could not publish audio: $error');
      await context.showErrorDialog(error);
    }
  }

  void _onRoomDidUpdate() {
    _sortParticipants();
  }

  void _initializeParticipantStatuses() {
    participantsManager.clear();

    // Initialize status for the local participant
    final localParticipant = widget.room.localParticipant;
    if (localParticipant != null) {
      final localStatus = ParticipantStatus(
        identity: localParticipant.identity,
        isAudioEnable: localParticipantRole == Role.admin.toString(),
        isVideoEnable: localParticipantRole == Role.admin.toString(),
        isTalkToHostEnable: localParticipantRole == Role.admin.toString(),
      );
      participantsManager.add(localStatus);
    }

    // Initialize status for remote participants
    for (var participant in widget.room.remoteParticipants.values) {
      final remoteParticipantRole = _getRoleFromMetadata(participant.metadata);
      final participantStatus = ParticipantStatus(
        identity: participant.identity,
        isAudioEnable: remoteParticipantRole == Role.admin.toString(),
        isVideoEnable: remoteParticipantRole == Role.admin.toString(),
        isTalkToHostEnable: remoteParticipantRole == Role.admin.toString(),
        // Other default values (e.g., isHandRaised, isTalkToHostEnable) are already false by default
      );
      participantsManager.add(participantStatus);
    }
  }

  void _addNewParticipantStatus(ParticipantConnectedEvent event) {
    setState(() {
      print('Participant connected: ${event.participant.identity}');
      final isNew = participantsManager
          .every((element) => element.identity != event.participant.identity);

      if (isNew) {
        print('new Participant connected: ${event.participant.identity}');
        final newParticipantStatus = ParticipantStatus(
          identity: event.participant.identity,
          isAudioEnable: false,
          isVideoEnable: false,
          isHandRaised: false,
          isTalkToHostEnable: false,
          handRaisedTimeStamp: 0,
          // Set other default values for the new participant status
        );

        participantsManager.add(newParticipantStatus);
        sendParticipantsStatus(participantsManager);
      }
    });
  }

  void removeParticipantStatus(ParticipantDisconnectedEvent event) {
    setState(() {
      participantsManager.removeWhere(
          (status) => status.identity == event.participant.identity);
    });
  }

  Future<void> sendParticipantsStatus(
      List<ParticipantStatus> participantsStatus) async {
    // Convert the list of ParticipantStatus objects to a list of JSON objects
    final participantsJsonList =
        participantsStatus.map((status) => status.toJson()).toList();

    // Wrap the list in an object with additional keys
    final metadata = jsonEncode({
      'type':
          'participantsStatusUpdate', // Example key to describe the type of metadata
      'timestamp':
          DateTime.now().toIso8601String(), // Example key to add a timestamp
      'participants':
          participantsJsonList, // The actual list of participant statuses
    });

    await widget.room.localParticipant?.publishData(utf8.encode(metadata));
    // Send the entire metadata object at once

    setState(() {
      participantsManager = participantsStatus;
      _sortParticipants();
    });
  }

  void updateParticipantStatusFromMetadata(String metadata) {
    // Parse the received metadata
    final decodedMetadata = jsonDecode(metadata);

    if (decodedMetadata['type'] == 'participantsStatusUpdate') {
      // Extract the list of participant status data from the 'participants' key
      final participantsStatusList = (decodedMetadata['participants'] as List)
          .map((item) => ParticipantStatus(
                identity: item['identity'],
                isAudioEnable: item['isAudioEnable'],
                isVideoEnable: item['isVideoEnable'],
                isHandRaised: item['isHandRaised'],
                isTalkToHostEnable: item['isTalkToHostEnable'],
                handRaisedTimeStamp: item['handRaisedTimeStamp'],
              ))
          .toList();

      // Update the state with the new participants status list
      setState(() {
        participantsManager = participantsStatusList;
        participantsStatusList.forEach((element) {
          if (element.identity == widget.room.localParticipant?.identity) {
            _isHandleRaiseHand = element.isHandRaised;
          }
        });
        _sortParticipants();
      });
    }
  }

  void _receivedHandRaiseRequest(String metadata) {
    final decodedMetadata = jsonDecode(metadata);

    if (decodedMetadata['handraise'] != null) {
      _handleRaiseHandFromParticipant(
        decodedMetadata['identity'],
        decodedMetadata['handraise'],
      );
    }
  }

  void _handleRaiseHandFromParticipant(String identity, bool isHandRaised) {
    setState(() {
      // Find the participant status by identity
      final participantStatus = _getParticipantStatus(identity);
      final participant = participantTracks
          .firstWhere((track) => track.participant.identity == identity)
          .participant;

      // Update the handraise status
      participantStatus.isHandRaised = isHandRaised;

      // If the hand is being raised, store the current timestamp
      if (isHandRaised) {
        participantStatus.handRaisedTimeStamp =
            DateTime.now().millisecondsSinceEpoch;
      }

      // Handle the local participant's hand raise status
      if (widget.room.localParticipant?.identity == identity) {
        _isHandleRaiseHand = isHandRaised;
      }

      // Show notification if the hand is raised and the local participant is an admin
      if (isHandRaised && localParticipantRole == Role.admin.toString()) {
        _showHandRaiseNotification(context, participant);
      }
      _sortParticipants();
    });
  }

  _getParticipantStatus(String identity) {
    return participantsManager?.firstWhere(
        (status) => status.identity == identity,
        orElse: () => ParticipantStatus(
              identity: identity,
              isAudioEnable: false,
              isVideoEnable: false,
              isHandRaised: false,
              isTalkToHostEnable: false,
              handRaisedTimeStamp: 0,
            ));
  }

  void _sortParticipants() {
    List<ParticipantTrack> userMediaTracks = [];
    List<ParticipantTrack> screenTracks = [];
    final localParticipant = widget.room.localParticipant;

    bool isLocalHost = localParticipant != null &&
        localParticipantRole == Role.admin.toString();

    for (var participant in widget.room.remoteParticipants.values) {
      // Find the corresponding ParticipantStatus

      final participantStatus = _getParticipantStatus(participant.identity);
      final isRemoteParticipantHost =
          _getRoleFromMetadata(participant.metadata) == Role.admin.toString();

      final isVideo = participantStatus.isVideoEnable;
      final isAudio = participantStatus.isAudioEnable;
      final isTalkToHostEnable = participantStatus.isTalkToHostEnable;

      print(
          'rohit _sortParticipants 123 for  participantStatus${participantStatus.toJson()}');

      // print('Starting _sortParticipants 123 for  participantStatus${ participant.audioTrackPublications.n}');
      final shouldAudioSubscribe =
          (isTalkToHostEnable && (isLocalHost || isRemoteParticipantHost)) ||
              (isAudio &&
                  !((isLocalHost || isRemoteParticipantHost) &&
                      !isTalkToHostEnable));

      if (shouldAudioSubscribe) {
        participant.audioTrackPublications?.forEach((element) {
          element.subscribe();
        });
      } else {
        participant.audioTrackPublications?.forEach((element) {
          element.unsubscribe();
        });
      }

      if (participant.isScreenShareEnabled()) {
        screenTracks.add(ParticipantTrack(
          participant: participant,
          type: ParticipantTrackType.kScreenShare,
        ));
        setState(() {
          _isScreenShareMode = true;
        });
      } else if (isVideo || isLocalHost || isRemoteParticipantHost) {
        userMediaTracks.add(ParticipantTrack(participant: participant));
      }
    }

    userMediaTracks.sort((a, b) {
      return a.participant.joinedAt.millisecondsSinceEpoch -
          b.participant.joinedAt.millisecondsSinceEpoch;
    });

    final localParticipantTracks =
        widget.room.localParticipant?.videoTrackPublications;

    if (localParticipantTracks != null) {
      for (var t in localParticipantTracks) {
        if (t.isScreenShare) {
          if (lkPlatformIs(PlatformType.iOS)) {
            if (!_flagStartedReplayKit) {
              _flagStartedReplayKit = true;
              ReplayKitChannel.startReplayKit();
            }
          }
          screenTracks.add(ParticipantTrack(
            participant: widget.room.localParticipant!,
            type: ParticipantTrackType.kScreenShare,
          ));
        } else {
          if (lkPlatformIs(PlatformType.iOS)) {
            if (_flagStartedReplayKit) {
              _flagStartedReplayKit = false;
              ReplayKitChannel.closeReplayKit();
            }
          }
        }
      }
    }

    // Add the local participant to the user media tracks list
    if (localParticipant != null) {
      userMediaTracks.add(ParticipantTrack(participant: localParticipant));
    }

    setState(() {
      participantTracks = [...screenTracks, ...userMediaTracks];
    });
  }

  void _toggleMuteAll(bool muteAll) {
    setState(() {
      _muteAll = muteAll;
      print('rohit muteAll ${muteAll}');

      // Update the participantsManager with new participants
      for (var participantStatus in participantsManager) {
        if (participantStatus.identity !=
            widget.room.localParticipant?.identity) {
          participantStatus.isTalkToHostEnable = !muteAll;
        }
        print('rohitg participantStatus ${participantStatus.toJson()}');
      }

      // Trigger the callback with the updated list
      sendParticipantsStatus(participantsManager);
    });
  }

  String _getRoleFromMetadata(String? metadata) {
    if (metadata != null && metadata.isNotEmpty) {
      final decodedMetadata = jsonDecode(metadata);
      return decodedMetadata['role'] ?? '';
    }
    return '';
  }

  List<ParticipantTrack> _filterParticipants(String searchQuery) {
    final localParticipant = widget.room.localParticipant;

    // Filter participants based on the search query
    final filteredParticipants = participantTracks.where((track) {
      final participantName = track.participant.name.toLowerCase();
      return participantName.contains(searchQuery.toLowerCase());
    }).toList();

    // Move the local participant to the top of the list
    if (localParticipant != null) {
      filteredParticipants
          .removeWhere((track) => track.participant == localParticipant);
      filteredParticipants.insert(
          0, ParticipantTrack(participant: localParticipant));
    }

    return filteredParticipants;
  }

  void _allowSpeak(Participant participant) {
    setState(() {
      // Find the corresponding participantsManager by participant identity
      final participantStatus = _getParticipantStatus(participant.identity);

      // Update the isTalkToHostEnable field to true
      participantStatus.isTalkToHostEnable = true;
      participantStatus.isHandRaised = false;
      sendParticipantsStatus(participantsManager);
    });
  }

  void _denySpeak(Participant participant) {
    setState(() {
      // Find the corresponding participantsManager by participant identity
      final participantStatus = _getParticipantStatus(participant.identity);

      // Update the isTalkToHostEnable field to false
      participantStatus.isTalkToHostEnable = false;
      participantStatus.isHandRaised = false;
      sendParticipantsStatus(participantsManager);
    });
  }

  void _toggleRaiseHand(Participant participant, bool isHandRaised) async {
    // Create the metadata with the updated hand raise status
    final handRaiseData = jsonEncode(
        {'identity': participant?.identity, 'handraise': isHandRaised});

    // Publish the data to the room so that other participants can receive it
    await widget.room.localParticipant?.publishData(
      utf8.encode(handRaiseData),
    );

    _handleRaiseHandFromParticipant(participant.identity, isHandRaised);
  }

  void _handleToggleRaiseHand(bool isHandRaised) async {
    _toggleRaiseHand(widget.room.localParticipant as Participant, isHandRaised);
  }

  Future<void> _copyInviteLinkToClipboard(BuildContext context) async {
    CopyInviteLinkDialog.show(context, widget.room.name!);
  }

  void _showHandRaiseNotification(
      BuildContext context, Participant participant) {
    HandRaiseNotification.show(context, participant, _allowSpeak, _denySpeak);
  }

  Future<void> _showParticipantSelectionDialog(context) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      _scaffoldKey.currentState?.openEndDrawer();
    }
  }

  void _openEndDrawer() {
    //_initializeAllowedToTalk();
    _scaffoldKey.currentState?.openEndDrawer();
  }

  // Toggle between view modes
  void _toggleViewMode() {
    setState(() {
      _isScreenShareMode = !_isScreenShareMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: Stack(
          children: [
            // Conditional layout based on view mode
            if (participantTracks.any((track) =>
                    track.type == ParticipantTrackType.kScreenShare) &&
                _isScreenShareMode)
              Positioned.fill(
                child: Stack(
                  children: [
                    // Display the screen share participant prominently
                    Positioned.fill(
                      child: ParticipantWidget.widgetFor(
                        participantTracks.firstWhere((track) => track
                            .participant
                            .isScreenShareEnabled()), // Assuming you have a way to find the screen share track
                        showStatsLayer: false,
                      ),
                    ),
                    // Display other participants in a side panel
                  ],
                ),
              )
            else
              ParticipantGridView(
                participantTracks: participantTracks,
              ),
            if (widget.room.localParticipant != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: ControlsWidget(
                    _toggleMuteAll,
                    _handleToggleRaiseHand,
                    _muteAll,
                    _isHandleRaiseHand,
                    localParticipantRole,
                    widget.room,
                    widget.room.localParticipant!,
                    participantsManager,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButtonBar(
        localParticipantRole: localParticipantRole!,
        isMobile: isMobile,
        context: context,
        copyInviteLinkToClipboard: _copyInviteLinkToClipboard,
        showParticipantSelectionDialog: _showParticipantSelectionDialog,
        openEndDrawer: _openEndDrawer,
        isScreenShare: participantTracks
            .any((track) => track.type == ParticipantTrackType.kScreenShare),
        toggleViewMode: _toggleViewMode,
        isScreenShareMode: _isScreenShareMode,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      endDrawer: ParticipantDrawer(
        searchQuery: searchQuery,
        onSearchChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        filterParticipants: _filterParticipants,
        localParticipant: widget.room.localParticipant,
        onParticipantsStatusChanged: sendParticipantsStatus,
        participantsStatusList: participantsManager,
      ),
    );
  }
}
