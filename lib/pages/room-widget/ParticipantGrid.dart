// ignore_for_file: file_names

import 'dart:convert';
import 'dart:math' as math;
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/service_locator.dart';
import 'package:video_meeting_room/services/textract_service.dart'; // Import your service

import 'package:video_meeting_room/widgets/participant_info.dart';
import 'package:video_meeting_room/widgets/MemoizedParticipantCard.dart';

class ParticipantGrid extends StatefulWidget {
  final List<ParticipantTrack> participantTracks;
  final double gridWidth;
  final double gridHeight;
  final List<ParticipantStatus> participantStatuses;
  final bool isLocalHost;
  final Function(ParticipantStatus) onParticipantsStatusChanged;
  final List<ParticipantStatus> handRaisedList;
  final int gridSize; // Add this parameter

  const ParticipantGrid({
    super.key,
    required this.participantTracks,
    required this.gridWidth,
    required this.gridHeight,
    required this.participantStatuses,
    required this.handRaisedList,
    required this.isLocalHost,
    required this.onParticipantsStatusChanged,
    required this.gridSize, // Add to constructor
  });

  @override
  // ignore: library_private_types_in_public_api
  _ParticipantGridState createState() => _ParticipantGridState();
}

class _ParticipantGridState extends State<ParticipantGrid> {

  // Initialize the TextractService
  final TextractService _textractService =
      getIt<TextractService>(); // Get the service instance
  String extractedText = '';

