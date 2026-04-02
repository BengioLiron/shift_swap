// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/swap_request_model.dart';
import '../models/user_model.dart';

class ApiService {
  // Change this to your FastAPI server IP when running locally
  // For Android emulator use 10.0.2.2, for real device use your machine's LAN IP
  static const String baseUrl = 'http://localhost:8000';

  static Future<UserModel> createUser(String name, String role) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'role': role}),
    );
    if (response.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create user: ${response.body}');
  }

  static Future<List<SwapRequest>> submitRequest({
    required String userId,
    required String userName,
    required String userRole,
    required String giveDay,
    required List<String> takeDays,
    int weekOffset = 0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/requests'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'user_name': userName,
        'user_role': userRole,
        'give_day': giveDay,
        'take_days': takeDays,
        'week_offset': weekOffset,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['matches'] as List)
          .map((m) => SwapRequest.fromJson(m as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to submit request: ${response.body}');
  }

  static Future<List<SwapRequest>> getMyRequests(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/requests/$userId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data
          .map((r) => SwapRequest.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to fetch requests: ${response.body}');
  }

  static Future<List<SwapRequest>> getAllRequests(String userRole) async {
    final response = await http.get(Uri.parse('$baseUrl/requests/all/$userRole'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data
          .map((r) => SwapRequest.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to fetch all requests: ${response.body}');
  }

  static Future<void> markDone({
    required String myRequestId,
    required String theirRequestId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/requests/mark-done'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'my_request_id': myRequestId,
        'their_request_id': theirRequestId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark done: ${response.body}');
    }
  }

  static Future<void> deleteRequest(String requestId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/requests/$requestId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete request: ${response.body}');
    }
  }
}
