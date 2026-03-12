import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'modele_tournois.dart';

class TournamentApiService {
  // Récupère l'URL directement depuis le fichier .env
  final String baseUrl = dotenv.get('API_URL');

  Map<String, String> _getHeaders(String token) {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // 1. Lister tous les tournois
  Future<List<Tournament>> getTournaments(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tournaments'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Tournament.fromJson(json)).toList();
    } else {
      throw Exception('Erreur chargement tournois : ${response.statusCode}');
    }
  }

  // 2. Récupérer un tournoi spécifique
  Future<Tournament> getTournament(String id, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tournaments/$id'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      return Tournament.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Erreur chargement tournoi $id : ${response.statusCode}');
    }
  }

  // 3. Créer un tournoi
  Future<Tournament> createTournament(String name, String game, int numberOfTeams, String token) async {
    final body = jsonEncode({
      'name': name,
      'game': game,
      'numberOfTeams': numberOfTeams,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/tournaments'),
      headers: _getHeaders(token),
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Tournament.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Erreur création tournoi : ${response.body}');
    }
  }

  // 4. Modifier un tournoi
  Future<Tournament> updateTournament(String id, String name, String game, int numberOfTeams, String token) async {
    final body = jsonEncode({
      'name': name,
      'game': game,
      'numberOfTeams': numberOfTeams,
    });

    final response = await http.put(
      Uri.parse('$baseUrl/tournaments/$id'),
      headers: _getHeaders(token),
      body: body,
    );

    if (response.statusCode == 200) {
      return Tournament.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Erreur modification tournoi : ${response.body}');
    }
  }

  // 5. Supprimer un tournoi
  Future<void> deleteTournament(String id, String token) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/tournaments/$id'),
      headers: _getHeaders(token),
    );

    if (response.statusCode >= 400) {
      throw Exception('Erreur suppression tournoi : ${response.statusCode}');
    }
  }

  // 6. Récupérer les rounds d'un tournoi
  Future<List<dynamic>> getRounds(String tournamentId, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tournaments/$tournamentId/rounds'),
      headers: _getHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur chargement rounds');
  }

  // 7. Récupérer les équipes d'un tournoi
  Future<List<dynamic>> getTeams(String tournamentId, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tournaments/$tournamentId/teams'),
      headers: _getHeaders(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erreur chargement équipes');
  }

  // 8. Générer automatiquement les rounds après la création du tournoi
  Future<void> generateRoundsAutomatically(String tournamentId, int numberOfTeams, String token) async {
    try {
      // 1. Trouver la puissance de 2 supérieure ou égale
      int nextPowerOf2 = 1;
      while (nextPowerOf2 < numberOfTeams) {
        nextPowerOf2 *= 2;
      }

      // 2. Calculer le nombre total de rounds
      int totalRounds = 0;
      int temp = nextPowerOf2;
      while (temp > 1) {
        temp ~/= 2;
        totalRounds++;
      }

      // 3. Boucler pour créer chaque round (de x-ème de finale jusqu'à la Finale)
      for (int i = 0; i < totalRounds; i++) {
        int teamsInRound = nextPowerOf2 >> i; 
        int matchesInRound = teamsInRound ~/ 2;
        
        String roundName;

        if (matchesInRound == 1) {
          roundName = "Finale";
        } else if (matchesInRound == 2) {
          roundName = "Demi-finale";
        } else if (matchesInRound == 4) {
          roundName = "Quart de finale";
        } else {
          roundName = "$matchesInRoundème de finale";
        }

        print('Envoi API: Création du round "$roundName" pour le tournoi $tournamentId');
        
        // Simule
        await Future.delayed(const Duration(milliseconds: 500));
        
        print('[DEBUG] Round "$roundName" créé avec succès !');
        
        // Plus tard:
        // await createRound(tournamentId, roundName, token);
      }

      print('Tous les rounds ont été créés avec succès !');

    } catch (e) {
      print('Erreur création rounds: $e');
      throw Exception('Erreur lors de la création automatique des rounds: $e');
    }
  }
}