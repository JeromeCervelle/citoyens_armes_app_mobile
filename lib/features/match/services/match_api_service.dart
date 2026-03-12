// Fichier : lib/features/match/services/match_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/match_dto.dart';

class MatchApiService {
  // Remplace localhost par 10.0.2.2 si tu utilises l'émulateur Android
  final String baseUrl = "http://10.72.73.182:9090/api/tournaments"; 

  // N'oublie pas de récupérer le token généré par celui de ton équipe qui fait l'authentification !
  // Ici on le simule en paramètre.
  Map<String, String> _getHeaders(String token) {
    return {
      "Content-Type": "application/json",
      "Accept": "*/*",
      "Authorization": "Bearer $token",
    };
  }

  // 1. Lister les matchs d'un tournoi [cite: 138]
  Future<List<MatchDTO>> getMatches(String tournamentId, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$tournamentId/matches'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => MatchDTO.fromJson(item)).toList();
    } else {
      throw Exception('Erreur lors du chargement des matchs : ${response.statusCode}');
    }
  }

  // 2. Inscrire des équipes à un match [cite: 63, 64, 83, 84, 85]
  Future<void> registerTeamsToMatch(String tournamentId, String matchId, String team1Id, String team2Id, String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$tournamentId/matches/$matchId/teams'),
      headers: _getHeaders(token),
      body: jsonEncode({
        "team1Id": team1Id,
        "team2Id": team2Id,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'inscription des équipes');
    }
  }

  // 3. Mettre à jour les points d'un match [cite: 108, 109, 132, 133]
  Future<void> updateMatchPoints(String tournamentId, String matchId, String teamId, int score, String token) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/$tournamentId/matches/$matchId/points'),
      headers: _getHeaders(token),
      body: jsonEncode({
        "teamId": teamId,
        "score": score,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la mise à jour du score');
    }
  }
  // Récupérer tous les tournois
  Future<List<dynamic>> getTournaments(String token) async {
    final response = await http.get(
      Uri.parse('http://localhost:9090/api/tournaments'),
      headers: _getHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur chargement tournois');
  }

  // Récupérer les rounds d'un tournoi
  Future<List<dynamic>> getRounds(String tournamentId, String token) async {
    final response = await http.get(
      Uri.parse('http://localhost:9090/api/tournaments/$tournamentId/rounds'),
      headers: _getHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur chargement rounds');
  }

  // Récupérer les équipes d'un tournoi
  Future<List<dynamic>> getTeams(String tournamentId, String token) async {
    final response = await http.get(
      Uri.parse('http://localhost:9090/api/tournaments/$tournamentId/teams'),
      headers: _getHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur chargement équipes');
  }
}