import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'user_model.dart';
import 'auth_service.dart';

class UserService {
  final String baseUrl = '${dotenv.env['API_URL']}/users';
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ─── Récupérer tous les utilisateurs ────────────────────────────────────────
  Future<List<User>> getAllUsers({bool includeInactive = false}) async {
    try {
      final headers = await _getHeaders();
      final url = includeInactive ? '$baseUrl?includeInactive=true' : baseUrl;
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Erreur getAllUsers: $e');
      return [];
    }
  }

  // ─── Récupérer l'utilisateur courant ────────────────────────────────────────
  Future<User?> getCurrentUser() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/me'), headers: headers)
          .timeout(const Duration(seconds: 5));

      print('getCurrentUser status: ${response.statusCode}');
      print('getCurrentUser body: ${response.body}');

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Erreur getCurrentUser: $e');
      return null;
    }
  }

  // ─── Récupérer un utilisateur par ID ────────────────────────────────────────
  Future<User?> getUserById(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/$id'), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Erreur getUserById: $e');
      return null;
    }
  }

  // ─── Modifier nom / email / rôle d'un utilisateur ───────────────────────────
  Future<User?> updateUser(
    String id, {
    String? email,
    String? name,
    String? role,
  }) async {
    try {
      final headers = await _getHeaders();

      final Map<String, dynamic> body = {};
      if (email != null) body['email'] = email;
      if (name != null) body['name'] = name;
      if (role != null) body['role'] = role;

      final response = await http
          .put(
            Uri.parse('$baseUrl/$id'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Erreur updateUser: $e');
      return null;
    }
  }

  // ─── Modifier le mot de passe ────────────────────────────────────────────────
  Future<bool> updatePassword(String id, String newPassword) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/$id/password'),
            headers: headers,
            body: jsonEncode({'newPassword': newPassword}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Erreur updatePassword: $e');
      return false;
    }
  }

  // ─── Supprimer un utilisateur ───────────────────────────────────────────────
  Future<bool> deleteUser(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl/$id'), headers: headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 204;
    } catch (e) {
      print('Erreur deleteUser: $e');
      return false;
    }
  }

  // ─── Mettre à jour le statut ────────────────────────────────────────────────
  Future<User?> updateUserStatus(String id, String status) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/$id/status'),
            headers: headers,
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Erreur updateUserStatus: $e');
      return null;
    }
  }
}
