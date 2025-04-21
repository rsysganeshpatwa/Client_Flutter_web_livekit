import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import 'package:video_meeting_room/method_channels/replay_kit_channel.dart';
import 'package:video_meeting_room/models/role.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/pages/login.dart';
import 'package:video_meeting_room/pages/room-widget/AdminApprovalDialog.dart';
import 'package:video_meeting_room/pages/room-widget/CopyInviteLinkDialog.dart';
import 'package:video_meeting_room/pages/room-widget/DraggableParticipantWidget.dart';
import 'package:video_meeting_room/pages/room-widget/HandRaiseNotification.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantDrawer.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantGridView.dart';
import 'package:video_meeting_room/pages/room-widget/ParticipantListView.dart';
import 'package:video_meeting_room/pages/room-widget/NewParticipantDialog.dart';
import 'package:video_meeting_room/providers/PinnedParticipantProvider.dart';
import 'package:video_meeting_room/services/approval_service.dart';
import 'package:video_meeting_room/services/room_data_manage_service.dart';
import 'package:video_meeting_room/widgets/participant.dart';

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

class PrioritizedTracksResult {
  final List<ParticipantTrack> tracks;
  final bool isPiP;
  final bool isSideBarShouldVisible;

  PrioritizedTracksResult(this.tracks, this.isPiP,this.isSideBarShouldVisible);
}

class _RoomPageState extends State<RoomPage> with WidgetsBindingObserver {
  // ==================== Properties/Fields ====================
  Map<String, SyncedParticipant> syncedParticipants = {};
  final List<ParticipantStatus> participantsStatusList = [];

  bool _muteAll = true;
  bool _isHandleRaiseHand = false;
  bool isParticipantListVisible = false; // Track sidebar visibility
  bool _isRunning = true; // Control flag for the loop
  String? localParticipantRole;
  String searchQuery = '';
  bool _isPiP = false;
  bool _isSideBarShouldVisible = false;

  final ApprovalService _approvalService = GetIt.instance<ApprovalService>();
  final RoomDataManageService _roomDataManageService =
      GetIt.instance<RoomDataManageService>();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, BuildContext> _dialogContexts =
      {}; // Map to store dialog contexts

  EventsListener<RoomEvent> get _listener => widget.listener;
  bool get fastConnection => widget.room.engine.fastConnectOptions != null;

  // ==================== Lifecycle Methods ====================
  @override
  void initState() {
    super.initState();
    widget.room.addListener(_onRoomDidUpdate);
    _setUpListeners();
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
  }

