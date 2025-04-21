import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_meeting_room/utils.dart';
import 'package:video_meeting_room/app_config.dart';

const String apiServiceUrl = AppConfig.apiLocalNodeUrl;
 
class LiveKitIngressPage extends StatefulWidget {
  @override
  _LiveKitIngressPageState createState() => _LiveKitIngressPageState();
}
 
class _LiveKitIngressPageState extends State<LiveKitIngressPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> ingressList = [];
  List<Map<String, dynamic>> egressList = [];
  
  final TextEditingController _roomNameController = TextEditingController(text: "ganesh");
  final TextEditingController _streamerNameController = TextEditingController(text: "Streamer");
  final TextEditingController _youtubeKeyController = TextEditingController(text: "dfwz-qg06-per2-qs6k-a6vh");
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchIngressList();
    fetchEgressList();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _roomNameController.dispose();
    _streamerNameController.dispose();
    _youtubeKeyController.dispose();
    super.dispose();
  }
 
  Future<void> fetchIngressList() async {
    final response = await http.get(
      Uri.parse('$apiServiceUrl/ingress/get-streams'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      setState(() {
        ingressList = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    }
  }
  
  Future<void> fetchEgressList() async {
    try {
      final response = await http.get(
        Uri.parse('$apiServiceUrl/egress/list'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          if (data['items'] != null) {
            egressList = List<Map<String, dynamic>>.from(data['items']);
          } else {
            egressList = [];
          }
        });
      }
    } catch (e) {
      print('Error fetching egress list: $e');
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
      _roomNameController.clear();
    }
  }

  Future<void> createYouTubeStream() async {
    if (_roomNameController.text.isEmpty || _youtubeKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Room name and YouTube stream key are required"))
      );
      return;
    }
    
    try {
      final response = await http.post(
        Uri.parse('$apiServiceUrl/egress/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "roomName": _roomNameController.text,
          "youtubeKey": _youtubeKeyController.text,
          "options": {
            "layout": "grid",
            "width": 1920,
            "height": 1080
          }
        }),
      );
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("YouTube stream started successfully"),
            backgroundColor: Colors.green,
          )
        );
        fetchEgressList();
        // _roomNameController.clear();
        // _youtubeKeyController.clear();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${errorData['error'] ?? 'Unknown error'}"),
            backgroundColor: Colors.red,
          )
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  Future<void> deleteIngress(String roomName) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Stream deleted successfully"),
            backgroundColor: Colors.green,
          ),
        );
        fetchIngressList();
      } else {
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
  
  Future<void> stopEgress(String egressId) async {
    bool confirmStop = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Stop YouTube Stream"),
          content: Text("Are you sure you want to stop this YouTube stream?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Stop", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ) ?? false;
    
    if (!confirmStop) return;
    
    try {
      final response = await http.post(
        Uri.parse('$apiServiceUrl/egress/stop'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"egressId": egressId}),
      );
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("YouTube stream stopped successfully"),
            backgroundColor: Colors.green,
          ),
        );
        fetchEgressList();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${errorData['error'] ?? 'Unknown error'}"),
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
            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: const Color.fromARGB(255, 39, 38, 104),
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: "RTMP Ingress", icon: Icon(Icons.upload)),
                Tab(text: "YouTube Streaming", icon: Icon(Icons.live_tv)),
              ],
            ),
            SizedBox(height: 20),
            
            // Tab Bar View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // RTMP Ingress Tab
                  buildIngressTab(screenHeight),
                  
                  // YouTube Streaming Tab
                  buildEgressTab(screenHeight),
                ],
              ),
            ),
          ],
        ),
      )
    ];
  }
  
  Widget buildIngressTab(double screenHeight) {
    return Column(
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
            backgroundColor: const Color.fromARGB(255, 39, 38, 104),
          ),
          child: Text(
            "Create Ingress",
            style: TextStyle(color: Colors.white),
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: ingressList.isEmpty 
              ? Center(child: Text("No ingress streams available"))
              : ListView.builder(
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
    );
  }
  
  Widget buildEgressTab(double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _roomNameController,
          decoration: InputDecoration(labelText: "Room Name"),
          style: TextStyle(color: Colors.black),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _youtubeKeyController,
          decoration: InputDecoration(labelText: "YouTube Stream Key"),
          style: TextStyle(color: Colors.black),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: createYouTubeStream,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 39, 38, 104),
          ),
          child: Text(
            "Start YouTube Stream",
            style: TextStyle(color: Colors.white),
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: egressList.isEmpty
              ? Center(child: Text("No active YouTube streams"))
              : ListView.builder(
                  itemCount: egressList.length,
                  itemBuilder: (context, index) {
                    final egress = egressList[index];
                    final String egressId = egress['egressId'] ?? 'unknown';
                    final String roomName = egress['roomName'] ?? 'unknown';
                    final String status = egress['status'] ?? 'unknown';
                    final DateTime startedAt = egress['startedAt'] != null 
                        ? DateTime.parse(egress['startedAt']) 
                        : DateTime.now();
                    
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Room: $roomName",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Status: $status",
                                      style: TextStyle(
                                        color: status == 'ACTIVE' ? Colors.green : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Started: ${startedAt.toString().substring(0, 19)}",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(Icons.stop_circle, color: Colors.red),
                                  onPressed: () => stopEgress(egressId),
                                  tooltip: "Stop stream",
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
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
                                    "Egress ID:",
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
                                          egressId,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontFamily: 'monospace',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.copy, color: Color.fromARGB(255, 39, 38, 104)),
                                        onPressed: () => copyToClipboard(egressId),
                                        tooltip: "Copy Egress ID",
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
    );
  }
}