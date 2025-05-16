import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const String nodeApiUrl = "https://your-node-api-url";

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
      Uri.parse('$nodeApiUrl/ingress'),
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
      Uri.parse('$nodeApiUrl/ingress'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "name": "\${_streamerNameController.text} Ingress",
        "input_type": "RTMP_INPUT",
        "room_name": _roomNameController.text,
        "participant_identity": "streamer",
        "participant_name": _streamerNameController.text
      }),
    );
    if (response.statusCode == 200) {
      fetchIngressList();
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
              child: Text("Create Ingress"),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: ingressList.length,
                itemBuilder: (context, index) {
                  final ingress = ingressList[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    child: ListTile(
                      title: Text(ingress['name'] ?? 'Unnamed',
                          style: TextStyle(color: Colors.black)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Type: \${ingress['input_type']}",
                              style: TextStyle(color: Colors.black)),
                          Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      "Stream URL: \${ingress['stream_url'] ?? 'N/A'}",
                                      style: TextStyle(color: Colors.black))),
                              IconButton(
                                icon: Icon(Icons.copy),
                                onPressed: () => copyToClipboard(
                                    ingress['stream_url'] ?? ''),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      "Stream Key: \${ingress['stream_key'] ?? 'N/A'}",
                                      style: TextStyle(color: Colors.black))),
                              IconButton(
                                icon: Icon(Icons.copy),
                                onPressed: () => copyToClipboard(
                                    ingress['stream_key'] ?? ''),
                              ),
                            ],
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
      ),
    ];
  }
}