  @override
  Future<void> dispose() async {
    (() async {
      if (lkPlatformIs(PlatformType.iOS)) {
        ReplayKitChannel.closeReplayKit();
      }

      widget.room.removeListener(_onRoomDidUpdate);
      await _listener.dispose();
      await widget.room.dispose();
      await removeParticipantFromDB();
    })();
    onWindowShouldClose = null;
    _isRunning = false;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ==================== Room Management Methods ====================
  void _onRoomDidUpdate() {
    setState(() {
      _sortUserMediaTracks();
    });
  }

  void _setUpListeners() => _listener
    ..on<RoomDisconnectedEvent>((event) async {
      if (event.reason != null) {}
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) =>
          handleRoomDisconnected(context, widget.room.localParticipant!));
    })
    ..on<ParticipantEvent>((event) {
      _sortParticipants('ParticipantEvent');
    })
    ..on<RoomRecordingStatusChanged>((event) {
      context.showRecordingStatusChangedDialog(event.activeRecording);
    })
    ..on<RoomAttemptReconnectEvent>((event) {})
    ..on<LocalTrackPublishedEvent>(
        (_) => _sortParticipants('LocalTrackPublishedEvent'))
    ..on<LocalTrackUnpublishedEvent>(
        (_) => _sortParticipants('LocalTrackUnpublishedEvent'))
    ..on<TrackSubscribedEvent>((event) {
      _sortParticipants('TrackSubscribedEvent');
    })
    ..on<TrackUnsubscribedEvent>((event) {
      _sortParticipants('TrackUnsubscribedEvent');
    })
    ..on<DataReceivedEvent>((event) async {
      try {
        _receivedHandRaiseRequest(utf8.decode(event.data));
        updateParticipantStatusFromMetadata(utf8.decode(event.data));
      } catch (_) {}
    })
    ..on<ParticipantConnectedEvent>((event) async {
      await _updateParticipantmanagerFromDB();
      _sortParticipants('TrackSubscribedEvent');
    })
    ..on<ParticipantDisconnectedEvent>((event) async {
      await _updateParticipantmanagerFromDB();
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
      await context.showErrorDialog(error);
    }
    try {
      await widget.room.localParticipant?.setMicrophoneEnabled(true);
    } catch (error) {
      await context.showErrorDialog(error);
    }
  }

  Future<void> removeParticipantFromDB() async {
    final roomId = await widget.room.getSid();
    final localParticipant = widget.room.localParticipant;
    final identity = localParticipant?.identity;
    final roomName = widget.room.name!;
    await _roomDataManageService.removeParticipant(roomId, roomName, identity);
  }

  void handleRoomDisconnected(BuildContext context, Participant participant) {
    if (localParticipantRole == Role.admin.toString()) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ThankYouWidget()),
      );
    }
  }

  // ==================== Participant Management Methods ====================
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

  void _sortParticipants(String from) {
    final localParticipant = widget.room.localParticipant;
    final bool isLocalHost = localParticipant != null &&
        localParticipantRole == Role.admin.toString();

    // Clear synced list before re-building
    syncedParticipants.clear();

    for (var participant in widget.room.remoteParticipants.values) {
      final identity = participant.identity;
      final participantStatus = _getParticipantStatus(identity);

      if (participantStatus == null) continue;

      final isRemoteParticipantHost =
          _getRoleFromMetadata(participant.metadata) == Role.admin.toString();

      final isVideo = participantStatus.isVideoEnable;
      final isAudio = participantStatus.isAudioEnable;
      final isTalkToHostEnable = participantStatus.isTalkToHostEnable;

      final shouldAudioSubscribe =
          (isTalkToHostEnable && (isLocalHost || isRemoteParticipantHost)) ||
              (isAudio &&
                  !((isLocalHost || isRemoteParticipantHost) &&
                      !isTalkToHostEnable));

      for (var element in participant.audioTrackPublications) {
        if (shouldAudioSubscribe) {
          element.subscribe();
        } else if (!(isLocalHost && isRemoteParticipantHost)) {
          element.unsubscribe();
        }
      }

      if (participant.isScreenShareEnabled()) {
        syncedParticipants[identity] = SyncedParticipant(
          identity: identity,
          track: ParticipantTrack(
            participant: participant,
            type: ParticipantTrackType.kScreenShare,
          ),
          status: participantStatus,
        );
      } else if (isVideo || isLocalHost || isRemoteParticipantHost) {
        syncedParticipants[identity] = SyncedParticipant(
          identity: identity,
          track: ParticipantTrack(participant: participant),
          status: participantStatus,
        );
      }
    }
    _sortUserMediaTracks();

    setState(() {});
  }

  void _sortUserMediaTracks() {
    List<SyncedParticipant> userMediaParticipants = syncedParticipants.values
        .where((participant) => participant.track != null)
        .toList();

    userMediaParticipants.sort((a, b) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final fiveSecondsAgo = now - 10000;

      final aSpokeAt =
          a.track?.participant.lastSpokeAt?.millisecondsSinceEpoch ?? 0;
      final bSpokeAt =
          b.track?.participant.lastSpokeAt?.millisecondsSinceEpoch ?? 0;

      final aSpokeRecently = aSpokeAt > fiveSecondsAgo;
      final bSpokeRecently = bSpokeAt > fiveSecondsAgo;

      if (aSpokeRecently != bSpokeRecently) {
        return aSpokeRecently ? -1 : 1;
      }

      if (a.track?.participant.hasVideo != b.track?.participant.hasVideo) {
        return a.track?.participant.hasVideo == true ? -1 : 1;
      }

      return a.track?.participant.joinedAt.millisecondsSinceEpoch ??
          0 - (b.track?.participant.joinedAt.millisecondsSinceEpoch ?? 0);
    });

    userMediaParticipants.sort((a, b) {
      final statusA = a.status;
      final statusB = b.status;

      final isHandRaisedA = statusA?.isHandRaised ?? false;
      final isHandRaisedB = statusB?.isHandRaised ?? false;

      if (!isHandRaisedA && !isHandRaisedB) {
        return 0;
      } else if (!isHandRaisedA) {
        return 1;
      } else if (!isHandRaisedB) {
        return -1;
      }

      return (statusA?.handRaisedTimeStamp ?? 0) -
          (statusB?.handRaisedTimeStamp ?? 0);
    });

    setState(() {
      syncedParticipants = {for (var p in userMediaParticipants) p.identity: p};
    });

    _addLocalParticipant();
    subscribeToFirstToFourthParticipants();
  }

  void _addLocalParticipant() {
    final localParticipant = widget.room.localParticipant;

    if (localParticipant == null) {
      print('[DEBUG] No local participant found.');
      return;
    }

    final localIdentity = localParticipant.identity;
    final localTrack = ParticipantTrack(participant: localParticipant);

    final existingStatus = _getParticipantStatus(localIdentity) ??
        ParticipantStatus(
          identity: localIdentity,
          isAudioEnable: true,
          isVideoEnable: true,
          isTalkToHostEnable: false,
          isHandRaised: false,
          isPinned: false,
          isSpotlight: false,
          role: localParticipantRole!,
        );

    print('[DEBUG] Adding local participant: $localIdentity');
    print(
        '[DEBUG] Existing syncedParticipants count: ${syncedParticipants.length}');
    print('[DEBUG] Existing Status: $existingStatus');

    // Remove existing entry if present (avoid duplicates)
    final wasRemoved = syncedParticipants.remove(localIdentity) != null;
    if (wasRemoved) {
      print('[DEBUG] Removed existing local participant from synced list');
    }

    // Convert to list to control order
    final entries = syncedParticipants.entries.toList();

    if (entries.length >= 3) {
      print(
          '[DEBUG] More than 3 participants exist. Inserting local at index 3.');
      entries.insert(
          3,
          MapEntry(
            localIdentity,
            SyncedParticipant(
              identity: localIdentity,
              track: localTrack,
              status: existingStatus,
            ),
          ));
    } else {
      print('[DEBUG] Less than 3 participants. Adding local normally.');
      entries.add(MapEntry(
        localIdentity,
        SyncedParticipant(
          identity: localIdentity,
          track: localTrack,
          status: existingStatus,
        ),
      ));
    }

    // Rebuild map from ordered list
    syncedParticipants
      ..clear()
      ..addEntries(entries);

    print(
        '[DEBUG] Final syncedParticipants count: ${syncedParticipants.length}');
    print('[DEBUG] Synced identities: ${syncedParticipants.keys.toList()}');
  }

  void subscribeToFirstToFourthParticipants() {
    if (syncedParticipants.isEmpty) {
      return;
    }

    List<SyncedParticipant> sortedParticipants =
        syncedParticipants.values.where((p) => p.track != null).toList();

    sortedParticipants.sort((a, b) {
      final aSpokeAt =
          a.track?.participant.lastSpokeAt?.millisecondsSinceEpoch ?? 0;
      final bSpokeAt =
          b.track?.participant.lastSpokeAt?.millisecondsSinceEpoch ?? 0;

      final aSpokeRecently =
          aSpokeAt > (DateTime.now().millisecondsSinceEpoch - 10000);
      final bSpokeRecently =
          bSpokeAt > (DateTime.now().millisecondsSinceEpoch - 10000);

      if (aSpokeRecently != bSpokeRecently) {
        return aSpokeRecently ? -1 : 1;
      }

      return a.track?.participant.joinedAt.millisecondsSinceEpoch ??
          0 - (b.track?.participant.joinedAt.millisecondsSinceEpoch ?? 0);
    });

    int limit = sortedParticipants.length < 4 ? sortedParticipants.length : 4;

    for (int i = 0; i < limit; i++) {
      SyncedParticipant syncedParticipant = sortedParticipants[i];
      _subscribeToParticipant(syncedParticipant.track!);
    }
  }

  void _subscribeToParticipant(ParticipantTrack participantTrack) {
    if (participantTrack.participant is RemoteParticipant) {
      final participant = participantTrack.participant as RemoteParticipant;
      for (var publication in participant.videoTrackPublications) {
        if (!publication.subscribed) {
          publication.subscribe();
          publication.enable();
        }
      }
    }
  }

  List<ParticipantTrack> _filterParticipants(String searchQuery) {
    final localParticipant = widget.room.localParticipant;

    final filteredParticipants =
        syncedParticipants.values.where((syncedParticipant) {
      final participantName =
          syncedParticipant.track!.participant.name.toLowerCase();
      return participantName.contains(searchQuery.toLowerCase());
    }).toList();

    final participantTracks = filteredParticipants.map((syncedParticipant) {
      return ParticipantTrack(
          participant: syncedParticipant.track!.participant);
    }).toList();

    if (localParticipant != null) {
      participantTracks
          .removeWhere((track) => track.participant == localParticipant);
      participantTracks.insert(
          0, ParticipantTrack(participant: localParticipant));
    }

    return participantTracks;
  }

  String _getRoleFromMetadata(String? metadata) {
    if (metadata != null && metadata.isNotEmpty) {
      final decodedMetadata = jsonDecode(metadata);
      return decodedMetadata['role'] ?? '';
    }
    return '';
  }

  // ==================== Participant Status Methods ====================
  Future<void> _initializeParticipantStatuses() async {
    final localParticipant = widget.room.localParticipant;
    if (localParticipant != null) {
      await _updateParticipantmanagerFromDB();
      final localStatus = ParticipantStatus(
        identity: localParticipant.identity,
        isAudioEnable: localParticipantRole == Role.admin.toString(),
        isVideoEnable: localParticipantRole == Role.admin.toString(),
        isTalkToHostEnable: localParticipantRole == Role.admin.toString(),
        role: localParticipantRole!,
      );

      setState(() {
        participantsStatusList.add(localStatus);

        _updateRoomData(participantsStatusList);
        sendParticipantsStatus();
      });
    }
  }

  Future<void> _updateParticipantmanagerFromDB() async {
    final roomId = await widget.room.getSid();
    final roomName = widget.room.name!;

    final data = await _roomDataManageService.getLatestData(roomId, roomName);
    if (data != null) {
      final participantsStatusDataList = (data as List).map((item) {
        return ParticipantStatus(
          identity: item['identity'],
          isAudioEnable: item['isAudioEnable'],
          isVideoEnable: item['isVideoEnable'],
          isHandRaised: item['isHandRaised'],
          isTalkToHostEnable: item['isTalkToHostEnable'],
          handRaisedTimeStamp: item['handRaisedTimeStamp'],
          isPinned: item['isPinned'],
          isSpotlight: item['isSpotlight'],
          role: item['role'],
        );
      }).toList();

      setState(() {
        participantsStatusList.clear();
        participantsStatusList.addAll(participantsStatusDataList);
      });
    }
  }

  void updateParticipantStatusFromMetadata(String metadata) {
    // Parse the received metadata
    final decodedMetadata = jsonDecode(metadata);

    if (decodedMetadata['type'] == 'participantsStatusUpdate') {
      // Extract the list of participant status data from the 'participants' key
      final participantsStatusDataList =
          (decodedMetadata['participants'] as List)
              .map((item) => ParticipantStatus(
                    identity: item['identity'],
                    isAudioEnable: item['isAudioEnable'],
                    isVideoEnable: item['isVideoEnable'],
                    isHandRaised: item['isHandRaised'],
                    isTalkToHostEnable: item['isTalkToHostEnable'],
                    handRaisedTimeStamp: item['handRaisedTimeStamp'],
                    isPinned: item['isPinned'],
                    isSpotlight: item['isSpotlight'],
                    role: item['role'],
                  ))
              .toList();

      // Update the state with the new participants status list
      setState(() {
        participantsStatusList.clear();
        participantsStatusList.addAll(participantsStatusDataList);

        for (var element in participantsStatusList) {
          if (element.identity == widget.room.localParticipant?.identity) {
            _isHandleRaiseHand = element.isHandRaised;
          }
        }
        _sortParticipants('updateParticipantStatusFromMetadata');
      });
    }
  }

  Future<void> sendParticipantsStatus() async {
    final participantsJsonList =
        participantsStatusList.map((status) => status.toJson()).toList();

    final metadata = jsonEncode({
      'type': 'participantsStatusUpdate',
      'timestamp': DateTime.now().toIso8601String(),
      'participants': participantsJsonList,
    });

    await widget.room.localParticipant
        ?.publishData(utf8.encode(metadata), reliable: true);
    await _updateRoomData(participantsStatusList);
    _sortParticipants('sendParticipantsStatus');
  }

