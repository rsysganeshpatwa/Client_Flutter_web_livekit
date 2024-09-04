import 'dart:convert';
import 'package:http/http.dart' as http;

class RoomDataManageService {
  final String apiServiceUrl;

  RoomDataManageService(this.apiServiceUrl);

  // Method to set the latest data for a room
  Future<void> setLatestData(String roomId, dynamic data) async {
    final url = Uri.parse('$apiServiceUrl/room-data-manage/set-latest-data/$roomId');
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': data}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set latest data: ${response.body}');
    }
  }

  // Method to get the latest data for a room
  Future<dynamic> getLatestData(String roomId) async {
    final url = Uri.parse('$apiServiceUrl/room-data-manage/latest-data/$roomId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      return null;
    }
  }
}
