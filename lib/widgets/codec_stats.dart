import 'package:flutter/material.dart';
import '../stats_repo.dart';
import 'dart:async';

class CodecStatsDialog extends StatefulWidget {
  final Map<String, String> stats;
  final bool isVideoOn; // New parameter for video status

  const CodecStatsDialog({
    Key? key,
    required this.stats,
    required this.isVideoOn, // Require this parameter
  }) : super(key: key);

  @override
  _CodecStatsDialogState createState() => _CodecStatsDialogState();
}

class _CodecStatsDialogState extends State<CodecStatsDialog> {
  late Map<String, String> stats;
  bool _isCodecStatsActive = true;

  @override
  void initState() {
    super.initState();
    stats = widget.stats;
    _updateStatsPeriodically(); // Start periodic updates
  }

  // Function to simulate periodic updates
  void _updateStatsPeriodically() async {
    while (_isCodecStatsActive) {
      await Future.delayed(Duration.zero);
      if (mounted) {
        setState(() {
          // Update the stats here
          stats = StatsRepository().stats;
        });
      }
    }
  }

  @override
  void dispose() {
    _isCodecStatsActive = false; // Stop updates when the dialog is closed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.all(10),
      child: SizedBox(
        width: 400, // Fixed width
        height: 350, // Fixed height
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Text(
                        'Codec Stats',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    // Check if video is on but no stats are available
                    if (widget.isVideoOn && stats.isEmpty)
                      Center(
                        child: Text(
                          'Wait, fetching codec information...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if(
                      // Check if video is off and no stats are available
                      !widget.isVideoOn && stats.isEmpty)
                      Center(
                        child: Text(
                          'Video/Audio is off',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )

                    else
                      // Display stats if available
                      ...stats.entries.map((entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(color: Colors.black, fontSize: 16),
                                children: [
                                  TextSpan(
                                    text: '${entry.key} : ',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: '${entry.value}',
                                    style: TextStyle(fontWeight: FontWeight.normal),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )),
                    SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                icon: Icon(Icons.close),
                color: Colors.black,
                onPressed: () {
                  _isCodecStatsActive = false;
                  Navigator.of(context).pop(); // Close the dialog
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
