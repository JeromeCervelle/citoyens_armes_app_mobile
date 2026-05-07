import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../user/auth_service.dart';
import 'log_model.dart';

class LogService {
  final String baseUrl = '${dotenv.env['API_URL']}/logs';
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<ConnectionLog>> getRecentLogs() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/recent'), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ConnectionLog.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Erreur getRecentLogs: $e');
      return [];
    }
  }

  Future<List<ConnectionLog>> getLogsByUser(String userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/user/$userId'), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ConnectionLog.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Erreur getLogsByUser: $e');
      return [];
    }
  }
}
