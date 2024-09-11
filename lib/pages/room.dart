import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/method_channels/replay_kit_channel.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/pages/login.dart';
import 'package:video_meeting_room/pages/room-widget/AdminApprovalDialog.dart';
import 'package:video_meeting_room/pages/room-widget/CopyInviteLinkDialog.dart';
import 'package:video_meeting_room/pages/room-widget/FloatingActionButtonBar.dart';
import 'package:video_meeting_room/pages/room-widget/HandRaiseNotification.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantDrawer.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantGridView.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantListView.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantSelectionDialog.dart';
import 'package:video_meeting_room/services/approval_service.dart';
import 'package:video_meeting_room/services/room_data_manage_service.dart';

import 'package:video_meeting_room/widgets/room-header.dart';
import 'package:video_meeting_room/widgets/thank_you.dart';

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
  bool _isScreenShareModeOnce = false; // State to toggle view mode
  final ApprovalService _approvalService = GetIt.instance<ApprovalService>();
  final RoomDataManageService _roomDataManageService =
      GetIt.instance<RoomDataManageService>();
  final Map<String, BuildContext> _dialogContexts =
      {}; // Map to store dialog contexts
  bool _isRunning = true; // Control flag for the loop
  int _currentPage = 0;
  final int _participantsPerPage = 6;
  @override
  void initState() {
    super.initState();
    widget.room.addListener(_onRoomDidUpdate);
    _setUpListeners();
    // Set up role for the local participant
    _initializeLocalParticipantRole();
    _sortParticipants();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

    //sendParticipant call every 5 second
    //exchangeData();
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
    _isRunning = false;
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
        if (localParticipantRole == Role.admin.toString()) {
          _checkForPendingRequests();
        }
      });
    }
  }

  void _setUpListeners() => _listener
    ..on<RoomDisconnectedEvent>((event) async {
      if (event.reason != null) {
        print('Room disconnected: reason => ${event.reason}');
      }
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) =>
          handleRoomDisconnected(context, widget.room.localParticipant!));
    })
    ..on<ParticipantEvent>((event) {
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

  _updateRoomData(participantsManager) async {
    final roomSID = await widget.room.getSid();
    //remove duplicate cate participant based on identity
    final uniqueParticipants = participantsManager
        .map((e) => e.toJson())
        .toSet()
        .map((e) => ParticipantStatus.fromJson(e))
        .toList();
    _roomDataManageService.setLatestData(roomSID, uniqueParticipants);
  }

  void handleRoomDisconnected(BuildContext context, Participant participant) {
    if (localParticipantRole == Role.admin.toString()) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ThankYouWidget()),
      );
    }
  }

  void _onRoomDidUpdate() {
    _sortParticipants();
  }

  Future<void> _initializeParticipantStatuses() async {
    participantsManager.clear();

    // Initialize status for the local participant
    final localParticipant = widget.room.localParticipant;
    if (localParticipant != null) {
      final localStatus = ParticipantStatus(
        identity: localParticipant.identity,
        isAudioEnable: localParticipantRole == Role.admin.toString(),
        isVideoEnable: localParticipantRole == Role.admin.toString(),
        isTalkToHostEnable: localParticipantRole == Role.admin.toString(),
        role: localParticipantRole!,
      );

      // Initialize status for remote participants

      // get Room Data from server
      final roomSID = await widget.room.getSid();
      final data = await _roomDataManageService.getLatestData(roomSID);
      final List<ParticipantStatus> participantsStatusList;
      if (data != null) {
        final participantsStatusList = (data as List)
            .map((item) => ParticipantStatus(
                  identity: item['identity'],
                  isAudioEnable: item['isAudioEnable'],
                  isVideoEnable: item['isVideoEnable'],
                  isHandRaised: item['isHandRaised'],
                  isTalkToHostEnable: item['isTalkToHostEnable'],
                  handRaisedTimeStamp: item['handRaisedTimeStamp'],
                  role: item['role'],
                ))
            .toList();
        setState(() {
          participantsManager.addAll(participantsStatusList);
        });
      }

      setState(() {
        participantsManager.add(localStatus);

        _updateRoomData(participantsManager);
        _sortParticipants();
      });
    }
  }

  void _addNewParticipantStatus(ParticipantConnectedEvent event) {
    setState(() {
      final isNew = participantsManager
          .every((element) => element.identity != event.participant.identity);

      final role = _getRoleFromMetadata(event.participant.metadata);
      final isAdmin = role == Role.admin.toString();
      if (isNew) {
        final newParticipantStatus = ParticipantStatus(
          identity: event.participant.identity,
          isAudioEnable: isAdmin,
          isVideoEnable: isAdmin,
          isHandRaised: false,
          isTalkToHostEnable: isAdmin,
          handRaisedTimeStamp: 0,
          role: role,
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

  Future<void> _checkForPendingRequests() async {
    while (_isRunning) {
      try {
        final requests =
            await _approvalService.fetchPendingRequests(widget.room.name!);
        final currentRequestIds =
            requests.map((request) => request['id'].toString()).toSet();

        // Close dialogs for requests not found
        _dialogContexts.keys.toList().forEach((requestId) {
          if (!currentRequestIds.contains(requestId)) {
            _closeDialog(requestId);
          }
        });

        // Close all dialogs if no pending requests
        if (requests.isEmpty && _dialogContexts.isNotEmpty) {
          _dialogContexts.keys.toList().forEach((requestId) {
            _closeDialog(requestId);
          });
        }

        // Check for new requests
        for (var request in requests) {
          final requestId = request['id'].toString();
          if (!_dialogContexts.containsKey(requestId)) {
            _showApprovalDialog(request);
          }
        }
      } catch (error) {
        // print('Error fetching pending requests: $error');
      }
      await Future.delayed(
          const Duration(seconds: 5)); // Check every 10 seconds
    }
  }

  void _closeDialog(String requestId) {
    final dialogContext = _dialogContexts[requestId];
    if (dialogContext != null) {
      Navigator.of(dialogContext).pop(); // Close the dialog
      setState(() {
        _dialogContexts.remove(requestId); // Remove the context from the map
      });
    }
  }

  void _showApprovalDialog(dynamic request) {
    final requestId = request['id'].toString(); // Use request ID as the key

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Store the context with the dialog's unique ID
        _dialogContexts[requestId] = context;

        return AdminApprovalDialog(
          participantName: request['participantName'],
          roomName: request['roomName'],
          onDecision: (approved) async {
            await _approvalService.approveRequest(request['id'], approved);
            _closeDialog(requestId); // Close this specific dialog
          },
        );
      },
    ).then((_) {
      // Clean up after the dialog is closed
      _dialogContexts.remove(requestId);
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

    await widget.room.localParticipant
        ?.publishData(utf8.encode(metadata), reliable: true);
    // Send the entire metadata object at once

    setState(() {
      participantsManager = participantsStatus;
      _updateRoomData(participantsManager);
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
                role: item['role'],
              ))
          .toList();

      // Update the state with the new participants status list
      setState(() {
        participantsManager = participantsStatusList;
        for (var element in participantsStatusList) {
          if (element.identity == widget.room.localParticipant?.identity) {
            _isHandleRaiseHand = element.isHandRaised;
          }
        }
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

      if(!isHandRaised && localParticipantRole == Role.admin.toString()){
        participant.handRaised = false;
      }


      _sortParticipants();
    });
  }

  _getParticipantStatus(String identity) {
    final list =
        participantsManager.firstWhere((status) => status.identity == identity,
            orElse: () => ParticipantStatus(
                  identity: '',
                  isAudioEnable: false,
                  isVideoEnable: false,
                  isHandRaised: false,
                  isTalkToHostEnable: false,
                  handRaisedTimeStamp: 0,
                  role: '',
                ));

    return list;
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
      if (participantStatus.identity.isEmpty) {
        continue;
      }
      final isRemoteParticipantHost =
          _getRoleFromMetadata(participant.metadata) == Role.admin.toString();

      final isVideo = participantStatus.isVideoEnable;
      final isAudio = participantStatus.isAudioEnable;
      final isTalkToHostEnable = participantStatus.isTalkToHostEnable;
      if (isRemoteParticipantHost) {
        print('isRemoteParticipantHost ${participantStatus.toJson()}');
      }
      // print('Starting  for  participantStatus${ participantStatus.toJson()}');
      // print('Starting _sortParticipants 123 for  participantStatus${ participant.audioTrackPublications.n}');
      final shouldAudioSubscribe =
          (isTalkToHostEnable && (isLocalHost || isRemoteParticipantHost)) ||
              (isAudio &&
                  !((isLocalHost || isRemoteParticipantHost) &&
                      !isTalkToHostEnable));

      if (shouldAudioSubscribe) {
        participant.audioTrackPublications.forEach((element) {
          element.subscribe();
        });
      } else {
        participant.audioTrackPublications.forEach((element) {
          if (!(isLocalHost && isRemoteParticipantHost)) {
            element.unsubscribe();
          }
        });
      }

      if (participant.isScreenShareEnabled()) {
        screenTracks.add(ParticipantTrack(
          participant: participant,
          type: ParticipantTrackType.kScreenShare,
        ));
        if (_isScreenShareModeOnce == false) {
          setState(() {
            _isScreenShareMode = true;
            _isScreenShareModeOnce = true;
          });
        }
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

  void _nextPage() {
    setState(() {
      if ((_currentPage + 1) * _participantsPerPage <
          participantTracks.length) {
        _currentPage++;
      }
    });
  }

  void _previousPage() {
    setState(() {
      if (_currentPage > 0) {
        _currentPage--;
      }
    });
  }

  void _toggleMuteAll(bool muteAll) {
    setState(() {
      _muteAll = muteAll;
      // Update the participantsManager with new participants
      final participants = participantsManager.where((participantStatus) {
        return participantStatus.role != Role.admin.toString();
      });
      for (var participantStatus in participants) {
        participantStatus.isTalkToHostEnable = !muteAll;
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
        {'identity': participant.identity, 'handraise': isHandRaised});

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
    //showCopyInviteDialog(context);
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
    print('rohit openEndDrawer');
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
    final bool isparticipantScreenShared = participantTracks
        .any((track) => track.type == ParticipantTrackType.kScreenShare);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFF1F2A38),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.room.localParticipant != null)
              RoomHeader(
                  room: widget.room,
                  participantsStatusList: participantsManager,
                  onToggleRaiseHand: _handleToggleRaiseHand,
                  isHandRaisedStatusChanged: _isHandleRaiseHand,
                  isAdmin: localParticipantRole == Role.admin.toString()),

            // Expanded Grid View (between header and footer)
            Expanded(
                child: Padding(
              padding: const EdgeInsets.all(8.0), // Add padding
              child: participantTracks.any((track) =>
                          track.type == ParticipantTrackType.kScreenShare) &&
                      _isScreenShareMode
                  ? Stack(
                      children: [
                        // Display the screen share participant prominently
                        Positioned.fill(
                            child: ParticipantGridView(
                          participantTracks: participantTracks.where((track) {
                            return track.type == ParticipantTrackType.kScreenShare;
                          }).toList(),  


                        )),
                        // Display other participants in a side panel (if needed)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 200,
                            color: Colors.black.withOpacity(0.5),
                            child: ParticipantListView(
                              participantTracks: participantTracks.where((track) {
                                return track.type != ParticipantTrackType.kScreenShare;
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ParticipantGridView(
                      participantTracks: participantTracks,
                    ),
            )),

            // Control Footer
            ControlsWidget(
              _toggleMuteAll,
              _handleToggleRaiseHand,
              _openEndDrawer,
              () => _copyInviteLinkToClipboard(context),
              _muteAll,
              _isHandleRaiseHand,
              localParticipantRole,
              widget.room,
              widget.room.localParticipant!,
              participantsManager,
            ),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButtonBar(
      //   localParticipantRole: localParticipantRole!,
      //   isMobile: isMobile,
      //   context: context,
      //   copyInviteLinkToClipboard: _copyInviteLinkToClipboard,
      //   showParticipantSelectionDialog: _showParticipantSelectionDialog,
      //   openEndDrawer: _openEndDrawer,
      //   isScreenShare: participantTracks
      //       .any((track) => track.type == ParticipantTrackType.kScreenShare),
      //   toggleViewMode: _toggleViewMode,
      //   isScreenShareMode: _isScreenShareMode,
      // ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // endDrawer: ParticipantDrawerNew(),
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
