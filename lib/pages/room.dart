// ignore_for_file: avoid_print

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
import 'package:video_meeting_room/pages/room-widget/ReconnectDialog.dart';
import 'package:video_meeting_room/providers/PinnedParticipantProvider.dart';
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
  final bool muteByDefault;
  final bool enableAudio;
  final bool enableVideo;

  const RoomPage(
    this.room,
    this.listener,
    this.muteByDefault,
    this.enableAudio,
    this.enableVideo, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> with WidgetsBindingObserver {
  // ==================== Properties/Fields ====================
  Map<String, SyncedParticipant> syncedParticipants = {};
  final List<ParticipantStatus> participantsStatusList = [];
  final List<StreamSubscription> _subscriptions = [];
  Timer? _checkPendingRequestsTimer;
  late PinnedParticipantProvider _pinnedProvider;

  int recentSpeechWindowMs = 10000;
  int promotionDelayMs = 1000;
  double minAudioLevel = 0.05;
  final Map<String, int> speakingCandidates =
      {}; // Should live outside the function

  bool _muteAll = true;
  bool _isHandleRaiseHand = false;
  bool isParticipantListVisible = false; // Track sidebar visibility
  bool _isRunning = true; // Control flag for the loop
  String? localParticipantRole;
  String searchQuery = '';
  bool _isPiP = false;
  bool _isSideBarShouldVisible = false;
  int _gridSize = 4; // Add this property
  bool _isFocusModeOn = false; // Add this property
  ParticipantStatus? localParticipantStatus;

  final ApprovalService _approvalService = GetIt.instance<ApprovalService>();
  final RoomDataManageService _roomDataManageService =
      GetIt.instance<RoomDataManageService>();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, BuildContext> _dialogContexts =
      {}; // Map to store dialog contexts

  EventsListener<RoomEvent> get _listener => widget.listener;
  bool get fastConnection => widget.room.engine.fastConnectOptions != null;

  // Add these properties
  bool _showControls = true;
  Timer? _hideControlsTimer;

  double? headerHeight = 64;
  double? controlsHeight = 72;
  String? _roomName = '';
  // Add this property to your _RoomPageState class properties
  bool _isMomAgentActive = false;

  // ==================== Lifecycle Methods ====================
  @override
  void initState() {
    super.initState();
    widget.room.addListener(_onRoomDidUpdate);
    _setUpListeners();
    _initializeLocalParticipantRole();
    _pinnedProvider =
        Provider.of<PinnedParticipantProvider>(context, listen: false);
    _pinnedProvider.addListener(_onPinnedChanged);

    _sortParticipants('initState');

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
    _isFocusModeOn = false;
    _roomName = widget.room.name;
  }

  @override
  Future<void> dispose() async {
    print('Disposing RoomPage');

    // First cancel timers to prevent async callbacks after disposal
    _isRunning = false;
    _checkPendingRequestsTimer?.cancel();

    // Cancel all tracked subscriptions
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    //  Close any open dialogs
    _closeAllDialogs();

    // Clean up observers
    WidgetsBinding.instance.removeObserver(this);

    // Use synchronous cleanup where possible
    if (lkPlatformIs(PlatformType.iOS)) {
      ReplayKitChannel.closeReplayKit();
    }

    // Remove room listener
    widget.room.removeListener(_onRoomDidUpdate);
    _pinnedProvider.removeListener(_onPinnedChanged);

    // Use a try-catch to ensure all resources are released even if some fail
    try {
      // Handle track cleanup
      await _listener.dispose();

      // Clean up all tracks synchronously
      await widget.room.localParticipant?.unpublishAllTracks();
      await widget.room.localParticipant?.setCameraEnabled(false);
      await widget.room.localParticipant?.setMicrophoneEnabled(false);
      await widget.room.localParticipant?.setScreenShareEnabled(false);

      // Remove room data
      await removeParticipantFromDB();

      // Finally dispose the room instance
      await widget.room.dispose();
    } catch (e) {
      print('Error during room cleanup: $e');
    }

    onWindowShouldClose = null;
    print('RoomPage fully disposed');
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  // Method to reset the timer
  void _resetHideControlsTimer() {
    setState(() {
      _showControls = true;
    });

    // Only start the hide timer if we're in focus mode
    if (_isFocusModeOn) {
      _startHideControlsTimer();
    }
  }

// Finally, modify the _startHideControlsTimer method to check for focus mode
  void _startHideControlsTimer() {
    // Only proceed if focus mode is on
    if (!_isFocusModeOn) return;

    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isFocusModeOn) {
        // Double-check focus mode is still on
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  // ==================== Room Management Methods ====================
  void _onRoomDidUpdate() {
    if (!mounted) return;
    setState(() {
      _sortUserMediaTracks();
    });
  }

  Future<void> handleRoomDisconnected(BuildContext context) async {
    if (!mounted) return;

    try {
      // First cleanup room resources
      await widget.room.localParticipant?.unpublishAllTracks();
      await widget.room.localParticipant?.setCameraEnabled(false);
      await widget.room.localParticipant?.setMicrophoneEnabled(false);
      await widget.room.localParticipant?.setScreenShareEnabled(false);
      await removeParticipantFromDB();

      // Then disconnect and dispose room
      await widget.room.disconnect();

      // Navigate based on role using pushReplacement
      if (!mounted) return;
      // Capture the context's mounted state
      if (!context.mounted) return;

      if (localParticipantRole == Role.admin.toString()) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ThankYouWidget()),
        );
      }
    } catch (e) {
      print('Error during room disconnection: $e');
      // Still try to navigate even if cleanup fails
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => localParticipantRole == Role.admin.toString()
              ? const LoginPage()
              : const ThankYouWidget(),
        ),
      );
    }
  }

  void _setUpListeners() {
    _listener
      ..on<RoomDisconnectedEvent>((event) async {
        if (event.reason != null) {
          print('Room disconnected reason: ${event.reason}');

          if (mounted && context.mounted) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => handleRoomDisconnected(context));
          }
        }
      })
      ..on<ParticipantEvent>((event) {
        _sortParticipants('ParticipantEvent');
      })
      ..on<RoomRecordingStatusChanged>((event) {
        //ontext.showRecordingStatusChangedDialog(event.activeRecording);
      })
      ..on<RoomAttemptReconnectEvent>((event) {
        print(
            'Attempting to reconnect ${event.attempt}/${event.maxAttemptsRetry}, '
            '(${event.nextRetryDelaysInMs}ms delay until next attempt)');
        // Show reconnection dialog
        //  _showReconnectDialog();
      })
      ..on<TranscriptionEvent>((event) {
        for (final segment in event.segments) {
          print(
              "New transcription from ${event.participant.identity}: ${segment.text}");
        }
      })
      ..on<RoomReconnectedEvent>((event) {
        print('Reconnected to room: ${widget.room.name}');

        //  ReconnectDialog.closeActiveDialog(context);
        _initializeParticipantStatuses();

        // _sortParticipants('RoomReconnectedEvent');
      })
      ..on<LocalTrackPublishedEvent>((_) {
        print('Local track published');
        ;
        _sortParticipants('LocalTrackPublishedEvent');
      })
      ..on<LocalTrackUnpublishedEvent>(
          (_) => _sortParticipants('LocalTrackUnpublishedEvent'))
      ..on<TrackSubscribedEvent>((event) {
        _sortParticipants('TrackSubscribedEvent');
      })
      ..on<TrackUnsubscribedEvent>((event) {
        print('Track unsubscribed: ${event.track.sid}');
        _sortParticipants('TrackUnsubscribedEvent');
      })
      ..on<DataReceivedEvent>((event) async {
        try {
        
          _receivedHandRaiseRequest(utf8.decode(event.data));
          updateParticipantStatusFromMetadata(utf8.decode(event.data));
        } catch (_) {}
      })
      ..on<ParticipantNameUpdatedEvent>((event) {
        print(
            'Participant name updated: ${event.participant.identity}, name => ${event.name}');
        _sortParticipants('');
      })
      ..on<ParticipantConnectedEvent>((event) async {
        if (localParticipantRole == Role.admin.toString()) {
          final identity = event.participant.identity;
          print('Participant connected: $identity');
          // Check if the participant is a mom agent
          if (identity.toLowerCase().contains('mom-bot')) {
            _notifyMomAgentActive(true);
          }
        }

        await _updateParticipantmanagerFromDB();
        _sortParticipants('TrackSubscribedEvent');
      })
      ..on<ParticipantDisconnectedEvent>((event) async {
        print('Participant disconnected: ${event.participant.identity}');
        if (localParticipantRole == Role.admin.toString()) {
          final identity = event.participant.identity;
          print('Participant connected: $identity');
          // Check if the participant is a mom agent
          if (identity.toLowerCase().contains('mom-bot')) {
            _notifyMomAgentActive(false);
          }
        }
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
  }

  Future<void> removeParticipantFromDB() async {
    final roomId = await widget.room.getSid();
    final localParticipant = widget.room.localParticipant;
    final identity = localParticipant?.identity;
    final roomName = widget.room.name;
    await _roomDataManageService.removeParticipant(roomId, roomName, identity);
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
          final isMomBot = widget.room.remoteParticipants.values.any(
            (p) => p.identity.toLowerCase().contains('mom-bot'),
          );
          if (isMomBot) {
            _notifyMomAgentActive(true);
          }
        }
      });
      if (localParticipantRole == Role.participant.toString() &&
          widget.muteByDefault) {
        Future.delayed(Duration.zero, () {
          if (mounted) {
            NewParticipantDialog.show(context, localParticipant.name);
          }
        });
      }
    }
  }

  void _sortParticipants(String from) {
    if (!mounted) return;
    final localParticipant = widget.room.localParticipant;
    final bool isLocalHost = localParticipant != null &&
        localParticipantRole == Role.admin.toString();

    final localParticipantStatus =
        _getParticipantStatus(localParticipant!.identity) ??
            ParticipantStatus(
              identity: localParticipant.identity,
              isAudioEnable: true,
              isVideoEnable: true,
              isTalkToHostEnable: false,
              isHandRaised: false,
              isPinned: false,
              isSpotlight: false,
              role: localParticipantRole!,
            );

    final bool isSpotlight = localParticipantStatus.isSpotlight;

    final previousSynced =
        Map<String, SyncedParticipant>.from(syncedParticipants);
    final Map<String, SyncedParticipant> tempSynced = {};

    for (var participant in widget.room.remoteParticipants.values) {
      final identity = participant.identity;
      if (identity.toLowerCase().contains('mom-bot')) {
        // Skip mom bot participants
        continue;
      }
      final participantStatus = _getParticipantStatus(identity);
      if (participantStatus == null) continue;

      final isRemoteParticipantHost =
          _getRoleFromMetadata(participant.metadata) == Role.admin.toString();

      final isVideo = participantStatus.isVideoEnable;
      final isAudio = participantStatus.isAudioEnable;
      final isTalkToHostEnable = participantStatus.isTalkToHostEnable;

      final shouldAudioSubscribe = (isTalkToHostEnable &&
              (isLocalHost || isRemoteParticipantHost || isSpotlight)) ||
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

      // Handle screen share track
      if (participant.isScreenShareEnabled()) {
        final key = '${identity}_screen';

        tempSynced[key] = SyncedParticipant(
          identity: key,
          track: ParticipantTrack(
            participant: participant,
            type: ParticipantTrackType.kScreenShare,
          ),
          status: participantStatus,
        );
      }

      // Handle camera or visible track
      if (isVideo || isLocalHost || isRemoteParticipantHost || isSpotlight) {
        tempSynced[identity] = SyncedParticipant(
          identity: identity,
          track: ParticipantTrack(
            participant: participant,
            type: ParticipantTrackType.kUserMedia,
          ),
          status: participantStatus,
        );
      }
    }

    // Maintain previous order then append new participants
    final sortedSynced = <String, SyncedParticipant>{};
    for (final key in previousSynced.keys) {
      if (tempSynced.containsKey(key)) {
        sortedSynced[key] = tempSynced[key]!;
      }
    }

    for (final entry in tempSynced.entries) {
      if (!sortedSynced.containsKey(entry.key)) {
        sortedSynced[entry.key] = entry.value;
      }
    }

    syncedParticipants
      ..clear()
      ..addAll(sortedSynced);

    _sortUserMediaTracks();

    setState(() {});
  }

  void _sortUserMediaTracks() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final recentSpeechCutoff = now - recentSpeechWindowMs;

    final pinnedSet = _pinnedProvider.pinnedIdentities;

    final localIdentity = widget.room.localParticipant?.identity;

    List<SyncedParticipant> allParticipants = syncedParticipants.values
        .where((p) =>
            p.track != null && p.identity != localIdentity) // exclude local
        .toList();
    final int maxVisible = _isSideBarShouldVisible ? 4 : _gridSize;
    List<SyncedParticipant> currentVisible =
        allParticipants.take(maxVisible).toList();
    final currentVisibleIds = currentVisible.map((p) => p.identity).toSet();

    bool isSpeaking(SyncedParticipant p) =>
        (p.track?.participant.lastSpokeAt?.millisecondsSinceEpoch ?? 0) >
        recentSpeechCutoff;

    bool isMuted(SyncedParticipant p) =>
        (p.track?.participant.isSpeaking == false) &&
        (p.track?.participant.audioLevel ?? 0.0) < 0.01;

    bool isHandRaised(SyncedParticipant p) => p.status?.isHandRaised == true;
    bool isPinned(SyncedParticipant p) => pinnedSet.contains(p.identity);
    bool isSpotlight(SyncedParticipant p) => p.status?.isSpotlight == true;
    bool isScreenShare(SyncedParticipant p) =>
        p.track!.type == ParticipantTrackType.kScreenShare;

    // Cleanup speakingCandidates for those no longer speaking
    speakingCandidates.removeWhere((identity, _) {
      final p = allParticipants.firstWhere((x) => x.identity == identity,
          orElse: () => SyncedParticipant(
                identity: identity,
                track: null,
                status: null,
              ));
      return !isSpeaking(p);
    });

    final activeSpeakersInTop4 =
        currentVisible.where((p) => isSpeaking(p)).length;

    final newSpeakers = allParticipants
        .where((p) => isSpeaking(p) && !currentVisibleIds.contains(p.identity))
        .toList();

    for (var p in newSpeakers) {
      speakingCandidates.putIfAbsent(p.identity, () => now);
    }

    final eligibleNewSpeakers = newSpeakers.where((p) {
      final startedAt = speakingCandidates[p.identity] ?? now;
      final hasSpokenLongEnough = now - startedAt >= promotionDelayMs;
      final isLoudEnough =
          (p.track?.participant.audioLevel ?? 0.0) >= minAudioLevel;
      return hasSpokenLongEnough && isLoudEnough;
    }).toList();

    if (eligibleNewSpeakers.isEmpty || activeSpeakersInTop4 >= maxVisible) {
      final updatedOrder = allParticipants.toList()
        ..sort((a, b) {
          int rank(SyncedParticipant p) {
            //   if (isScreenShare(p)) return 0;
            // Group camera right after screen share if same base identity
            final screenShareIdentities = allParticipants
                .where((x) => isScreenShare(x))
                .map((x) => x.identity.split('_screen').first)
                .toSet();

            final baseId = p.identity.split('_screen').first;
            if (screenShareIdentities.contains(baseId)) return 0;
            if (isSpotlight(p)) return 1;
            if (isPinned(p)) return 2;
            if (isHandRaised(p)) return 3;
            return 4;
          }

          int rA = rank(a);
          int rB = rank(b);
          if (rA != rB) return rA.compareTo(rB);

          // Optional: fallback to lastShownAt descending
          return (b.lastShownAt).compareTo(a.lastShownAt);
        });

      setState(() {
        syncedParticipants = {
          for (var p in updatedOrder) p.identity: p,
        };
      });

      _addLocalParticipant();
      return;
    }

    SyncedParticipant? replaceTarget;
    for (var p in currentVisible) {
      if (isScreenShare(p) ||
          isSpotlight(p) ||
          isPinned(p) ||
          isHandRaised(p)) {
        continue;
      }

      final lastSpoke =
          p.track?.participant.lastSpokeAt?.millisecondsSinceEpoch ?? 0;
      final neverSpoke = lastSpoke == 0;
      final notSpeaking = lastSpoke < recentSpeechCutoff;

      if (isMuted(p) || neverSpoke || notSpeaking) {
        if (replaceTarget == null ||
            (p.lastShownAt) < (replaceTarget.lastShownAt)) {
          replaceTarget = p;
        }
      }
    }

    if (replaceTarget != null) {
      final indexToReplace = currentVisible.indexOf(replaceTarget);
      final newSpeaker = eligibleNewSpeakers.first;
      newSpeaker.lastShownAt = now;

      currentVisible[indexToReplace] = newSpeaker;

      final updatedOrder = allParticipants.toList()
        ..sort((a, b) {
          int rank(SyncedParticipant p) {
            // Group camera right after screen share if same base identity
            final screenShareIdentities = allParticipants
                .where((x) => isScreenShare(x))
                .map((x) => x.identity.split('_screen').first)
                .toSet();

            final baseId = p.identity.split('_screen').first;
            if (screenShareIdentities.contains(baseId)) return 0;
            if (isSpotlight(p)) return 1;
            if (isPinned(p)) return 2;
            if (isHandRaised(p)) return 3;
            return 4;
          }

          int rA = rank(a);
          int rB = rank(b);
          if (rA != rB) return rA.compareTo(rB);

          // Within same rank, preserve visual order
          int aIndex =
              currentVisible.indexWhere((p) => p.identity == a.identity);
          int bIndex =
              currentVisible.indexWhere((p) => p.identity == b.identity);
          if (aIndex == -1) aIndex = 999;
          if (bIndex == -1) bIndex = 999;
          return aIndex.compareTo(bIndex);
        });

      setState(() {
        syncedParticipants = {
          for (var p in updatedOrder) p.identity: p,
        };
      });
    }

    _addLocalParticipant();
  }

  void _addLocalParticipant() {
    final localParticipant = widget.room.localParticipant;

    if (localParticipant == null) {
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

    // Remove existing entry if present (avoid duplicates)
    syncedParticipants.remove(localIdentity);

    // Convert to list to control order
    final entries = syncedParticipants.entries.toList();

    if (entries.length >= 3) {
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
    if (!mounted) return;
    final localParticipant = widget.room.localParticipant;
    if (localParticipant != null) {
      ParticipantStatus localStatus = ParticipantStatus(
        identity: localParticipant.identity,
        isAudioEnable:
            localParticipantRole == Role.admin.toString() || widget.enableAudio,
        isVideoEnable:
            localParticipantRole == Role.admin.toString() || widget.enableVideo,
        isTalkToHostEnable: localParticipantRole == Role.admin.toString() ||
            !widget.muteByDefault,
        role: localParticipantRole!,
      );
      final localParicipantStatus =
          _getParticipantStatus(localParticipant.identity);
      await _updateParticipantmanagerFromDB();
      if (localParicipantStatus != null) {
        localStatus = localParicipantStatus;
      }
      print('Local participant status: ${localStatus.identity}');
      setState(() {
        participantsStatusList.add(localStatus);

        _updateRoomData(participantsStatusList).then((_) {
          sendParticipantsStatus();
        });
      });
    }
  }

  Future<void> _updateParticipantmanagerFromDB() async {
    if (!mounted) return;
    final roomId = await widget.room.getSid();
    String? roomName = widget.room.name ?? _roomName;
    if (roomName == null) {
      print('Room name is null');
      return;
    }

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
    if (!mounted) return;
    // Parse the received metadata
    final decodedMetadata = jsonDecode(metadata);

    for (var element in decodedMetadata['participants']) {
      print('Local participant metadata: ${element['identity']}');
    }
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
    if (!mounted) return;
    final updatedIdentities = updatedStatuses.map((p) => p.identity).toSet();

    // Compute new list outside of setState
    final newList = [
      // Keep existing that are not being updated
      ...participantsStatusList
          .where((p) => !updatedIdentities.contains(p.identity)),

      // Add the new/updated participants
      ...updatedStatuses,
    ];

    setState(() {
      participantsStatusList
        ..clear()
        ..addAll(newList);
    });
    // Sync after state updated
    _updateRoomData(newList).then((_) {
      sendParticipantsStatus();
    });
  }

  void _notifyMomAgentActive(bool isActive) {
    if (!mounted) return;
    // Update the state to reflect the mom agent's active status

    //show nofification
    if (isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mom Agent recording is now active'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mom Agent recording is now inactive'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      // This will trigger a rebuild of RoomHeader with updated status
      _isMomAgentActive = isActive;
    });
  }

  void _handlePinAndSpotlightStatusChanged(ParticipantStatus status) {
    // Update the participant status
    List<ParticipantStatus> updatedStatuses = updateSpotlightStatus(
      participantList: participantsStatusList,
      updatedStatus: status,
    );

    // Call the callback function with the updated statuses
    updateParticipantsStatus(updatedStatuses);
  }

  void _onPinnedChanged() {
    _sortUserMediaTracks();
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
    if (!mounted) return;

    final participantStatus = _getParticipantStatus(identity);

    if (participantStatus == null) {
      return;
    }

    final participantTrack = syncedParticipants[identity]?.track;

    final participant = participantTrack!.participant;

    if (isHandRaised && localParticipantRole == Role.admin.toString()) {
      _showHandRaiseNotification(context, participant);
    }
  }

  void _toggleRaiseHand(Participant participant, bool isHandRaised) async {
    if (!mounted) return;
    final localParticipant = participant;

    final participantStatus = _getParticipantStatus(localParticipant.identity);
    if (participantStatus == null) return;

    // ✅ Only set timestamp on first raise
    if (isHandRaised && !participantStatus.isHandRaised) {
      participantStatus.handRaisedTimeStamp =
          DateTime.now().millisecondsSinceEpoch;
    }

    // ✅ Clear timestamp on unraise
    if (!isHandRaised) {
      participantStatus.handRaisedTimeStamp = 0;
    }

    // ✅ Update hand raise flag
    participantStatus.isHandRaised = isHandRaised;

    // ✅ Replace old entry with updated one
    participantsStatusList
      ..removeWhere((status) => status.identity == localParticipant.identity)
      ..add(participantStatus);

    updateParticipantsStatus(participantsStatusList);

    final handRaiseData = jsonEncode({
      'identity': participant.identity,
      'handraise': isHandRaised,
    });

    await widget.room.localParticipant?.publishData(utf8.encode(handRaiseData));

    setState(() {
      _isHandleRaiseHand = isHandRaised;
    });
  }

  void _handleToggleRaiseHand(bool isHandRaised) async {
    _toggleRaiseHand(widget.room.localParticipant as Participant, isHandRaised);
  }

  // ==================== Admin Control Methods ====================
  Future<void> _checkForPendingRequests() async {
    // Cancel any existing timer
    _checkPendingRequestsTimer?.cancel();

    // Use a recursive timer pattern instead of a while loop
    void scheduleNextCheck() {
      if (!_isRunning || !mounted) return;

      _checkPendingRequestsTimer = Timer(const Duration(seconds: 5), () async {
        if (!_isRunning || !mounted) return;

        try {
          final requests =
              await _approvalService.fetchPendingRequests(widget.room.name!);

          if (!mounted) return;

          final currentRequestIds =
              requests.map((request) => request['id'].toString()).toSet();

          // Handle dialog closures for completed requests
          _dialogContexts.keys.toList().forEach((requestId) {
            if (!currentRequestIds.contains(requestId)) {
              _closeDialog(requestId);
            }
          });

          if (requests.isEmpty && _dialogContexts.isNotEmpty) {
            _closeAllDialogs();
          }

          // Show new dialogs if needed
          for (var request in requests) {
            final requestId = request['id'].toString();
            if (!_dialogContexts.containsKey(requestId)) {
              _showApprovalDialog(request);
            }
          }
        } catch (error) {
          print('Error checking pending requests: $error');
        }

        // Schedule next check if still running
        scheduleNextCheck();
      });
    }

    // Start the first check
    scheduleNextCheck();
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
    if (!mounted) return;

    final dialogContext = _dialogContexts[requestId];
    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
      setState(() {
        _dialogContexts.remove(requestId);
      });
    } else {
      // Just remove from tracking if context is no longer valid
      _dialogContexts.remove(requestId);
    }
  }

  void _closeAllDialogs() {
    for (var context in _dialogContexts.values) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    _dialogContexts.clear();
  }

  void _toggleMuteAll(bool muteAll) {
    if (!mounted) return;
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

  void _handleToggleFocusMode(bool value) {
    setState(() {
      _isFocusModeOn = value;

      // When focus mode is turned ON:
      if (value) {
        // 1. Show controls initially to confirm the mode change
        _showControls = true;
        // 2. Start the auto-hide timer
        _startHideControlsTimer();
      }
      // When focus mode is turned OFF:
      else {
        // 1. Keep controls showing permanently
        _showControls = true;
        // 2. Cancel the auto-hide timer
        _hideControlsTimer?.cancel();
      }
    });
  }

  Widget _buildSidebar(
    List<SyncedParticipant> sidebarTracks,
    List<ParticipantStatus> statusList,
    bool isMobile,
  ) {
    if (!_isSideBarShouldVisible ||
        isMobile ||
        widget.room.localParticipant == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: ValueNotifier<bool>(isParticipantListVisible),
      builder: (context, isVisible, child) {
        return isVisible
            ? SizedBox(
                width: 300,
                child: Container(
                  color: const Color(0xFF404040),
                  child: ParticipantListView(
                    key: const ValueKey('sidebar'),
                    syncedParticipant: sidebarTracks,
                    handRaisedList: statusList,
                    isLocalHost: localParticipantRole == Role.admin.toString(),
                    onParticipantsStatusChanged:
                        _handlePinAndSpotlightStatusChanged,
                  ),
                ),
              )
            : const SizedBox.shrink();
      },
    );
  }

  List<SyncedParticipant> getPrioritizedTracks(
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
        .map((p) => p)
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
        .map((p) => p)
        .toList();
    if (spotlights.isNotEmpty) {
      onPiPChanged?.call(true);
      onSideBarShouldVisible?.call(true);
      return spotlights;
    }

    // Pinned participants (can include local)
    final pinned = participants.values
        .where((p) => pinnedIds.contains(p.identity))
        .map((p) => p)
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
          return !isScreenShare && (!isSpotlight || isLocal);
        })
        .map((p) => p)
        .toList();

    // Enable PiP if more than 4 participants
    if (defaultGrid.length > 4) {
      isPiP = true;
      defaultGrid.removeWhere((p) {
        return p.track!.participant.identity == localIdentity;
      });
    }

    onPiPChanged?.call(isPiP);
    onSideBarShouldVisible?.call(isSideBarShouldVisible);
    return defaultGrid;
  }

  List<SyncedParticipant> getSidebarParticipants(
    List<SyncedParticipant> prioritizedTracks,
    String localIdentity,
  ) {
    if (!mounted) return [];
    if (prioritizedTracks.isEmpty) {
      setState(() {
        _isSideBarShouldVisible = false;
      });
      return [];
    }

    // ignore: unnecessary_null_comparison
    final shownIds = prioritizedTracks != null
        ? prioritizedTracks
            .map((p) => p.identity)
            .toSet() // IDs already shown in grid or PiP

        : <String>{};
    final sidebarTracks = syncedParticipants.values.where((p) {
      if (p.track == null || p.identity == localIdentity) return false;

      final baseIdentity = p.identity.replaceFirst('_screen', '');
      final alreadyShown = shownIds.contains(baseIdentity);

      return !alreadyShown && p.track?.type == ParticipantTrackType.kUserMedia;
    }).toList();

    if (sidebarTracks.isNotEmpty) {
      setState(() {
        _isSideBarShouldVisible = true;
      });
    } else {
      setState(() {
        _isSideBarShouldVisible = false;
      });
    }
    //Optional: toggle sidebar visibility state

    return sidebarTracks;
  }

  void _handleGridSizeChange(int size) {
    setState(() {
      _gridSize = size;
    });
  }

  // Add this method to your _RoomPageState class
  Future<void> _showReconnectDialog() async {
    // Check if a dialog is already showing
    final isDialogShowing = ModalRoute.of(context)?.isCurrent != true;
    if (isDialogShowing || !mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ReconnectDialog(
          roomName: widget.room.name ?? 'Meeting Room',
        );
      },
    );

    // If user pressed Leave Meeting button (result == true), disconnect from room
    if (result == true && mounted) {
      handleRoomDisconnected(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localIdentity = widget.room.localParticipant?.identity;

    final localParticipant = syncedParticipants[localIdentity];

    final localParticipantTrack = localParticipant?.track;
    final localParticipantStatus = localParticipant?.status;

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    if (localIdentity == null) {
      print("localIdentity is null");
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (localParticipantTrack == null) {
      print("localParticipantTrack is null");
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (localParticipantStatus == null) {
      print("localParticipantStatus is null");
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final prioritizedTracks = getPrioritizedTracks(
      syncedParticipants,
      _pinnedProvider.pinnedIdentities,
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
            isParticipantListVisible = value;
            _isSideBarShouldVisible = value;
          });
        }
      },
    );
    final sidebarTracks = getSidebarParticipants(
      prioritizedTracks,
      localIdentity,
    );

    final statusList = syncedParticipants.values
        .map((e) => e.status)
        .whereType<ParticipantStatus>()
        .toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF353535),
      body: MouseRegion(
        onHover: (_) => _resetHideControlsTimer(),
        child: GestureDetector(
          onTap: _resetHideControlsTimer,
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          // Header with calculated height or zero
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: _showControls ? (headerHeight ?? 64) : 0,
                            child: AnimatedOpacity(
                              opacity: _showControls ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: RoomHeader(
                                room: widget.room,
                                participantsStatusList: statusList,
                                onToggleRaiseHand: _handleToggleRaiseHand,
                                isHandRaisedStatusChanged: _isHandleRaiseHand,
                                isAdmin: localParticipantRole ==
                                    Role.admin.toString(),
                                onGridSizeChanged: _handleGridSizeChange,
                                onOpenSidebar: _toggleParticipantList,
                                isSidebarOpen: isParticipantListVisible,
                                isSideBarShouldVisible: _isSideBarShouldVisible,
                                onToggleFocusMode: _handleToggleFocusMode,
                                isFocusModeOn: _isFocusModeOn,
                                isMomAgentActive: _isMomAgentActive,
                              ),
                            ),
                          ),

                          // Grid with flex factor that grows when headers are hidden
                          Flexible(
                            flex: _showControls
                                ? 1
                                : 10, // Increase flex when controls are hidden
                            child: ParticipantGridView(
                              syncedParticipant: prioritizedTracks,
                              handRaisedList: statusList,
                              isLocalHost:
                                  localParticipantRole == Role.admin.toString(),
                              onParticipantsStatusChanged:
                                  _handlePinAndSpotlightStatusChanged,
                              gridSize: _gridSize,
                            ),
                          ),

                          // Footer with calculated height or zero
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: _showControls ? (controlsHeight ?? 72) : 0,
                            child: AnimatedOpacity(
                              opacity: _showControls ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: ControlsWidget(
                                _toggleMuteAll,
                                _handleToggleRaiseHand,
                                _openEndDrawer,
                                () => _copyInviteLinkToClipboard(context),
                                _muteAll,
                                _isHandleRaiseHand,
                                localParticipantRole,
                                widget.room,
                                widget.room.localParticipant!,
                                statusList,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sidebar
                    _buildSidebar(sidebarTracks, statusList, isMobile),
                  ],
                ),

                // Rest of your UI...
                if (_isPiP)
                  DraggableParticipantWidget(
                    localParticipantTrack: localParticipantTrack,
                    localParticipantStatus: localParticipantStatus,
                    localParticipantRole: localParticipantRole!,
                    updateParticipantsStatus:
                        _handlePinAndSpotlightStatusChanged,
                  ),
              ],
            ),
          ),
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
        participantsStatusList: statusList,
      ),
    );
  }
}
