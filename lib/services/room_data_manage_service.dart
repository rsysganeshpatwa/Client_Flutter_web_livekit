import 'dart:convert';
import 'package:http/http.dart' as http;

class RoomDataManageService {
  final String apiServiceUrl;

  RoomDataManageService(this.apiServiceUrl);

  // Method to set the latest data for a room
  Future<void> setLatestData(String roomId, String roomName, dynamic data) async {
    final url = Uri.parse('$apiServiceUrl/room-data-manage/set-latest-data/$roomId?roomName=$roomName');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': data}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set latest data: ${response.body}');
    }
  }

  // Method to remove participant for a room
  Future<void> removeParticipant(roomID,roomName,identity) async {
    final url = Uri.parse('$apiServiceUrl/room-data-manage/remove-participant').replace(
      queryParameters: {
        'roomId': roomID,
        'roomName': roomName,
        'participantId': identity,
      },
    );    
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        print('Participant removed successfully');
      } else {
        print('Failed to remove participant: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
  // Method to get the latest data for a room
  Future<dynamic> getLatestData(String roomId, String roomName) async {
    final url = Uri.parse('$apiServiceUrl/room-data-manage/latest-data/$roomId?roomName=$roomName');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      return null;
    }
  }
}
