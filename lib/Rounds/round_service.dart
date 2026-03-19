import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'Model/round.dart';

/// Service gérant les appels API pour les manches (rounds) d'un tournoi.
///
/// L'URL de base est lue depuis la variable [API_URL] du fichier .env.
/// Utilise l'endpoint : {API_URL}/tournaments/{tournamentId}/rounds
class RoundService {
  /// URL de base de l'API, lue depuis .env (variable API_URL).
  final String baseUrl;

  /// Client HTTP — injectable pour les tests (MockClient), sinon client par défaut.
  final http.Client _client;

  RoundService({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? dotenv.env['API_URL'] ?? 'http://localhost:8080/api',
      _client = client ?? http.Client();

  /// En-têtes communs à toutes les requêtes.
  Map<String, String> _getHeaders([String? token]) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// Construit l'URL pour les manches d'un tournoi donné.
  /// [baseUrl] contient déjà /api, ex: http://10.0.2.2:9090/api
  Uri _roundsUri(String tournamentId, [String? roundId]) {
    final path = roundId != null
        ? '/tournaments/$tournamentId/rounds/$roundId'
        : '/tournaments/$tournamentId/rounds';
    return Uri.parse('$baseUrl$path');
  }

  // ---------------------------------------------------------------------------
  // READ — Lister toutes les manches d'un tournoi
  // ---------------------------------------------------------------------------

  /// Récupère la liste de toutes les manches d'un tournoi.
  ///
  /// [tournamentId] : identifiant du tournoi.
  ///
  /// Retourne une liste de [Round].
  /// Lève une [Exception] si la requête échoue.
  Future<List<Round>> getRounds(String tournamentId) async {
    final response = await _client.get(
      _roundsUri(tournamentId),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body) as List<dynamic>;
      return body
          .map((item) => Round.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw Exception(
      'Impossible de récupérer les manches (${response.statusCode}): '
      '${response.body}',
    );
  }

  // ---------------------------------------------------------------------------
  // READ — Récupérer une manche par son ID
  // ---------------------------------------------------------------------------

  /// Récupère les détails d'une manche spécifique.
  ///
  /// [tournamentId] : identifiant du tournoi.
  /// [roundId]      : identifiant de la manche.
  ///
  /// Retourne le [Round] correspondant.
  /// Lève une [Exception] si la requête échoue.
  Future<Round> getRound(String tournamentId, String roundId) async {
    final response = await _client.get(
      _roundsUri(tournamentId, roundId),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return Round.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw Exception(
      'Impossible de récupérer la manche $roundId '
      '(${response.statusCode}): ${response.body}',
    );
  }

  // ---------------------------------------------------------------------------
  // CREATE — Créer une nouvelle manche
  // ---------------------------------------------------------------------------

  /// Crée une nouvelle manche dans un tournoi.
  ///
  /// [tournamentId] : identifiant du tournoi.
  /// [name]         : nom de la manche (ex. "Quarts de finale").
  ///
  /// Retourne le [Round] créé.
  /// Lève une [Exception] si la requête échoue.
  /// [tournamentId] : identifiant du tournoi.
  /// [name]         : nom de la manche (ex. "Quarts de finale").
  /// [format]       : format du match (ex. 1 pour BO1, 3 pour BO3, 5 pour BO5).
  ///
  /// Retourne le [Round] créé.
  /// Lève une [Exception] si la requête échoue.
  Future<Round> createRound(String tournamentId, String name, int format, String token) async {
    final body = jsonEncode({
      'name': name,
      'format': format,
    });

    final response = await _client.post(
      _roundsUri(tournamentId),
      headers: _getHeaders(token),
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Round.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw Exception(
      'Impossible de créer la manche (${response.statusCode}): '
      '${response.body}',
    );
  }

  // ---------------------------------------------------------------------------
  // DELETE — (Bah non du coup)
  // ---------------------------------------------------------------------------
  //
}
