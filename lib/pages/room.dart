import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/method_channels/replay_kit_channel.dart';
import 'package:video_meeting_room/pages/connect.dart';

import '../exts.dart';
import '../utils.dart';
import '../widgets/controls.dart';
import '../widgets/participant.dart';
import '../widgets/participant_info.dart';

enum Role {
  admin,
  participant,
}

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
  bool _muteAll = false;
  Set<Participant> _allowedToTalk = {}; // Track participants allowed to talk
  Participant? _activeParticipant;
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
    ..on<TrackE2EEStateEvent>(_onE2EEStateEvent)
    ..on<ParticipantNameUpdatedEvent>((event) {
      // print(
      //     'Participant name updated: ${event.participant.identity}, name => ${event.name}');
      _sortParticipants();
    })
    ..on<ParticipantAttributesChanged>((event) {
      print(
          'Participant metadata updated: ${event.participant.identity}, metadata => ${event.attributes}');
    })
    ..on<RoomMetadataChangedEvent>((event) {
      print('Room metadata changed: ${event.metadata}');
    })
    ..on<DataReceivedEvent>((event) {
      String decoded = 'Failed to decode';
      try {
        decoded = utf8.decode(event.data);
        print('Data received: $decoded');
        _receviedMetadata(event);
      } catch (_) {
        print('Failed to decode: $_');
      }

      // context.showDataReceivedDialog(decoded);
    })
    ..on<AudioPlaybackStatusChanged>((event) async {
      if (!widget.room.canPlaybackAudio) {
        print('Audio playback failed for iOS Safari ..........');
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

  void _onE2EEStateEvent(TrackE2EEStateEvent e2eeState) {
    // print('e2ee state: $e2eeState');
  }
  Future<void> _updateMetadata() async {
    // Broadcast the updated list to all participants
    final allowedToTalkIdentities =
        _allowedToTalk.map((p) => p.identity).toList();
    final dataMessage = jsonEncode({'allowedToTalk': allowedToTalkIdentities});
    await widget.room.localParticipant?.publishData(utf8.encode(dataMessage));
    print('Updated metadata: $dataMessage');
  }

  void _receviedMetadata(DataReceivedEvent event) {
    try {
      final decodedData = utf8.decode(event.data);
      final data = jsonDecode(decodedData) as Map<String, dynamic>;
      print('Received metadata: $data');
      if (data.containsKey('allowedToTalk')) {
        setState(() {
          final allowedIdentities = data['allowedToTalk'] as List<dynamic>;
          _allowedToTalk = widget.room.remoteParticipants.values
              .where((p) => allowedIdentities.contains(p.identity))
              .toSet();
            _updateAudioSubscriptions();
        });
      
      }
    } catch (e) {
      print('Failed to parse metadata: $e');
    }
  }

  void _manageAudioSubscriptions() {
    final localParticipant = widget.room.localParticipant;
    bool isHost =
        localParticipant != null && localParticipant.identity == "Host";

    for (var participant in widget.room.remoteParticipants.values) {
      for (var track in participant.trackPublications.values) {
        if (isHost || participant.identity == "Host") {
          // Participants should hear only the host
          track.subscribe();
        } else {
          // Participants should not hear each other
          track.unsubscribe();
        }
      }
    }
  }

  void _sortParticipants() {
    List<ParticipantTrack> userMediaTracks = [];
    List<ParticipantTrack> screenTracks = [];
    final localParticipant = widget.room.localParticipant;

    bool isHost =
        localParticipant != null &&  localParticipantRole == Role.admin.toString();
    for (var participant in widget.room.remoteParticipants.values) {
        final metadata = participant.metadata;
      final remoteParticipantRole = metadata != null ? jsonDecode(metadata)['role'] : null;
      for (var t in participant.videoTrackPublications) {
        if (t.isScreenShare) {
          screenTracks.add(ParticipantTrack(
            participant: participant,
            type: ParticipantTrackType.kScreenShare,
          ));
        } else if (isHost || remoteParticipantRole == Role.admin.toString()) {

          userMediaTracks.add(ParticipantTrack(participant: participant));
        }
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

          userMediaTracks.add(
              ParticipantTrack(participant: widget.room.localParticipant!));
        }
      }
    }
    setState(() {
      participantTracks = [...screenTracks, ...userMediaTracks];
    });
  }

  Future<void> _copyInviteLinkToClipboard() async {
    final roomName = widget.room.name;
    String encodedRoomName = Uri.encodeComponent(roomName!);
    final inviteLink = 'https://${Uri.base.host}?room=$encodedRoomName';
    await Clipboard.setData(ClipboardData(text: inviteLink));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite link copied to clipboard')),
    );
  }

  void _setActiveParticipant(Participant participant) {
    setState(() {
      // Toggle selection of the participant
      if (_allowedToTalk.contains(participant)) {
        _allowedToTalk.remove(participant); // Remove if already in the list
      } else {
        _allowedToTalk.add(participant); // Add if not in the list
      }

      _activeParticipant = participant;
      _muteAll = false;

      // Call update functions to reflect changes
      _updateAudioSubscriptions();
      _updateMetadata();
    });
  }

  void _initializeAllowedToTalk() {
    setState(() {
      _allowedToTalk.clear(); // Clear the current set

      final localParticipant = widget.room.localParticipant;
      if (localParticipantRole == Role.admin.toString()) {
        _allowedToTalk.add(localParticipant as Participant);
      }
    

      // Add remote participants based on their role or track subscription status
      for (var participant in widget.room.remoteParticipants.values) {

        if (localParticipantRole == Role.admin.toString()) {
          // Always add admin to _allowedToTalk
          _allowedToTalk.add(participant);
        } else {
          // Add only if any audio track is subscribed
          
          for (var track in participant.audioTrackPublications) {
            if (track.subscribed ) {
              _allowedToTalk.add(participant);
              break; // Add participant only once, no need to check other tracks
            }
          }
        }
      }
    });
  }

  void _toggleParticipantForTalk(Participant participant) {
    setState(() {
      if (_allowedToTalk.contains(participant)) {
        _allowedToTalk.remove(participant);
      } else {
        _allowedToTalk.add(participant);
      }
      _updateAudioSubscriptions();
      _updateMetadata();
    });
  }

  void _toggleMuteAll(bool muteAll) {
    setState(() {
      _muteAll = muteAll;
      _allowedToTalk.clear(); // Clear the current set
      print( 'meta Mute all: $muteAll');
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
      _updateMetadata();
    });
  }

  void _trackSubscribed(TrackSubscribedEvent event) {
    final participant = event.participant;
    setState(() {
      if (!_allowedToTalk.contains(participant)) {
        _allowedToTalk.add(participant);
      }
      _updateAudioSubscriptions(); // Update audio subscriptions
    });
  }

  void _trackUnsubscribed(TrackUnsubscribedEvent event) {
    final participant = event.participant;

    setState(() {
      if (_allowedToTalk.contains(participant) &&
          localParticipantRole != Role.admin.toString()) {
        _allowedToTalk.remove(participant);
      }

      _updateAudioSubscriptions(); // Update audio subscriptions
    });
  }

  void _updateAudioSubscriptions() {
    if(localParticipantRole == Role.admin.toString() && !_allowedToTalk.contains(widget.room.localParticipant!)){
      _allowedToTalk.add(widget.room.localParticipant!);
    }

    final remote = widget.room.remoteParticipants.values;
    print('Allowed to talk meta: $_allowedToTalk');
   print('Remote participants meta: $remote');
    for (var participant in widget.room.remoteParticipants.values) {
       final metadata = participant.metadata;
      final role = metadata != null ? jsonDecode(metadata)['role'] : null;
      for (var track in participant.audioTrackPublications) {
        if (_allowedToTalk.contains(participant) && localParticipantRole ==Role.admin.toString() || role == Role.admin.toString()) {
          track.subscribe();
        } else {
          track.unsubscribe();
        }
      }
    }
  }

  Future<void> _showParticipantSelectionDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      //  _initializeAllowedToTalk();
      await showDialog(
        context: context,
        builder: (context) {
          // Use StatefulBuilder to rebuild the dialog when state changes
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('Select Participants'),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: participantTracks.map((track) {
                      return ListTile(
                        title: Text(
                          track.participant.identity ?? 'Unknown',
                          style: TextStyle(color: Colors.white),
                        ),
                        trailing: Checkbox(
                          value: _allowedToTalk.contains(track.participant),
                          onChanged: (value) {
                            setState(() {
                              _toggleParticipantForTalk(track.participant);
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            _toggleParticipantForTalk(track.participant);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                    },
                    child: Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
    } else {
      // Implement side panel for larger screens if needed
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
            Column(
              children: [
                Expanded(
                  child: participantTracks.isNotEmpty
                      ? GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 4.0,
                            mainAxisSpacing: 4.0,
                            childAspectRatio: (screenWidth / crossAxisCount) /
                                (screenHeight / rowCount),
                          ),
                          itemCount: numParticipants,
                          itemBuilder: (context, index) {
                            final participant =
                                participantTracks[index].participant;
                          
                            return GestureDetector(
                              onTap: () => _setActiveParticipant(participant),
                              child: Container(
                      
                                child: ParticipantWidget.widgetFor(
                                  participantTracks[index],
                                  showStatsLayer: false,
                                  
                                ),
                              ),
                            );
                          },
                        )
                      : Container(),
                ),
              ],
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
                    localParticipantRole,
                    widget.room,
                    widget.room.localParticipant!,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _copyInviteLinkToClipboard,
            child: Icon(Icons.link),
            tooltip: 'Copy invite link',
          ),
          SizedBox(height: 16),
          if (localParticipantRole == Role.admin.toString())
            FloatingActionButton(
              onPressed: () {
                if (isMobile) {
                  _showParticipantSelectionDialog(); // Show dialog for mobile devices
                } else {
                  _openEndDrawer(); // Open side panel for larger screens
                }
              },
              child: Icon(Icons.people),
              tooltip: 'Manage Participants',
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      endDrawer: Drawer(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search participants',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
              ),
            ),
            Expanded(
              child: ListView(
                children: _filterParticipants(searchQuery).map((track) {
                  final isLocal =
                      track.participant == widget.room.localParticipant;
                  final participantName = track.participant.name ?? 'Unknown';
                  final displayName =
                      isLocal ? '$participantName (you)' : participantName;

                  return ListTile(
                    title: Text(displayName),
                    trailing: isLocal
                        ? null
                        : Checkbox(
                            value: _allowedToTalk.contains(track.participant),
                            onChanged: (value) {
                              _toggleParticipantForTalk(track.participant);
                            },
                          ),
                    onTap: isLocal
                        ? null
                        : () {
                            _toggleParticipantForTalk(track.participant);
                          },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
