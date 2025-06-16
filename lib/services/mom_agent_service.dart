import 'dart:convert';

import 'package:http/http.dart' as http;

class MomService {
  final String baseUrl;

  MomService(this.baseUrl);

  // Start the bot session
  Future<bool> startMeeting(String? roomName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'room_name': roomName,
      }),
    );

    if (response.statusCode == 200) {
      return true; // Meeting started successfully
    } else {
      return false; // Failed to start meeting
    }
  }

  // Stop the bot session and get the MoM
  Future<String> stopMeeting(String? roomName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stop'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'room_name': roomName}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['mom'] ?? "No MoM generated.";
    } else {
      throw Exception('Failed to stop meeting: ${response.body}');
    }
  }
}
