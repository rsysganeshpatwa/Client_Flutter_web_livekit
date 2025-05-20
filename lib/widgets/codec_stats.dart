import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class CodecStatsDialog extends StatefulWidget {
  final Room room;
  final bool isAdmin;

  const CodecStatsDialog({
    super.key,
    required this.room,
    required this.isAdmin,

  });

  @override
  State<CodecStatsDialog> createState() => _CodecStatsDialogState();
}

class _CodecStatsDialogState extends State<CodecStatsDialog> {
  final Map<String, Map<String, dynamic>> _participantStats = {};
  final Map<String, String> localStats= {};
  final List<EventsListener<TrackEvent>> _listeners = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _isInitialized = false;
  bool showAllParticipants = true;


  @override
  void initState() {
    super.initState();
    _setupListeners();
    showAllParticipants = widget.isAdmin;

    // Add listener to search controller
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _clearListeners();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupListeners() {
    // Clear any existing listeners
    _clearListeners();

    // Initialize stats for local participant
    final localParticipant = widget.room.localParticipant;
    if (localParticipant != null) {
      _setupParticipantStats(localParticipant);
    }
    // Initialize stats for remote participants
    for (final participant in widget.room.remoteParticipants.values) {
      _setupParticipantStats(participant);
    }

    setState(() {
      _isInitialized = true;
    });
  }

  void _setupParticipantStats(Participant? participant) {
    if (participant == null) return;

    // Initialize stats structure for this participant
    final participantId = participant.identity;
    final name = participant.name.isNotEmpty ? participant.name : participantId;

    _participantStats[participantId] = {
      'name': name,
      'identity': participantId,
      'type': participant is LocalParticipant ? 'Local' : 'Remote',
      'connectionQuality': participant.connectionQuality.toString(),
      'video': {
        'sender': <String, dynamic>{},
        'receiver': <String, dynamic>{},
      },
      'audio': {
        'sender': <String, dynamic>{},
        'receiver': <String, dynamic>{},
      },
    };

    // Add track listeners for this participant
    for (final pub in [...participant.videoTrackPublications, ...participant.audioTrackPublications]) {
      if (pub.track != null) {
        _setupTrackListener(participant, pub.track!);
      }
    }
  }
  Future<void> _setupTrackListener(Participant participant, Track track) async {
    final listener = track.createListener();
    _listeners.add(listener);

    final participantId = participant.identity;

    if (track is LocalVideoTrack) {
     listener.on<VideoSenderStatsEvent>((event) {
  if (!mounted) return;

  final stats = event.stats;
 
  final selectedLayer = stats['f'] ?? stats['h'] ?? stats['q'];

  if (selectedLayer != null) {
    final resolution = '${selectedLayer.frameWidth}x${selectedLayer.frameHeight}';
  
    final fps = '${selectedLayer.framesPerSecond?.toDouble() ?? 0} fps';
    final codec = selectedLayer.mimeType != null
        ? '${selectedLayer.mimeType!.split('/')[1]}, ${selectedLayer.clockRate}hz'
        : 'Unknown';
    final encoderImplementation = selectedLayer.encoderImplementation ?? 'Unknown';
    final qualityLimitationReason = selectedLayer.qualityLimitationReason ?? 'None';
    final framesSent = selectedLayer.framesSent ?? 0;

    setState(() {
      _participantStats[participantId]?['video']['sender'] = {
        'bitrate': '${event.currentBitrate.toInt()} kbps',
        'resolution': resolution,
        'fps': fps,
        'codec': codec,
        'encoderImplementation': encoderImplementation,
        'qualityLimitationReason': qualityLimitationReason,
        'framesSent': framesSent,
      };
    });
  }
});

    } else if (track is RemoteVideoTrack) {
      listener.on<VideoReceiverStatsEvent>((event) {
        if (!mounted) return;
        setState(() {
          _participantStats[participantId]?['video']['receiver'] = {
            'bitrate': '${event.currentBitrate.toInt()} kbps',
            'resolution': '${event.stats.frameWidth}x${event.stats.frameHeight}',
            'fps': '${event.stats.framesPerSecond?.toDouble() ?? 0} fps',
            'jitter': '${event.stats.jitter} s',
            'packetsLost': event.stats.packetsLost.toString(),
            'packetsReceived': event.stats.packetsReceived.toString(),
            'framesReceived': event.stats.framesReceived.toString(),
            'framesDecoded': event.stats.framesDecoded.toString(),
            'framesDropped': event.stats.framesDropped.toString(),
            'decoderImplementation': event.stats.decoderImplementation ?? 'Unknown',
            'codec': event.stats.mimeType != null
                ? '${event.stats.mimeType!.split('/')[1]}, ${event.stats.clockRate}hz'
                : 'Unknown',
          };
        });
      });
    } else if (track is LocalAudioTrack) {
      listener.on<AudioSenderStatsEvent>((event) {
        if (!mounted) return;
        setState(() {
          _participantStats[participantId]?['audio']['sender'] = {
            'bitrate': '${event.currentBitrate.toInt()} kbps',
            'codec': event.stats.mimeType != null
                ? '${event.stats.mimeType!.split('/')[1]}, ${event.stats.clockRate}hz, ${event.stats.channels}ch'
                : 'Unknown',
            'payloadType': event.stats.payloadType.toString(),
            'packetsSent': event.stats.packetsSent.toString(),
          };
        });
      });
    } else if (track is RemoteAudioTrack) {
      listener.on<AudioReceiverStatsEvent>((event) {
        if (!mounted) return;
        setState(() {
          _participantStats[participantId]?['audio']['receiver'] = {
            'bitrate': '${event.currentBitrate.toInt()} kbps',
            'jitter': '${event.stats.jitter} s',
            'packetsLost': event.stats.packetsLost.toString(),
            'packetsReceived': event.stats.packetsReceived.toString(),
            'concealedSamples': event.stats.concealedSamples.toString(),
            'concealmentEvents': event.stats.concealmentEvents.toString(),
            'codec': event.stats.mimeType != null
                ? '${event.stats.mimeType!.split('/')[1]}, ${event.stats.clockRate}hz, ${event.stats.channels}ch'
                : 'Unknown',
            'payloadType': event.stats.payloadType.toString(),
          };
        });
      });
    }
  }

  void _clearListeners() {
    for (final listener in _listeners) {
      listener.dispose();
    }
    _listeners.clear();
  }

  List<String> _getFilteredParticipantIds() {
    if (_searchQuery.isEmpty) {
      return _participantStats.keys.toList();
    }

    return _participantStats.entries
        .where((entry) =>
            entry.key.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (entry.value['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()))
        .map((entry) => entry.key)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredParticipantIds = _getFilteredParticipantIds();

    // Use more neutral colors for the theme
    const Color backgroundColor = Colors.white;
    final Color cardBackgroundColor = Colors.grey.shade50;
    final Color borderColor = Colors.grey.shade200;
    final Color textColor = Colors.grey.shade800;
    final Color headerColor = Colors.grey.shade900;
    final Color accentColor = Colors.grey.shade700;

    return Dialog(
      backgroundColor: backgroundColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with improved contrast
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speed, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        'Connection Stats',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: headerColor,
                        ),
                      ),
                    ],
                  ),
                  if(widget.isAdmin) ...[
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: Icon(
                          showAllParticipants ? Icons.visibility_off : Icons.visibility,
                          color: accentColor,
                        ),
                        label: Text(
                          showAllParticipants ? 'Hide Remote' : 'Show Remote',
                          style: TextStyle(
                            color: accentColor,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            showAllParticipants = !showAllParticipants;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: accentColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.close, color: headerColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  ],
                ],
              ),
            ),

            // Search field - moved to top
            if (showAllParticipants) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintText: 'Search participants',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade500),
                    border: InputBorder.none,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade500),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                  style: TextStyle(fontSize: 14, color: textColor),
                ),
              ),
            ],

            const SizedBox(height: 16),

            if (!_isInitialized)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              // Make the entire content area scrollable with visible scrollbar
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thickness: 8,
                  radius: const Radius.circular(8),
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Local Participant Stats
                        _buildLocalParticipantCard(
                          filteredParticipantIds.firstWhere(
                            (id) => _participantStats[id]?['type'] == 'Local',
                            orElse: () => '',
                          ),
                          cardBackgroundColor,
                          borderColor,
                          textColor,
                          headerColor,
                          accentColor,
                        ),

                        // Remote Participants Section Header
                        if (showAllParticipants) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Remote Participants',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: headerColor,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Remote participants list with table layout
                          _buildRemoteParticipantsTable(
                            filteredParticipantIds
                                .where((id) => _participantStats[id]?['type'] == 'Remote')
                                .toList(),
                            cardBackgroundColor,
                            borderColor,
                            textColor,
                            headerColor,
                            accentColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalParticipantCard(
    String participantId,
    Color cardBackgroundColor,
    Color borderColor,
    Color textColor,
    Color headerColor,
    Color accentColor,
  ) {
    if (participantId.isEmpty) {
      return const SizedBox.shrink();
    }

    final stats = _participantStats[participantId]!;
    final videoStats = stats['video'] as Map<String, dynamic>;
    final audioStats = stats['audio'] as Map<String, dynamic>;
    final connectionQuality = stats['connectionQuality'] as String;

    Color participantAccentColor = accentColor;

    // Determine accent color based on connection quality
    if (connectionQuality == 'ConnectionQuality.excellent') {
      participantAccentColor = Colors.green.shade700;
    } else if (connectionQuality == 'ConnectionQuality.good') {
      participantAccentColor = Colors.amber.shade700;
    } else if (connectionQuality == 'ConnectionQuality.poor') {
      participantAccentColor = Colors.red.shade700;
    }

    // Fix for local video resolution showing null
    Map<String, dynamic> fixedVideoSenderStats = {};
    if ((videoStats['sender'] as Map<String, dynamic>).isNotEmpty) {
      // Create a copy of the video sender stats
      fixedVideoSenderStats = Map.from(videoStats['sender'] as Map<String, dynamic>);

      // Fix resolution if it contains "nullxnull"
      if (fixedVideoSenderStats['resolution'] == 'nullxnull' ||
          fixedVideoSenderStats['resolution'].toString().contains('null')) {
        // Try to get resolution from the local participant's video track
        final localVideoTrack = widget.room.localParticipant?.videoTrackPublications
            .where((pub) => pub.track != null)
            .map((pub) => pub.track!)
            .firstOrNull;

        if (localVideoTrack != null) {
          // Use current dimensions or a fallback value
          fixedVideoSenderStats['resolution'] =
             '...Detecting...'; // localVideoTrack.dimensions.toString();
         
        } else {
          fixedVideoSenderStats['resolution'] = 'Not available';
        }
      }
    }

    return Card(
      elevation: 1,
      color: cardBackgroundColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor),
      ),
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: participantAccentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Local Participant (You)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildConnectionQualityIndicator(connectionQuality),
              ],
            ),
            Divider(color: borderColor),

            // Stats in a grid layout for better space utilization
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Audio column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.mic, color: participantAccentColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Audio',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: headerColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if ((audioStats['sender'] as Map<String, dynamic>).isEmpty &&
                            (audioStats['receiver'] as Map<String, dynamic>).isEmpty)
                          Text(
                            'No audio stats available',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((audioStats['sender'] as Map<String, dynamic>).isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Text(
                                    'Upload Stats',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildStatsTable(audioStats['sender'] as Map<String, dynamic>, textColor),
                                const SizedBox(height: 12),
                              ],

                              if ((audioStats['receiver'] as Map<String, dynamic>).isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Text(
                                    'Download Stats',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildStatsTable(audioStats['receiver'] as Map<String, dynamic>, textColor),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Vertical divider between columns
                  VerticalDivider(
                    width: 32,
                    thickness: 1,
                    color: borderColor,
                  ),

                  // Video column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.videocam, color: participantAccentColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Video',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: headerColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (fixedVideoSenderStats.isEmpty &&
                            (videoStats['receiver'] as Map<String, dynamic>).isEmpty)
                          Text(
                            'No video stats available',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (fixedVideoSenderStats.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Text(
                                    'Upload Stats',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildStatsTable(fixedVideoSenderStats, textColor),
                                const SizedBox(height: 12),
                              ],

                              if ((videoStats['receiver'] as Map<String, dynamic>).isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Text(
                                    'Download Stats',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildStatsTable(videoStats['receiver'] as Map<String, dynamic>, textColor),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteParticipantsTable(
    List<String> participantIds,
    Color cardBackgroundColor,
    Color borderColor,
    Color textColor,
    Color headerColor,
    Color accentColor,
  ) {
    if (participantIds.isEmpty) {
      return Center(
        child: Card(
          elevation: 0,
          color: cardBackgroundColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No remote participants connected'
                      : 'No participants match your search',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: participantIds.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final participantId = participantIds[index];
        final stats = _participantStats[participantId]!;
        final name = stats['name'] as String;
        final videoStats = stats['video'] as Map<String, dynamic>;
        final audioStats = stats['audio'] as Map<String, dynamic>;
        final connectionQuality = stats['connectionQuality'] as String;

        Color participantAccentColor = accentColor;

        // Determine accent color based on connection quality
        if (connectionQuality == 'ConnectionQuality.excellent') {
          participantAccentColor = Colors.green.shade700;
        } else if (connectionQuality == 'ConnectionQuality.good') {
          participantAccentColor = Colors.amber.shade700;
        } else if (connectionQuality == 'ConnectionQuality.poor') {
          participantAccentColor = Colors.red.shade700;
        }

        // Ensure we always show audio and video sections for remote participants
        bool hasAudioStats = (audioStats['receiver'] as Map<String, dynamic>).isNotEmpty ||
            (audioStats['sender'] as Map<String, dynamic>).isNotEmpty;

        bool hasVideoStats = (videoStats['receiver'] as Map<String, dynamic>).isNotEmpty ||
            (videoStats['sender'] as Map<String, dynamic>).isNotEmpty;

        return Card(
          elevation: 1,
          color: cardBackgroundColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, color: participantAccentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: headerColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildConnectionQualityIndicator(connectionQuality),
                  ],
                ),
                Divider(color: borderColor),

                // Stats in a grid layout for better space utilization
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Audio column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.mic, color: participantAccentColor, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Audio',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: headerColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (!hasAudioStats)
                              Text(
                                'No audio stats available',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if ((audioStats['sender'] as Map<String, dynamic>).isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Text(
                                        'Upload Stats',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildStatsTable(audioStats['sender'] as Map<String, dynamic>, textColor),
                                    const SizedBox(height: 12),
                                  ],

                                  if ((audioStats['receiver'] as Map<String, dynamic>).isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Text(
                                        'Download Stats',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildStatsTable(audioStats['receiver'] as Map<String, dynamic>, textColor),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),

                      // Vertical divider between columns
                      VerticalDivider(
                        width: 32,
                        thickness: 1,
                        color: borderColor,
                      ),

                      // Video column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.videocam, color: participantAccentColor, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Video',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: headerColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (!hasVideoStats)
                              Text(
                                'No video stats available',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if ((videoStats['sender'] as Map<String, dynamic>).isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Text(
                                        'Upload Stats',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildStatsTable(videoStats['sender'] as Map<String, dynamic>, textColor),
                                    const SizedBox(height: 12),
                                  ],

                                  if ((videoStats['receiver'] as Map<String, dynamic>).isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Text(
                                        'Download Stats',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildStatsTable(videoStats['receiver'] as Map<String, dynamic>, textColor),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTable(Map<String, dynamic> stats, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(1.8),
        },
        children: stats.entries.map((entry) {
          return TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100, width: 0.5),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  _formatKey(entry.key),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  '${entry.value}',
                  style: TextStyle(color: textColor),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConnectionQualityIndicator(String quality) {
    Color color;
    IconData icon;
    String displayText = quality.replaceAll('ConnectionQuality.', '');

    switch (quality) {
      case 'ConnectionQuality.excellent':
        color = Colors.green.shade700;
        icon = Icons.network_wifi;
        break;
      case 'ConnectionQuality.good':
        color = Colors.amber.shade700;
        icon = Icons.network_wifi;
        break;
      case 'ConnectionQuality.poor':
        color = Colors.red.shade700;
        icon = Icons.signal_wifi_statusbar_connected_no_internet_4;
        break;
      default:
        color = Colors.grey.shade700;
        icon = Icons.signal_wifi_off;
        displayText = 'unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    // Convert camelCase to Title Case with spaces
    final result = key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    );
    return result.substring(0, 1).toUpperCase() + result.substring(1);
  }

}