void updateParticipantsStatus(List<ParticipantStatus> updatedStatuses) {
  final updatedIdentities = updatedStatuses.map((p) => p.identity).toSet();

  setState(() {
    // Remove existing ones with the same identity
    participantsStatusList.removeWhere((p) => updatedIdentities.contains(p.identity));
    
    // Add updated participants
    participantsStatusList.addAll(updatedStatuses);

    // Update and sync
    _updateRoomData(participantsStatusList).then((_) {
      sendParticipantsStatus();
    });
  });
}


  Future<void> _updateRoomData(List<ParticipantStatus> statuslist) async {
    final roomSID = await widget.room.getSid();
    final roomName = widget.room.name!;

    final participantStatuses =
        statuslist.map((status) => status.toJson()).toList();
    _roomDataManageService.setLatestData(
        roomSID, roomName, participantStatuses);
  }

  ParticipantStatus? _getParticipantStatus(String identity) {
    try {
      return participantsStatusList.firstWhere(
        (status) => status.identity == identity,
      );
    } catch (e) {
      return null;
    }
  }

  // ==================== Hand Raise Methods ====================
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
      final participantStatus = _getParticipantStatus(identity);

      if (participantStatus == null) {
        return;
      }

      final participantTrack = syncedParticipants[identity]?.track;

      final participant = participantTrack!.participant;

      participantStatus.isHandRaised = isHandRaised;

      if (isHandRaised) {
        participantStatus.handRaisedTimeStamp =
            DateTime.now().millisecondsSinceEpoch;
      }

      if (widget.room.localParticipant?.identity == identity) {
        _isHandleRaiseHand = isHandRaised;
      }

      if (isHandRaised && localParticipantRole == Role.admin.toString()) {
        _showHandRaiseNotification(context, participant);
      }

      _sortParticipants('handleRaiseHandFromParticipant');
    });
  }

  void _toggleRaiseHand(Participant participant, bool isHandRaised) async {
    final handRaiseData = jsonEncode(
        {'identity': participant.identity, 'handraise': isHandRaised});

    await widget.room.localParticipant?.publishData(
      utf8.encode(handRaiseData),
    );

    _handleRaiseHandFromParticipant(participant.identity, isHandRaised);
  }

  void _handleToggleRaiseHand(bool isHandRaised) async {
    _toggleRaiseHand(widget.room.localParticipant as Participant, isHandRaised);
  }

  // ==================== Admin Control Methods ====================
  Future<void> _checkForPendingRequests() async {
    while (_isRunning) {
      try {
        final requests =
            await _approvalService.fetchPendingRequests(widget.room.name!);
        final currentRequestIds =
            requests.map((request) => request['id'].toString()).toSet();

        _dialogContexts.keys.toList().forEach((requestId) {
          if (!currentRequestIds.contains(requestId)) {
            _closeDialog(requestId);
          }
        });

        if (requests.isEmpty && _dialogContexts.isNotEmpty) {
          _dialogContexts.keys.toList().forEach((requestId) {
            _closeDialog(requestId);
          });
        }

        for (var request in requests) {
          final requestId = request['id'].toString();
          if (!_dialogContexts.containsKey(requestId)) {
            _showApprovalDialog(request);
          }
        }
        // ignore: empty_catches
      } catch (error) {}
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  void _showApprovalDialog(dynamic request) {
    final requestId = request['id'].toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        _dialogContexts[requestId] = context;

        return AdminApprovalDialog(
          participantName: request['participantName'],
          roomName: request['roomName'],
          onDecision: (approved) async {
            await _approvalService.approveRequest(request['id'], approved);
            _closeDialog(requestId);
          },
        );
      },
    ).then((_) {
      _dialogContexts.remove(requestId);
    });
  }

  void _closeDialog(String requestId) {
    final dialogContext = _dialogContexts[requestId];
    if (dialogContext != null) {
      Navigator.of(dialogContext).pop();
      setState(() {
        _dialogContexts.remove(requestId);
      });
    }
  }

  void _toggleMuteAll(bool muteAll) {
    setState(() {
      _muteAll = muteAll;

      for (var participant in syncedParticipants.values) {
        if (participant.status?.role != Role.admin.toString()) {
          participant.status?.isTalkToHostEnable = !muteAll;
        }
      }

      sendParticipantsStatus();
    });
  }

  void _allowSpeak(Participant participant) {
    final syncedParticipant = syncedParticipants[participant.identity];
    if (syncedParticipant != null && syncedParticipant.status != null) {
      setState(() {
        syncedParticipant.status!.isTalkToHostEnable = true;
        syncedParticipant.status!.isHandRaised = false;
        sendParticipantsStatus();
      });
    }
  }

  void _denySpeak(Participant participant) {
    final syncedParticipant = syncedParticipants[participant.identity];
    if (syncedParticipant != null && syncedParticipant.status != null) {
      setState(() {
        syncedParticipant.status!.isTalkToHostEnable = false;
        syncedParticipant.status!.isHandRaised = false;
        sendParticipantsStatus();
      });
    }
  }

  // ==================== UI Control Methods ====================
  void _showHandRaiseNotification(
      BuildContext context, Participant participant) {
    HandRaiseNotification.show(context, participant, _allowSpeak, _denySpeak);
  }

  Future<void> _copyInviteLinkToClipboard(BuildContext context) async {
    CopyInviteLinkDialog.show(context, widget.room.name!);
  }

  void _openEndDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _toggleParticipantList() {
    setState(() {
      isParticipantListVisible = !isParticipantListVisible;
    });
  }

  List<ParticipantTrack> getPrioritizedTracks(
    Map<String, SyncedParticipant> participants,
    List<String> pinnedIds,
    String? localIdentity,
    void Function(bool isPiP)? onPiPChanged, // optional callback to set state
    void Function(bool isSideBarShouldVisible)? onSideBarShouldVisible,
  ) {
    bool isPiP = false;
    bool isSideBarShouldVisible = false;

    // Screen share has highest priority (excluding local)
    final screenShares = participants.values
        .where((p) =>
            p.track?.type == ParticipantTrackType.kScreenShare &&
            p.identity != localIdentity)
        .map((p) => p.track!)
        .toList();
    if (screenShares.isNotEmpty) {
      onPiPChanged?.call(true);
      onSideBarShouldVisible?.call(true);
      return screenShares;
    }

    // Spotlighted participants (excluding local)
    final spotlights = participants.values
        .where(
            (p) => p.status?.isSpotlight == true && p.identity != localIdentity)
        .map((p) => p.track!)
        .toList();
    if (spotlights.isNotEmpty) {
      onPiPChanged?.call(true);
       onSideBarShouldVisible?.call(true);
       print('Spotlights: ${spotlights.length}');
      print('Spotlights: ${spotlights.map((e) => e.participant.name)}');
      return spotlights;
    }

    // Pinned participants (can include local)
    final pinned = participants.values
        .where((p) => pinnedIds.contains(p.identity))
        .map((p) => p.track!)
        .toList();
    if (pinned.isNotEmpty) {
      onPiPChanged?.call(true);
       onSideBarShouldVisible?.call(true);
      return pinned;
    }

    // Default grid participants
 final defaultGrid = participants.values
    .where((p) {
      final isSpotlight = p.status?.isSpotlight == true;
      final isScreenShare =
          p.track?.type == ParticipantTrackType.kScreenShare;
      final isLocal = p.identity == localIdentity;

      return !isScreenShare &&
          (!isSpotlight || (isSpotlight && isLocal == false));
    })
    .map((p) => p.track!)
    .toList();

    // Enable PiP if more than 4 participants
    if (defaultGrid.length > 4) {
      isPiP = true;
       defaultGrid.removeWhere((track) {
        return track.participant.identity == localIdentity;
      });
    } 

    onPiPChanged?.call(isPiP);
    onSideBarShouldVisible?.call(isSideBarShouldVisible);
    print('Default Grid: ${defaultGrid.length}');
    print('Default Grid: ${defaultGrid.map((e) => e.participant.name)}');
    return defaultGrid;
  }

  @override
  Widget build(BuildContext context) {
    final pinnedProvider = Provider.of<PinnedParticipantProvider>(context);
    final localIdentity = widget.room.localParticipant?.identity;

    final localParticipant = syncedParticipants[localIdentity];

    final localParticipantTrack = localParticipant?.track;
    final localParticipantStatus = localParticipant?.status;

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final prioritizedTracks = getPrioritizedTracks(
      syncedParticipants,
      pinnedProvider.pinnedIdentities,
      localIdentity,
      (bool value) {
        if (_isPiP != value) {
          setState(() {
            _isPiP = value;
          });
        }
      },
      (bool value) {
        if (_isSideBarShouldVisible != value) {
          setState(() {
            _isSideBarShouldVisible = value;
          });
        }
      },
    );

    final shownIds = prioritizedTracks
        .map((track) => track.participant.identity)
        .toSet(); // So we can exclude these

   final sidebarTracks = syncedParticipants.values
    .where((p) =>
        p.track != null &&
        p.identity != localIdentity && // Exclude local participant
        !shownIds.contains(p.identity) &&
        p.track?.type != ParticipantTrackType.kScreenShare) // Avoid screenshare
    .map((p) => p.track!)
    .toList();
    if(sidebarTracks.isEmpty) {
      setState(() {
      _isSideBarShouldVisible =false;
    });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF353535),
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      RoomHeader(
                        room: widget.room,
                        participantsStatusList: syncedParticipants.values
                            .map((e) => e.status)
                            .whereType<ParticipantStatus>()
                            .toList(),
                        onToggleRaiseHand: _handleToggleRaiseHand,
                        isHandRaisedStatusChanged: _isHandleRaiseHand,
                        isAdmin: localParticipantRole == Role.admin.toString(),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ParticipantGridView(
                            participantTracks: prioritizedTracks,
                            participantStatuses: syncedParticipants.values
                                .map((e) => e.status)
                                .whereType<ParticipantStatus>()
                                .toList(),
                            isLocalHost:
                                localParticipantRole == Role.admin.toString(),
                            onParticipantsStatusChanged:
                                updateParticipantsStatus,
                          ),
                        ),
                      ),
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
                        syncedParticipants.values
                            .map((e) => e.status)
                            .whereType<ParticipantStatus>()
                            .toList(),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: (!isMobile &&
                          widget.room.localParticipant != null &&
                          isParticipantListVisible && _isSideBarShouldVisible)
                      ? 300
                      : 0,
                  color: const Color(0xFF404040),
                  child: _isSideBarShouldVisible
                      ? ParticipantListView(
                          participantTracks: sidebarTracks,
                          participantStatuses: syncedParticipants.values
                              .map((e) => e.status)
                              .whereType<ParticipantStatus>()
                              .toList(),
                          onParticipantsStatusChanged: updateParticipantsStatus,
                        )
                      : null,
                ),
              ],
            ),
            if (!isMobile && _isSideBarShouldVisible)
              Positioned(
                top: MediaQuery.of(context).size.height / 2 - 25,
                right: isParticipantListVisible ? 280 : -20,
                child: GestureDetector(
                  onTap: _toggleParticipantList,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isParticipantListVisible
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            if (!isMobile && _isPiP)
              DraggableParticipantWidget(
                localParticipantTrack: localParticipantTrack!,
                localParticipantStatus: localParticipantStatus!,
                localParticipantRole: localParticipantRole!,
                updateParticipantsStatus: updateParticipantsStatus,
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
        onParticipantsStatusChanged: updateParticipantsStatus,
        participantsStatusList: syncedParticipants.values
            .map((e) => e.status)
            .whereType<ParticipantStatus>()
            .toList(),
      ),
    );
  }
}