  Future<void> _onParticipantTap(
      BuildContext context, ParticipantTrack participantTrack) async {
    // Capture a frame from the video

    if (!participantTrack.participant.isCameraEnabled()) {
      // Handle the case where there are no video tracks
      _showErrorDialog(
          context, "No video track available for this participant.");
      return;
    }
    final track = participantTrack
        .participant.videoTrackPublications.first.track as Track;
    final byteBufferImage = await track.mediaStreamTrack.captureFrame();

    // Convert ByteBuffer to Uint8List
    final uint8List = byteBufferImage.asUint8List();

    showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          backgroundColor: Colors.white,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Extracting text...", style: TextStyle(color: Colors.black)),
            ],
          ),
        );
      },
    );

    try {
      String text = await _textractService.extractText(uint8List);
      extractedText = text; // Store extracted text
      if (!mounted || !context.mounted) return;

      Navigator.of(context).pop(); // Close loading dialog
      _showResultDialog(context, extractedText, uint8List);
    } catch (e) {
      if (!mounted || !context.mounted) return;

      Navigator.of(context).pop(); // Close loading dialog
      _showErrorDialog(context, e.toString());
    }
  }

  void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showResultDialog(
      BuildContext context, String resultText, Uint8List imageBytes) {
    // Clean up the resultText by ensuring \n is properly handled
    String cleanedText = jsonDecode(resultText)['text'].replaceAll(
        RegExp(r'\\n'),
        '\n'); // Extract text and replace escaped \n with actual newlines

    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevent dismissing the dialog by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white, // Set background color to white
          child: Container(
            width: MediaQuery.of(context).size.width *
                0.5, // Width 90% of screen width
            height: MediaQuery.of(context).size.height *
                0.8, // Height 80% of screen height
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top-left close button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.black, size: 28),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "OCR Result",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                // Scrollable area for the extracted text
                Expanded(
                  child: SingleChildScrollView(
                    clipBehavior: Clip.antiAlias,
                    child: TextField(
                      readOnly: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      controller: TextEditingController(
                          text: cleanedText.isEmpty
                              ? 'No Text Found !'
                              : cleanedText), // Use cleaned text
                      style: const TextStyle(color: Colors.black),
                      maxLines:
                          null, // Allow the TextField to expand for all lines
                      minLines: 5, // Minimum height of the text field
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Row for the Copy and Download buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Copy text to clipboard
                        Clipboard.setData(ClipboardData(text: cleanedText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Text copied to clipboard")),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Download the original image
                        _downloadOriginalImage(imageBytes);
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Download Image'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Function to download original image using Anchor for Flutter Web
  void _downloadOriginalImage(Uint8List imageBytes) {
    // Create a Blob from the Uint8List image bytes
    final blob = html.Blob([imageBytes]);

    // Create a URL for the Blob
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Create an anchor element
    html.AnchorElement(href: url)
      ..setAttribute("download", "downloaded_image.png") // Set the filename
      ..click(); // Trigger the download by simulating a click

    // Clean up the URL object after download
    html.Url.revokeObjectUrl(url);
  }

  int _getRaisehandIndexByStatusTimestamp(
    String identity,
  ) {
    // Filter and sort by timestamp
    final sorted = widget.handRaisedList
        .where((p) => p.isHandRaised)
        .toList()
      ..sort((a, b) => a.handRaisedTimeStamp.compareTo(b.handRaisedTimeStamp));

    // Get the index
    final index = sorted.indexWhere((p) => p.identity == identity);
    return index >= 0 ? index + 1 : -1; // return 1-based index, -1 if not found
  }

  Widget _buildParticipantWidget(int index, double width, double height) {
    final track = widget.participantTracks[index];
    final status = widget.participantStatuses.firstWhere(
      (s) => s.identity == track.participant.identity,
      orElse: () => ParticipantStatus(
        identity: '',
        isAudioEnable: false,
        isVideoEnable: false,
        isHandRaised: false,
        isTalkToHostEnable: false,
      ),
    );
    final handRaisedIndex = _getRaisehandIndexByStatusTimestamp(
      track.participant.identity,
    );
    return MemoizedParticipantCard(
      key: ValueKey(track.participant.sid),
      track: track,
      status: status,
      index: handRaisedIndex,
      isLocalHost: widget.isLocalHost,
      width: width,
      height: height,
      onParticipantsStatusChanged: widget.onParticipantsStatusChanged,
      onTap: widget.isLocalHost
          ? () => _onParticipantTap(context, track)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final numParticipants = widget.participantTracks.length;
   
    return Container(
      width: widget.gridWidth,
      height: widget.gridHeight,
      color: Colors.transparent,
      child: widget.gridSize == 4
          ? (numParticipants <= 1
              ? _buildSingleParticipant()
              : numParticipants <= 2
                  ? _buildTwoParticipants()
                  : _buildFourParticipants())
          : (numParticipants <= 1
              ? _buildSingleParticipant()
              : numParticipants <= 2
                  ? _buildTwoParticipants()
                  : numParticipants <= 4
                      ? _buildFourParticipants()
                      : numParticipants <= 6
                          ? _buildSixParticipants()
                          : _buildEightParticipants()),
    );
  }

  Widget _buildSingleParticipant() {
    return _buildParticipantWidget(0, widget.gridWidth, widget.gridHeight);
  }

  Widget _buildTwoParticipants() {
    return Row(
      children: [
        SizedBox(
          width: widget.gridWidth / 2,
          height: widget.gridHeight,
          child: _buildParticipantWidget(0, widget.gridWidth / 2, widget.gridHeight),
        ),
        SizedBox(
          width: widget.gridWidth / 2,
          height: widget.gridHeight,
          child: _buildParticipantWidget(1, widget.gridWidth / 2, widget.gridHeight),
        ),
      ],
    );
  }

  Widget _buildFourParticipants() {
    return Column(
      children: [
        SizedBox(
          height: widget.gridHeight / 2,
          child: Row(
            children: [
              SizedBox(
                width: widget.gridWidth / 2,
                height: widget.gridHeight / 2,
                child: _buildParticipantWidget(0, widget.gridWidth / 2, widget.gridHeight / 2),
              ),
              SizedBox(
                width: widget.gridWidth / 2,
                height: widget.gridHeight / 2,
                child: _buildParticipantWidget(1, widget.gridWidth / 2, widget.gridHeight / 2),
              ),
            ],
          ),
        ),
        SizedBox(
          height: widget.gridHeight / 2,
          child: Row(
            children: [
              SizedBox(
                width: widget.gridWidth / 2,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 2
                    ? _buildParticipantWidget(2, widget.gridWidth / 2, widget.gridHeight / 2)
                    : Container(),
              ),
              SizedBox(
                width: widget.gridWidth / 2,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 3
                    ? _buildParticipantWidget(3, widget.gridWidth / 2, widget.gridHeight / 2)
                    : Container(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Add support for 6 participants (3x2 grid)
  Widget _buildSixParticipants() {
    return Column(
      children: [
        SizedBox(
          height: widget.gridHeight / 2,
          child: Row(
            children: [
              SizedBox(
                width: widget.gridWidth / 3,
                height: widget.gridHeight / 2,
                child: _buildParticipantWidget(0, widget.gridWidth / 3, widget.gridHeight / 2),
              ),
              SizedBox(
                width: widget.gridWidth / 3,
                height: widget.gridHeight / 2,
                child: _buildParticipantWidget(1, widget.gridWidth / 3, widget.gridHeight / 2),
              ),
              SizedBox(
                width: widget.gridWidth / 3,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 2
                    ? _buildParticipantWidget(2, widget.gridWidth / 3, widget.gridHeight / 2)
                    : Container(),
              ),
            ],
          ),
        ),
        SizedBox(
          height: widget.gridHeight / 2,
          child: Row(
            children: [
              SizedBox(
                width: widget.gridWidth / 3,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 3
                    ? _buildParticipantWidget(3, widget.gridWidth / 3, widget.gridHeight / 2)
                    : Container(),
              ),
              SizedBox(
                width: widget.gridWidth / 3,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 4
                    ? _buildParticipantWidget(4, widget.gridWidth / 3, widget.gridHeight / 2)
                    : Container(),
              ),
              SizedBox(
                width: widget.gridWidth / 3,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 5
                    ? _buildParticipantWidget(5, widget.gridWidth / 3, widget.gridHeight / 2)
                    : Container(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Add support for 8 participants (4x2 grid)
  Widget _buildEightParticipants() {
    return Column(
      children: [
        SizedBox(
          height: widget.gridHeight / 2,
          child: Row(
            children: [
              SizedBox(
                width: widget.gridWidth / 4,
                height: widget.gridHeight / 2,
                child: _buildParticipantWidget(0, widget.gridWidth / 4, widget.gridHeight / 2),
              ),
              SizedBox(
                width: widget.gridWidth / 4,
                height: widget.gridHeight / 2,
                child: _buildParticipantWidget(1, widget.gridWidth / 4, widget.gridHeight / 2),
              ),
              SizedBox(
                width: widget.gridWidth / 4,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 2
                    ? _buildParticipantWidget(2, widget.gridWidth / 4, widget.gridHeight / 2)
                    : Container(),
              ),
              SizedBox(
                width: widget.gridWidth / 4,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 3
                    ? _buildParticipantWidget(3, widget.gridWidth / 4, widget.gridHeight / 2)
                    : Container(),
              ),
            ],
          ),
        ),
        SizedBox(
          height: widget.gridHeight / 2,
          child: Row(
            children: [
              SizedBox(
                width: widget.gridWidth / 4,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 4
                    ? _buildParticipantWidget(4, widget.gridWidth / 4, widget.gridHeight / 2)
                    : Container(),
              ),
              SizedBox(
                width: widget.gridWidth / 4,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 5
                    ? _buildParticipantWidget(5, widget.gridWidth / 4, widget.gridHeight / 2)
                    : Container(),
              ),
              SizedBox(
                width: widget.gridWidth / 4,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 6
                    ? _buildParticipantWidget(6, widget.gridWidth / 4, widget.gridHeight / 2)
                    : Container(),
              ),
              SizedBox(
                width: widget.gridWidth / 4,
                height: widget.gridHeight / 2,
                child: widget.participantTracks.length > 7
                    ? _buildParticipantWidget(7, widget.gridWidth / 4, widget.gridHeight / 2)
                    : Container(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Dispose of any resources if needed
    super.dispose();
  }
}
