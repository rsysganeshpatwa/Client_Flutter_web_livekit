import 'dart:convert';
import 'package:http/http.dart' as http;

class ApprovalService {
  final String baseUrl;

  ApprovalService(this.baseUrl);

  // Fetch pending requests
 Future<List<dynamic>> fetchPendingRequests(String roomName) async {
    final uri = Uri.parse('$baseUrl/room-permission/pending-requests').replace(queryParameters: {'roomName': roomName});

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load pending requests');
    }
  }

  // Create a new approval request
  Future<Map<String, dynamic>> createApprovalRequest(String participantName, String roomName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/room-permission/request-approval'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: json.encode({
        'participantName': participantName,
        'roomName': roomName,
      }),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create approval request');
    }
  }

  // Approve or reject a request
  Future<Map<String, dynamic>> approveRequest(int requestId, bool approve) async {
    final response = await http.post(
      Uri.parse('$baseUrl/room-permission/approve-request'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: json.encode({
        'requestId': requestId,
        'approve': approve,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to approve or reject request');
    }
  }

  // Get request status
  Future<Map<String, dynamic>> getRequestStatus(int requestId) async {
    final response = await http.get(Uri.parse('$baseUrl/room-permission/request-status?requestId=$requestId'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get request status');
    }
  }

  // Cancel a request
  Future<Map<String, dynamic>> removeRequest(int requestId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/room-permission/remove-request'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: json.encode({
        'requestId': requestId,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to cancel request');
    }
  }
}
