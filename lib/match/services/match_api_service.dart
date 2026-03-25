import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/match_dto.dart';

class MatchApiService {
  final String baseUrl = "${dotenv.get('API_URL')}/tournaments";

  Map<String, String> _getHeaders([String? token]) {
    return {
      "Content-Type": "application/json",
      "Accept": "*/*",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<List<MatchDTO>> getMatches(String tournamentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$tournamentId/matches'),
      headers: _getHeaders(),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => MatchDTO.fromJson(item)).toList();
    }
    throw Exception('Erreur lors du chargement des matchs : ${response.statusCode}');
  }

  Future<void> registerTeamsToMatch(
    String tournamentId,
    String matchId,
    String team1Id,
    String team2Id,
    String token,
  ) async {
    final Map<String, dynamic> data = {"team1Id": team1Id};
    if (team2Id.isNotEmpty) data["team2Id"] = team2Id;

    final response = await http.post(
      Uri.parse('$baseUrl/$tournamentId/matches/$matchId/teams'),
      headers: _getHeaders(token),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'inscription des équipes');
    }
  }

  Future<void> updateMatchPoints(
    String tournamentId,
    String matchId,
    String teamId,
    int score,
    String token,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/$tournamentId/matches/$matchId/points'),
      headers: _getHeaders(token),
      body: jsonEncode({"teamId": teamId, "score": score}),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la mise à jour du score');
    }
  }

  /// Crée un match vide dans une manche (via l'endpoint par round).
  Future<dynamic> createMatch(
    String tournamentId,
    String roundId,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$tournamentId/rounds/$roundId/matches'),
      headers: _getHeaders(token),
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur création match : ${response.body}');
  }

  /// Crée plusieurs matchs vides en un seul appel (bulk).
  /// Bien plus rapide que N appels createMatch() consécutifs.
  Future<List<Map<String, dynamic>>> bulkCreateMatches(
    String tournamentId,
    String roundId,
    int count,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$tournamentId/matches/bulk'),
      headers: _getHeaders(token),
      body: jsonEncode({"roundId": roundId, "count": count}),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200 || response.statusCode == 201) {
      List<dynamic> body = jsonDecode(response.body);
      return body.cast<Map<String, dynamic>>();
    }
    throw Exception('Erreur création bulk matchs : ${response.body}');
  }

  Future<void> updateMatchStatus(
    String tournamentId,
    String matchId,
    String status,
    String token,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/$tournamentId/matches/$matchId/status'),
      headers: _getHeaders(token),
      body: jsonEncode({"status": status}),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la mise à jour du statut : ${response.body}');
    }
  }

  Future<List<MatchDTO>> getMatchesByTeam(
    String tournamentId,
    String teamId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$tournamentId/matches/team/$teamId'),
      headers: _getHeaders(),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => MatchDTO.fromJson(item)).toList();
    }
    throw Exception('Erreur lors du chargement des matchs de l\'équipe : ${response.statusCode}');
  }
}
