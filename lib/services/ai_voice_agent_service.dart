import 'dart:convert';
import 'package:http/http.dart' as http;

class AIVoiceAgentService {
  final String baseUrl;

  AIVoiceAgentService({required this.baseUrl});

  /// Root endpoint to test connection
  Future<String?> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));

      if (response.statusCode == 200) {
        return json.decode(response.body)['message'];
      } else {
        print('Failed to connect to AI Agent API: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error checking AI Agent health: $e');
      return null;
    }
  }

  /// Start agent with room name and identity
  Future<bool> startAgent(String? roomName, String participantIdentity) async {
    try {

      print('Starting AI agent with room: $roomName, identity: $participantIdentity');
      final response = await http.post(
        Uri.parse('$baseUrl/start-agent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'room_name': roomName,
          'participant_identity': participantIdentity,
        }),
      );
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to start agent: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error starting AI agent: $e');
      return false;
    }
  }

  /// Stop agent
  Future<bool> stopAgent(String? roomName) async {
    try {
      print('Stopping AI agent for room: $roomName');
      final response = await http.post(
        Uri.parse('$baseUrl/stop-agent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'room_name': roomName}),
      );
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to stop agent: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error stopping AI agent: $e');
      return false;
    }


  }
}