import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/method_channels/replay_kit_channel.dart';
import 'package:video_meeting_room/models/role.dart';
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
  Set<Participant> _allowedToTalk = {}; // Track participants allowed to talk
  String searchQuery = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? localParticipantRole;

  @override
  void initState() {
    super.initState();
    widget.room.addListener(_onRoomDidUpdate);
    _setUpListeners();
    _sortParticipants();
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      if (!fastConnection) {
        _askPublish();
      }
    });

    // Set up role for the local participant
    _initializeLocalParticipantRole();

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
      });
    }
    _initializeAllowedToTalk();
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
      _trackSubscribed(event);
    })
    ..on<TrackUnsubscribedEvent>((event) {
      _sortParticipants();
      _trackUnsubscribed(event);
    })
    ..on<ParticipantNameUpdatedEvent>((event) {
      _sortParticipants();
    })
    ..on<DataReceivedEvent>((event) {
      try {
        _receivedMetadata(event);
      } catch (_) {
        print('Failed to decode: $_');
      }
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

  Future<void> _updateAllowedToTalkMetadata() async {
    // Broadcast the updated list to all participants
    final allowedToTalkIdentities =
        _allowedToTalk.map((p) => p.identity).toList();
    final dataMessage = jsonEncode({'allowedToTalk': allowedToTalkIdentities});
    await widget.room.localParticipant?.publishData(utf8.encode(dataMessage));
  }

  void _receivedMetadata(DataReceivedEvent event) {
    try {
      final decodedData = utf8.decode(event.data);
      final data = jsonDecode(decodedData) as Map<String, dynamic>;
      print('Received metadata: $data');

      setState(() {
        // Handle allowedToTalk updates
        if (data.containsKey('allowedToTalk')) {
          final allowedIdentities = data['allowedToTalk'] as List<dynamic>;
          _allowedToTalk = widget.room.remoteParticipants.values
              .where((p) => allowedIdentities.contains(p.identity))
              .toSet();
          _updateAudioSubscriptions();
        }

        // Handle handraise updates
        if (data.containsKey('identity') && data.containsKey('handraise')) {
          final identity = data['identity'] as String;
          final handraise = data['handraise'] as bool;
          _handleHandraiseUpdate(identity, handraise);
        }
      });
    } catch (e) {
      print('Failed to parse metadata: $e');
    }
  }

void _handleHandraiseUpdate(String identity, bool handraise) {
  setState(() {
    participantTracks.forEach((track) {
      if (track.participant.identity == identity) {
        final currentMetadata =
            jsonDecode(track.participant.metadata ?? '{}');

        currentMetadata['handraise'] = handraise;

        // If the hand is being raised, store the current timestamp
        if (handraise) {
          currentMetadata['handraiseTime'] = DateTime.now().millisecondsSinceEpoch;
        }

        track.participant.metadata = jsonEncode(currentMetadata);

        // Handle the local participant's hand raise status
        if (widget.room.localParticipant?.identity == identity) {
          _isHandleRaiseHand = handraise;
        }

        // Show notification if the hand is raised and the local participant is an admin
        if (handraise && localParticipantRole == Role.admin.toString()) {
          _showHandRaiseNotification(context, track.participant);
        }
      }
    });
  });
}

  void _sortParticipants() {
    List<ParticipantTrack> userMediaTracks = [];
    List<ParticipantTrack> screenTracks = [];
    final localParticipant = widget.room.localParticipant;

    bool isHost = localParticipant != null &&
        localParticipantRole == Role.admin.toString();
    for (var participant in widget.room.remoteParticipants.values) {
      final metadata = participant.metadata;
      final remoteParticipantRole =
          metadata != null ? jsonDecode(metadata)['role'] : null;

      if (participant.isScreenShareEnabled()) {
        screenTracks.add(ParticipantTrack(
          participant: participant,
          type: ParticipantTrackType.kScreenShare,
        ));
      } else if (isHost || remoteParticipantRole == Role.admin.toString()) {
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
    userMediaTracks
        .add(ParticipantTrack(participant: widget.room.localParticipant!));
    setState(() {
      participantTracks = [...screenTracks, ...userMediaTracks];
    });
  }

  void _initializeAllowedToTalk() {
    setState(() {
      _allowedToTalk.clear();
      if (localParticipantRole == Role.admin.toString()) {
        // New admin joins: Mute all participants
         _allowedToTalk.add(widget.room.localParticipant as Participant);
      } else {
        // Participant joins: Check if they should be allowed to talk
        for (var participant in widget.room.remoteParticipants.values) {
          if (_allowedToTalk.contains(participant)) {
            _allowedToTalk.add(participant);
          } else {
            _allowedToTalk.remove(participant);
          }
        }
      }
      _updateAudioSubscriptions();
    });
  }

  void _toggleParticipantForTalk(Participant participant) {
    setState(() {
      final isAllowedToTalk = _allowedToTalk.contains(participant);

      // Toggle the participant's allowed to talk status
      if (isAllowedToTalk) {
        // If the participant is currently allowed to talk, remove them
        _allowedToTalk.remove(participant);
      } else {
        // If the participant is currently not allowed to talk, add them
        _allowedToTalk.add(participant);
        // Also set _muteAll to false when toggling individual participants
        _muteAll = false;
      }
        
        print('Starting _toggleParticipantForTalk _allowedToTalk ganesh ${_allowedToTalk}');

      // Update audio subscriptions only if there's a change in allowedToTalk
      if (isAllowedToTalk != _allowedToTalk.contains(participant)) {
        _updateAudioSubscriptions();
      }

      // Ensure metadata is consistent with allowedToTalk state
      _updateAllowedToTalkMetadata();
      _toggleRaiseHand(participant, false);
    });
  }

  void _toggleMuteAll(bool muteAll) {
    setState(() {
      _muteAll = muteAll;
      _allowedToTalk.clear(); // Clear the current set

      if (muteAll) {
        final localParticipant = widget.room.localParticipant;

        if (localParticipant != null &&
            localParticipantRole == Role.admin.toString()) {
          _allowedToTalk.add(localParticipant);
        }
      } else {
        _allowedToTalk.addAll(widget.room.remoteParticipants.values);
      }
      _updateAudioSubscriptions();
      _updateAllowedToTalkMetadata();
    });
  }

void _trackSubscribed(TrackSubscribedEvent event) {
  final participant = event.participant;
  final metadata = participant.metadata;
  final role = _getRoleFromMetadata(metadata);
  print('Track subscribed _allowedToTalk ganesh + ${_allowedToTalk}');
   print('Track subscribed identity ganesh + ${participant.identity}');
   print('Track subscribed _muteAll ganesh + ${_muteAll}');
  setState(() {
    if (role != Role.admin.toString()) {
      if (!_muteAll) {
        _allowedToTalk.add(participant);
      } else {
        _allowedToTalk.remove(participant);
      }
    } else {
      _allowedToTalk.add(participant);  // Admin is always allowed to talk
    }

    _updateAudioSubscriptions();
  });
}

void _trackUnsubscribed(TrackUnsubscribedEvent event) {
  final participant = event.participant;
  final metadata = participant.metadata;
  final role = _getRoleFromMetadata(metadata);

  setState(() {
    if (role != Role.admin.toString()) {
      if (_allowedToTalk.contains(participant)) {
        _allowedToTalk.remove(participant);
      }
    }
    _updateAudioSubscriptions();
  });
}

String _getRoleFromMetadata(String? metadata) {
  if (metadata != null && metadata.isNotEmpty) {
    final decodedMetadata = jsonDecode(metadata);
    return decodedMetadata['role'] ?? '';
  }
  return '';
}


  void _updateAudioSubscriptions() {
    print('Starting _updateAudioSubscriptions ganesh');
    print('Current _allowedToTalk ganesh: ${_allowedToTalk}');

    if (localParticipantRole == Role.admin.toString() &&
        !_allowedToTalk.contains(widget.room.localParticipant!)) {
      _allowedToTalk.add(widget.room.localParticipant!);
    }

    for (var participant in widget.room.remoteParticipants.values) {
      final metadata = participant.metadata;
      final role = metadata != null ? jsonDecode(metadata)['role'] : null;
      for (var track in participant.audioTrackPublications) {
        if ((_allowedToTalk.contains(participant) &&
                localParticipantRole == Role.admin.toString()) ||
            role == Role.admin.toString()) {
               print('subscribing from audio track ganesh${participant.identity}');
          track.subscribe();
        } else {
          print('Unsubscribing from audio track ganesh${participant.identity}');
          track.unsubscribe();
        }
      }
    }
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
    _toggleParticipantForTalk(participant);
  }

  void _toggleRaiseHand(Participant participant, bool isHandRaised) async {
    // Create the metadata with the updated hand raise status
    final handRaiseData = jsonEncode(
        {'identity': participant?.identity, 'handraise': isHandRaised});

    // Publish the data to the room so that other participants can receive it
    await widget.room.localParticipant?.publishData(
      utf8.encode(handRaiseData),
    );

    _handleHandraiseUpdate(participant.identity, isHandRaised);
  }

  void _handleToggleRaiseHand(bool isHandRaised) async {
    _toggleRaiseHand(widget.room.localParticipant as Participant, isHandRaised);
  }

  Future<void> _copyInviteLinkToClipboard(BuildContext context) async {
    CopyInviteLinkDialog.show(context, widget.room.name!);
  }

  void _showHandRaiseNotification(
      BuildContext context, Participant participant) {
    HandRaiseNotification.show(context, participant, _allowSpeak);
  }

  Future<void> _showParticipantSelectionDialog(context) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      await showDialog(
        context: context,
        builder: (context) {
          return ParticipantSelectionDialog(
            participantTracks: participantTracks,
            allowedToTalk: _allowedToTalk,
            onToggleParticipantForTalk: _toggleParticipantForTalk,
            localParticipantIdentity:
                widget.room.localParticipant?.identity ?? '',
          );
        },
      );
    }
  }

  void _openEndDrawer() {
    // _initializeAllowedToTalk();
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final int numParticipants = participantTracks.length;
    final bool isMobile = screenWidth < 600;

    final int crossAxisCount = (isMobile && numParticipants == 2)
        ? 1
        : (numParticipants > 1)
            ? (screenWidth / (screenWidth / math.sqrt(numParticipants))).ceil()
            : 1;

    final int rowCount = (isMobile && numParticipants == 2)
        ? 2
        : (numParticipants / crossAxisCount).ceil();

    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        child: Stack(
          children: [
            ParticipantGridView(
              participantTracks: participantTracks,
              crossAxisCount: crossAxisCount,
              rowCount: rowCount,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
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
        allowedToTalk: _allowedToTalk,
        toggleParticipantForTalk: _toggleParticipantForTalk,
      ),
    );
  }
}
