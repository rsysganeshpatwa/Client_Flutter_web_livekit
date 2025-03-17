import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_meeting_room/utils.dart';
import 'package:video_meeting_room/app_config.dart';

const String apiServiceUrl = AppConfig.apiNodeUrl; //dotenv.env['API_NODE_URL']! ;
 
class LiveKitIngressPage extends StatefulWidget {
  @override
  _LiveKitIngressPageState createState() => _LiveKitIngressPageState();
}
 
class _LiveKitIngressPageState extends State<LiveKitIngressPage> {
  List<Map<String, dynamic>> ingressList = [];
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _streamerNameController =
      TextEditingController(text: "Streamer");
 
  @override
  void initState() {
    super.initState();
    fetchIngressList();
  }
 
  Future<void> fetchIngressList() async {
    final response = await http.get(
      Uri.parse('$apiServiceUrl/ingress/get-streams'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      setState(() {
        ingressList =
            List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    }
  }
 
  Future<void> createIngress() async {
    final response = await http.post(
      Uri.parse('$apiServiceUrl/ingress/post-stream'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "name": "My RTMP Ingress",
        "input_type": "RTMP_INPUT",
        "roomName": _roomNameController.text,
        "participant_identity": "streamer",
        "participant_name": _streamerNameController.text
      }),
    );
    if (response.statusCode == 200) {
      fetchIngressList();
    }
  }

  Future<void> deleteIngress(String roomName) async {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Stream"),
          content: Text("Are you sure you want to delete the stream for room '$roomName'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ) ?? false;
    
    if (!confirmDelete) return;
    
    try {
      final response = await http.delete(
        Uri.parse('$apiServiceUrl/ingress/delete-stream/$roomName'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Stream deleted successfully"),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the list
        fetchIngressList();
      } else {
        // Show error message
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${errorData['message'] ?? 'Unknown error'}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
 
  void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Copied to clipboard")),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;
 
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 217, 219, 221),
      body: Center(
        child: isMobile
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: buildMainContent(screenWidth, screenHeight),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: buildMainContent(screenWidth, screenHeight),
              ),
      ),
    );
  }
 
  List<Widget> buildMainContent(double screenWidth, double screenHeight) {
    return [
      // Left Panel (Logo & Info)
      Container(
        width: screenWidth * 0.2,
        height: screenHeight * 0.7,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 39, 38, 104),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.all(screenHeight * 0.02),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'images/Rsi_logo.png',
              semanticLabel: 'Rsilogo',
              height: screenHeight * 0.07,
            ),
            SizedBox(height: screenHeight * 0.15),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Welcome to R Systems video conferencing solution',
                style: TextStyle(
                  fontSize: screenHeight * 0.02,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      // Right Panel (Form & Stream List)
      Container(
        width: screenWidth * 0.4,
        height: screenHeight * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.all(screenHeight * 0.02),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _roomNameController,
              decoration: InputDecoration(labelText: "Room Name"),
              style: TextStyle(color: Colors.black),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _streamerNameController,
              decoration: InputDecoration(labelText: "Streamer Name"),
              style: TextStyle(color: Colors.black),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: createIngress,
              style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 39, 38, 104), // Set button color
                  ),
              child: Text(
                    "Create Ingress",
                    style: TextStyle(color: Colors.white), // Set text color if needed
                  ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: ingressList.length,
                itemBuilder: (context, index) {
                  final ingress = ingressList[index];
                  
                  // Create the combined stream URL and key
                  final String streamUrl = ingress['stream_url'] ?? 'N/A';
                  final String streamKey = ingress['stream_key'] ?? 'N/A';
                  final String combinedStreamUrl = streamUrl.endsWith('/')
                      ? "${streamUrl}${streamKey}"
                      : "${streamUrl}/${streamKey}";
                      
                  // Create host and participant links (modify as needed)
                  String encodedRoomName = ingress['roomName'] ?? 'unknown';

                  // Define the base URL dynamically from Uri.base
                  final baseUrl = 'https://${Uri.base.host}';

                  // Define parameters for both host and participant
                  final Map<String, String> hostParams = {
                    'room': encodedRoomName,
                    'role': 'admin',
                  };

                  final Map<String, String> participantParams = {
                    'room': encodedRoomName,
                    'role': 'participant',
                  };

                  // Encode, encrypt, and encode again for both host and participant
                  final encodedHostParams = UrlEncryptionHelper.encodeParams(hostParams);
                  final encryptedHostParams = UrlEncryptionHelper.encrypt(encodedHostParams);
                  final encodedEncryptedHostParams = Uri.encodeComponent(encryptedHostParams);

                  final encodedParticipantParams = UrlEncryptionHelper.encodeParams(participantParams);
                  final encryptedParticipantParams = UrlEncryptionHelper.encrypt(encodedParticipantParams);
                  final encodedEncryptedParticipantParams = Uri.encodeComponent(encryptedParticipantParams);

                  // Construct final invite links
                  final String hostLink = '$baseUrl?data=$encodedEncryptedHostParams';
                  final String participantLink = '$baseUrl?data=$encodedEncryptedParticipantParams';
                  
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Room name and delete button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Room Name : ${encodedRoomName}",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => deleteIngress(encodedRoomName),
                                tooltip: "Delete stream",
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          // Combined Stream URL with Copy Button
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Stream URL :",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        combinedStreamUrl,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontFamily: 'monospace',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.copy, color: Color.fromARGB(255, 39, 38, 104)),
                                      onPressed: () => copyToClipboard(combinedStreamUrl),
                                      tooltip: "Copy combined URL",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          
                          // Host and Participant Links
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Host Link :",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        hostLink,
                                        style: TextStyle(color: Colors.black),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.copy, color: Color.fromARGB(255, 39, 38, 104)),
                                      onPressed: () => copyToClipboard(hostLink),
                                      tooltip: "Copy host link",
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Participant Link :",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        participantLink,
                                        style: TextStyle(color: Colors.black),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.copy, color: Color.fromARGB(255, 39, 38, 104)),
                                      onPressed: () => copyToClipboard(participantLink),
                                      tooltip: "Copy participant link",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      )
    ];
  }
}