import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'model_equipe.dart';
import '../user/auth_service.dart';

class EquipeController {
  final String baseUrl = dotenv.env['API_URL']!;

  // Helper asynchrone pour les headers avec le bon token
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      "Content-Type": "application/json",
      "accept": "*/*",
      "Authorization": "Bearer ${token ?? ''}",
    };
  }

  // Récupérer toutes les équipes d'un tournoi
  Future<List<Equipe>> getEquipes(String tournamentId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse("$baseUrl/tournaments/$tournamentId/teams"),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((e) => Equipe.fromJson(e)).toList();
    } else {
      throw Exception(
        "Erreur chargement équipes (Code: ${response.statusCode})",
      );
    }
  }

  // Créer une équipe
  Future<bool> createEquipe(String tournamentId, Equipe equipe) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse("$baseUrl/tournaments/$tournamentId/teams"),
      headers: headers,
      body: jsonEncode(equipe.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) return true;
    throw Exception("Erreur création équipe: ${response.body}");
  }

  // Modifier une équipe
  Future<void> updateEquipe(String tournamentId, Equipe equipe) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse("$baseUrl/tournaments/$tournamentId/teams/${equipe.id}"),
      headers: headers,
      body: jsonEncode(equipe.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Erreur modification équipe (Code: ${response.statusCode})",
      );
    }
  }

  // Supprimer une équipe
  Future<void> deleteEquipe(String tournamentId, String teamId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse("$baseUrl/tournaments/$tournamentId/teams/$teamId"),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Erreur suppression équipe (Code: ${response.statusCode})",
      );
    }
  }

  Future<List<Map<String, dynamic>>> getTournaments() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse("$baseUrl/tournaments"),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((t) => {"id": t['id'], "name": t['name']}).toList();
    } else {
      throw Exception("Erreur chargement tournois");
    }
  }
}
