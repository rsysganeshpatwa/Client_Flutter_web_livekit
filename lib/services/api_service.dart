import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String tokenServiceUrl;

  ApiService(this.tokenServiceUrl);

  Future<String> getToken(String identity, String roomName, String role,String adminWelcomeMessage) async {
    final response = await http.post(
      Uri.parse('$tokenServiceUrl/token'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'identity': identity, 'roomName': roomName, 'role': role, 'adminWelcomeMessage':adminWelcomeMessage}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['token'];
    } else {
      throw Exception('Failed to generate token');
    }
  }

   Future<String> getWelcomeMessage(String roomName) async {
    final response = await http.post(
      Uri.parse('$tokenServiceUrl/welcomeMessage'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'roomName': roomName}),
    );

    if (response.statusCode == 200) {
      final data = response.body;
      return data;
    } else {
      throw Exception('Failed to get welcome message');
    }
  }


  Stream<List<String>> getRoomList() async* {
    while (true) {
      final response = await http.get(Uri.parse('$tokenServiceUrl/rooms'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final roomList = data.map((room) => room['name'].toString()).toList();
        yield roomList;
      }

      await Future.delayed(const Duration(seconds: 30));
    }
  }
}
