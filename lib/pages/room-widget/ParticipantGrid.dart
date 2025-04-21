import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_meeting_room/models/room_models.dart';
import 'package:video_meeting_room/service_locator.dart';
import 'package:video_meeting_room/services/textract_service.dart'; // Import your service
import 'package:video_meeting_room/utils.dart';
import 'package:video_meeting_room/widgets/participant.dart';
import 'package:video_meeting_room/widgets/participant_info.dart';


class ParticipantGrid extends StatefulWidget {
  final List<ParticipantTrack> participantTracks;
  final double gridWidth;
  final double gridHeight;
  final List<ParticipantStatus> participantStatuses;
  final bool isLocalHost;
  final Function(List<ParticipantStatus>) onParticipantsStatusChanged;

  ParticipantGrid({
    Key? key,
    required this.participantTracks,
    required this.gridWidth,
    required this.gridHeight,
    required this.participantStatuses,
    required this.isLocalHost,
    required this.onParticipantsStatusChanged,
  }) : super(key: key);

  @override
  _ParticipantGridState createState() => _ParticipantGridState();
}

class _ParticipantGridState extends State<ParticipantGrid> {
  final TextractService _textractService = getIt<TextractService>(); // Get the service instance
  String extractedText = '';

  Future<void> _onParticipantTap(BuildContext context, ParticipantTrack participantTrack) async {
    // Capture a frame from the video
    final track = participantTrack.participant.videoTrackPublications.first.track as Track;
    final byteBufferImage = await track.mediaStreamTrack.captureFrame();

    // Convert ByteBuffer to Uint8List
    final uint8List = byteBufferImage.asUint8List();

    // Show loading dialog
    final loadingDialog = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              const Text("Extracting text...", style: TextStyle(color: Colors.black)),
            ],
          ),
        );
      },
    );

    try {
      String text = await _textractService.extractText(uint8List);
      extractedText = text; // Store extracted text
      Navigator.of(context).pop(); // Close loading dialog
      _showResultDialog(context, extractedText, uint8List);
    } catch (e) {
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
  
void _showResultDialog(BuildContext context, String resultText, Uint8List imageBytes) {
  // Clean up the resultText by ensuring \n is properly handled
  String cleanedText = jsonDecode(resultText)['text'].replaceAll(RegExp(r'\\n'), '\n');  // Extract text and replace escaped \n with actual newlines

  showDialog(
    context: context,
    barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.white, // Set background color to white
        child: Container(
          width: MediaQuery.of(context).size.width * 0.5, // Width 90% of screen width
          height: MediaQuery.of(context).size.height * 0.8, // Height 80% of screen height
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top-left close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black, size: 28),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "OCR Result",
                style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
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
                    controller: TextEditingController(text: cleanedText.isEmpty ? 'No Text Found !' :cleanedText ), // Use cleaned text
                    style: const TextStyle(color: Colors.black),
                    maxLines: null, // Allow the TextField to expand for all lines
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
                        const SnackBar(content: Text("Text copied to clipboard")),
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
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", "downloaded_image.png") // Set the filename
    ..click(); // Trigger the download by simulating a click

  // Clean up the URL object after download
  html.Url.revokeObjectUrl(url);
}
  

 void _handlePinAndSpotlightStatusChanged(ParticipantStatus status) {
    // Update the participant status
    List<ParticipantStatus> updatedStatuses = updateSpotlightStatus(
      participantList: widget.participantStatuses,
      updatedStatus: status,
    );

    // Call the callback function with the updated statuses
    widget.onParticipantsStatusChanged(updatedStatuses);
  }



  @override
 @override
Widget build(BuildContext context) {
  final bool isMobile = widget.gridWidth < 600;
  final int numParticipants = widget.participantTracks.length;
  final bool isLocalHost = widget.isLocalHost;
  print("is grid localhost: $isLocalHost");

  if (numParticipants == 0) {
    return const Center(
      child: Text(
        "No participants",
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  final int estimatedCrossAxis = (isMobile && numParticipants == 2)
      ? 1
      : (numParticipants > 1)
          ? (widget.gridWidth /
                  (widget.gridWidth / math.sqrt(numParticipants)))
              .ceil()
          : 1;

  final int safeCrossAxisCount = estimatedCrossAxis > 0 ? estimatedCrossAxis : 1;
  final int rows = (numParticipants / safeCrossAxisCount).ceil();
  final double safeGridHeight = widget.gridHeight > 0 ? widget.gridHeight : 1;
  final double aspectRatio = (widget.gridWidth / safeCrossAxisCount) /
      (safeGridHeight / (rows > 0 ? rows : 1));
  final double safeAspectRatio = aspectRatio > 0 ? aspectRatio : 1.0;

  return GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: safeCrossAxisCount,
      childAspectRatio: safeAspectRatio,
      crossAxisSpacing: 12.0,
      mainAxisSpacing: 12.0,
    ),
    itemCount: numParticipants,
    itemBuilder: (context, index) {
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

      return GestureDetector(
        onTap: () {
          // Uncomment to handle OCR/tap event
          // _onParticipantTap(context, track);
        },
        child: Card(
          elevation: 4.0,
          child: Column(
            children: [
              Expanded(
                child: ParticipantWidget.widgetFor(
                  track,
                  status,
                  showStatsLayer: false,
                  participantIndex: index,
                  handleExtractText: widget.isLocalHost
                      ? () {
                          print('Extracting text...');
                          _onParticipantTap(context, track);
                        }
                      : null,
                  onParticipantsStatusChanged: _handlePinAndSpotlightStatusChanged,
                  isLocalHost: isLocalHost
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  @override
  void dispose() {
    super.dispose();
  }
}
