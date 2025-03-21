import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/method_channels/replay_kit_channel.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/pages/login.dart';
import 'package:video_meeting_room/pages/room-widget/AdminApprovalDialog.dart';
import 'package:video_meeting_room/pages/room-widget/CopyInviteLinkDialog.dart';
import 'package:video_meeting_room/pages/room-widget/HandRaiseNotification.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantDrawer.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantGridView.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantListView.dart';
import 'package:video_meeting_room/pages/room-widget/NewParticipantDialog.dart';
import 'package:video_meeting_room/services/approval_service.dart';
import 'package:video_meeting_room/services/room_data_manage_service.dart';

import 'package:video_meeting_room/widgets/room-header.dart';
import 'package:video_meeting_room/widgets/thank_you.dart';

import '../exts.dart';
import '../utils.dart';
import '../widgets/controls.dart';
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
  final ApprovalService _approvalService = GetIt.instance<ApprovalService>();
  final RoomDataManageService _roomDataManageService =
      GetIt.instance<RoomDataManageService>();
  final Map<String, BuildContext> _dialogContexts =
      {}; // Map to store dialog contexts
  bool _isRunning = true; // Control flag for the loop
  int _currentPage = 0;
  final int _participantsPerPage = 6;
  bool isParticipantListVisible = false; // Track sidebar visibility
  @override
  void initState() {
    super.initState();

    html.window.addEventListener('beforeunload', (event)  async {
      final roomId = await widget.room.getSid();
      // Get local participant identity
      final localParticipant = widget.room.localParticipant;
      final identity = localParticipant?.identity;
      final roomName = widget.room.name!;
      // Perform your action here, e.g., cleanup or save state
      print("Tab closing or reloading...");
      _roomDataManageService.removeParticipant(roomId,roomName,identity);
      widget.room.disconnect();
      // To display a confirmation dialog (optional):
      // event.returnValue = 'Are you sure you want to leave?';
    });
    widget.room.addListener(_onRoomDidUpdate);
    _setUpListeners();
    // Set up role for the local participant
    _initializeLocalParticipantRole();
    _sortParticipants('initState');
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
  // Capture the window close event

  @override
  Future<void> dispose() async {
    (() async {
      if (lkPlatformIs(PlatformType.iOS)) {
        ReplayKitChannel.closeReplayKit();
      }
      print('RoomPage dispose');
      widget.room.removeListener(_onRoomDidUpdate);
      await _listener.dispose();
      await widget.room.dispose();
    })();
    onWindowShouldClose = null;
    _isRunning = false;
    final roomID = await widget.room.getSid();
    // Get local participant identity
    final localParticipant = widget.room.localParticipant;
    final identity = localParticipant?.identity;
    final roomName =  widget.room.name!;
     _roomDataManageService.removeParticipant(roomID,roomName,identity);
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
      if (localParticipantRole == Role.participant.toString()) {
        Future.delayed(Duration.zero, () {
          if (mounted) {
            NewParticipantDialog.show(context, localParticipant.name);
          }
        });
      }
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
       _sortParticipants('ParticipantEvent');
    })
    ..on<RoomRecordingStatusChanged>((event) {
      context.showRecordingStatusChangedDialog(event.activeRecording);
    })
    ..on<RoomAttemptReconnectEvent>((event) {
      print(
          'Attempting to reconnect ${event.attempt}/${event.maxAttemptsRetry}, '
          '(${event.nextRetryDelaysInMs}ms delay until next attempt)');
    })
     ..on<LocalTrackPublishedEvent>((_) => _sortParticipants('LocalTrackPublishedEvent'))
     ..on<LocalTrackUnpublishedEvent>((_) => _sortParticipants('LocalTrackUnpublishedEvent'))
    // // ignore: unnecessary_set_literal
    ..on<TrackSubscribedEvent>((event) {
      _sortParticipants('TrackSubscribedEvent');
        //_trackSubscribed(event);
    })
    ..on<TrackUnsubscribedEvent>((event) {
      _sortParticipants('TrackUnsubscribedEvent');
      //   _trackUnsubscribed(event);
    })
    // ..on<ParticipantNameUpdatedEvent>((event) {
    //   _sortParticipants();
    // })
  
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
    ..on<ParticipantDisconnectedEvent>((event) async {
      removeParticipantStatus(event);
      _sortParticipants('ParticipantDisconnectedEvent');
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
    final roomName =  widget.room.name!;

  // Use a Set to track unique identities
  final Set<String> seenIdentities = {};

  // Remove duplicates based on 'identity'
  final uniqueParticipants = participantsManager
      .where((participant) => seenIdentities.add(participant.identity)) // Add returns false if already in set
      .map((e) => ParticipantStatus.fromJson(e.toJson()))
      .toList();

  _roomDataManageService.setLatestData(roomSID, roomName, uniqueParticipants);

  // Print debug information
  print('rohit _updateRoomData $roomSID');
  print(jsonEncode(uniqueParticipants));
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
    setState(() {
      //print('rohit _onRoomDidUpdate');
      _sortUserMediaTracks(participantTracks);
    });
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

      final roomName =  widget.room.name!;

      final data = await _roomDataManageService.getLatestData(roomSID,roomName);
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
        _sortParticipants('initializeParticipantStatuses');
      });
    }
  }

  Future<void> _updateParticipantmanagerFromDB() async{
    final roomId = await widget.room.getSid();
    final roomName = await widget.room.name!;

    final data = await _roomDataManageService.getLatestData(roomId,roomName);
    setState(() {
      participantsManager.clear();
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
    });
  }

  void _addNewParticipantStatus(ParticipantConnectedEvent event) async{
    //final data = await _roomDataManageService.getLatestData(roomSID,roomName);
    await _updateParticipantmanagerFromDB();
    setState(() {
      final isNew = participantsManager
          .every((element) => element.identity != event.participant.identity);
      // print('rohit isNew $isNew');
      final role = _getRoleFromMetadata(event.participant.metadata);
      final isAdmin = role == Role.admin.toString();
      //final isAdmin = role == Role.admin.toString() || event.participant.identity == "streamer";
      if (isNew) {
        final newParticipantStatus = ParticipantStatus(
          identity: event.participant.identity,
          isAudioEnable: isAdmin,
          isVideoEnable: isAdmin,
          isHandRaised: false,
          isTalkToHostEnable: isAdmin,
          handRaisedTimeStamp: 0,
          role: role.isEmpty ? Role.participant.toString() : role,
          //role: !isAdmin ? Role.participant.toString() : Role.admin.toString(),
          // Set other default values for the new participant status
        );

        print('new Join');
        print(jsonEncode(newParticipantStatus));
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
      //_initializeParticipantStatuses();
      _sortParticipants('sendParticipantsStatus');
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
        _sortParticipants('updateParticipantStatusFromMetadata');
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
      _sortParticipants('handleRaiseHandFromParticipant');
    });
  }

  _getParticipantStatus(String identity) {
    final list =
        participantsManager.firstWhere((status) => status.identity == identity,
            orElse: () => ParticipantStatus(
                  identity: identity,
                  isAudioEnable: false,
                  isVideoEnable: false,
                  isHandRaised: false,
                  isTalkToHostEnable: false,
                  handRaisedTimeStamp: 0,
                  role: Role.participant.toString(),
                ));

    return list;
  }

  void _sortParticipants(String from) {
    List<ParticipantTrack> userMediaTracks = [];
    List<ParticipantTrack> screenTracks = [];
    final localParticipant = widget.room.localParticipant;

    bool isLocalHost = localParticipant != null &&
        localParticipantRole == Role.admin.toString();

    for (var participant in widget.room.remoteParticipants.values) {
      // Find the corresponding ParticipantStatus
      final participantStatus = _getParticipantStatus(participant.identity);
      final data = jsonEncode(participantStatus);
      print('rohit sort $data');
      if (participantStatus.identity.isEmpty) {
        continue;
      }

      final isRemoteParticipantHost =
          _getRoleFromMetadata(participant.metadata) == Role.admin.toString();

      final isVideo = participantStatus.isVideoEnable;
      final isAudio = participantStatus.isAudioEnable;
      final isTalkToHostEnable = participantStatus.isTalkToHostEnable;
      //final isStreamer = participant.identity == "streamer";
      final shouldAudioSubscribe =
          (isTalkToHostEnable && (isLocalHost || isRemoteParticipantHost)) ||
          //(isTalkToHostEnable && (isLocalHost || isRemoteParticipantHost || isStreamer) ) ||
              (isAudio &&
                  !((isLocalHost || isRemoteParticipantHost) &&
                      !isTalkToHostEnable));
      final name = participant.identity;
        print('check name $name is  shouldAudioSubscribe  $shouldAudioSubscribe');

      if (shouldAudioSubscribe) {
        final totalaudioTrackPublications =
            participant.audioTrackPublications.length;
        print('rohit audio total $totalaudioTrackPublications');
        participant.audioTrackPublications.forEach((element) {
          print('rohit audio subscribe $jsonEncode(element)');
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
        print('rohit screen share $participant');
        screenTracks.add(ParticipantTrack(
          participant: participant,
          type: ParticipantTrackType.kScreenShare,
        ));
      } else if (isVideo || isLocalHost || isRemoteParticipantHost) {
      //  print('rohit isVideo $participant');
        userMediaTracks.add(ParticipantTrack(participant: participant));
      }
    }

    // Sort the user media tracks
    _sortUserMediaTracks(userMediaTracks);

    // Add the local participant to the user media tracks
   // _addLocalParticipant(userMediaTracks);

    // Update the state with the combined participant tracks
    setState(() {
      participantTracks = [...screenTracks, ...userMediaTracks];
    });
  }

  void _sortUserMediaTracks(List<ParticipantTrack> userMediaTracks) {
    userMediaTracks.sort((a, b) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final fiveSecondsAgo = now - 10000; // 10000 milliseconds = 10 seconds

      // lastSpokeAt in milliseconds, default to 0 if null
      final aSpokeAt = a.participant.lastSpokeAt?.millisecondsSinceEpoch ?? 0;
      final bSpokeAt = b.participant.lastSpokeAt?.millisecondsSinceEpoch ?? 0;

      // Sort by whether they spoke within the last 10 seconds
      final aSpokeRecently = aSpokeAt > fiveSecondsAgo;
      final bSpokeRecently = bSpokeAt > fiveSecondsAgo;

      if (aSpokeRecently != bSpokeRecently) {
        return aSpokeRecently ? -1 : 1;
      }

      // Sort by video status if spoken within last 10 seconds is the same
      if (a.participant.hasVideo != b.participant.hasVideo) {
        return a.participant.hasVideo ? -1 : 1;
      }

      // Sort by joinedAt if both spoke recently or not recently
      return a.participant.joinedAt.millisecondsSinceEpoch -
          b.participant.joinedAt.millisecondsSinceEpoch;
    });

    userMediaTracks.sort((a, b) {
      final statusA = _getParticipantStatus(a.participant.identity);
      final statusB = _getParticipantStatus(b.participant.identity);

      // Check if both participants have raised their hands
      final isHandRaisedA = statusA?.isHandRaised ?? false;
      final isHandRaisedB = statusB?.isHandRaised ?? false;

      if (!isHandRaisedA && !isHandRaisedB) {
        // Neither have raised hands, keep them in the same order
        return 0;
      } else if (!isHandRaisedA) {
        // A hasn't raised hand, so move A down
        return 1;
      } else if (!isHandRaisedB) {
        // B hasn't raised hand, so move B down
        return -1;
      }

      // If both have raised hands, sort by handRaisedTimeStamp
      // Earlier timestamps (raised first) should come first
      return (statusA?.handRaisedTimeStamp ?? 0) -
          (statusB?.handRaisedTimeStamp ?? 0);
    });

_addLocalParticipant(userMediaTracks );
subscribeToFirstToFourthParticipants(userMediaTracks);
    
  }
void _addLocalParticipant(List<ParticipantTrack> userMediaTracks) {
  final localParticipant = widget.room.localParticipant;

  if (localParticipant != null) {
    final localParticipantTrack = ParticipantTrack(participant: localParticipant);

    // Remove localParticipant if it already exists in the list
    userMediaTracks.removeWhere((track) => track.participant == localParticipant);

    // If there are more than 3 participants, insert localParticipant at the 4th position
    if (userMediaTracks.length >= 3) {
      userMediaTracks.insert(3, localParticipantTrack); // Insert at index 3 (4th position)
    } else {
      // If 3 or fewer participants, add the local participant to the end of the list
      userMediaTracks.add(localParticipantTrack);
    }
  }
}

void subscribeToFirstToFourthParticipants(List<ParticipantTrack> userMediaTracks) {
  // Ensure there are participants in the list
  if (userMediaTracks.isEmpty) {
    print('No participants available to subscribe.');
    return;
  }

  // Loop through the first 4 participants or the total number of participants if fewer than 4
  int limit = userMediaTracks.length < 4 ? userMediaTracks.length : 4;

  for (int i = 0; i < limit; i++) {
    ParticipantTrack participantTrack = userMediaTracks[i];
    _subscribeToParticipant(participantTrack);
  }
}

void _subscribeToParticipant(ParticipantTrack participantTrack) {
  // Logic to subscribe to the participant
   if (participantTrack.participant is RemoteParticipant ){
      final participant = participantTrack.participant as RemoteParticipant;
      participant.videoTrackPublications.forEach((publication) {
        if (!publication.subscribed) {
          publication.subscribe();
          publication.enable();
        //  print('Subscribed to ${participantTrack.participant.identity}\'s video track');
        }
      });

   }
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
    //print('rohit openEndDrawer');
    _scaffoldKey.currentState?.openEndDrawer();
  }

  // Toggle between view modes
  void _toggleParticipantList() {
    setState(() {
      isParticipantListVisible = !isParticipantListVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final bool isParticipantScreenShared = participantTracks.any((track) =>
        track.type == ParticipantTrackType.kScreenShare &&
        track.participant.identity != widget.room.localParticipant?.identity);
    final bool isStreamer = participantTracks.any((track) =>
        track.participant.identity == "streamer" &&
        track.participant.identity != widget.room.localParticipant?.identity);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF353535),
      body: SafeArea(
        child: Stack( // Changed from Row to Stack to allow proper positioning
          children: [
            Row(
              children: [
                // Main column with header, grid, and footer
                Expanded(
                  child: Column(
                    children: [
                      // Room header
                      RoomHeader(
                        room: widget.room,
                        participantsStatusList: participantsManager,
                        onToggleRaiseHand: _handleToggleRaiseHand,
                        isHandRaisedStatusChanged: _isHandleRaiseHand,
                        isAdmin: localParticipantRole == Role.admin.toString(),
                      ),

                      // Expanded Grid View (between header and footer)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: isParticipantScreenShared || isStreamer
                              ? Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ParticipantGridView(
                                        participantTracks: participantTracks.where(
                                          (track) =>
                                              (track.type ==
                                                      ParticipantTrackType.kScreenShare ||
                                                  track.participant.identity ==
                                                      "streamer") &&
                                              track.participant.identity !=
                                                  widget.room.localParticipant?.identity,
                                        ).toList(),
                                        participantStatuses: participantsManager,
                                        isLocalHost: false,
                                      ),
                                    ),
                                  ],
                                )
                              : ParticipantGridView(
                                  participantTracks: participantTracks.where(
                                    (track) =>
                                        track.type != ParticipantTrackType.kScreenShare &&
                                        track.participant.identity != "streamer",
                                  ).toList(),
                                  participantStatuses: participantsManager,
                                  isLocalHost:
                                      localParticipantRole == Role.admin.toString(),
                                ),
                        ),
                      ),

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

                // Sidebar
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: (!isMobile &&
                          widget.room.localParticipant != null &&
                          isParticipantListVisible)
                      ? 300
                      : 0,
                  color: Color(0xFF404040),
                  child: isParticipantListVisible
                      ? ParticipantListView(
                          participantTracks: participantTracks.where((track) {
                            return track.type != ParticipantTrackType.kScreenShare &&
                                track.participant.identity != "streamer";
                          }).toList(),
                          participantStatuses: participantsManager,
                        )
                      : null,
                ),
              ],
            ),

            // Sidebar Toggle Button - Now Positioned Correctly in the Center-Right
            if (!isMobile && isStreamer)
              Positioned(
                top: MediaQuery.of(context).size.height / 2 - 25, // Centered vertically
                right: isParticipantListVisible ? 280 : -20, // Adjust dynamically
                child: GestureDetector(
                  onTap: _toggleParticipantList,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isParticipantListVisible ? Icons.chevron_right : Icons.chevron_left,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
