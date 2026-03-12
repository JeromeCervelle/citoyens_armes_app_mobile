/// Test d'intégration — appelle la VRAIE API (Docker doit tourner).
///
/// Prérequis :
///   1. `docker-compose -f docker/local-citoyens-armes/docker-compose-local.yaml up -d`
///   2. Configurer [_email] et [_password] ci-dessous
///
/// Lancer avec :
///   flutter test test/rounds/round_service_integration_test.dart
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:citoyens_armes_app_mobile/Rounds/round_service.dart';

// ---------------------------------------------------------------------------
// Configuration — à adapter
// ---------------------------------------------------------------------------
const _baseUrl = 'http://localhost:9090/api';
final _email = 'test_${DateTime.now().millisecondsSinceEpoch}@test.fr';
const _password = 'string';
const _roundName = 'Manche créée par test';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Inscrit l'utilisateur (ignoré s'il existe déjà), puis retourne un token JWT.
Future<String> _getToken() async {
  // Toujours tenter l'inscription — si le compte existe déjà l'API renverra
  // une erreur qu'on ignore, puis on fait le login.
  await http.post(
    Uri.parse('$_baseUrl/auth/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': _email,
      'password': _password,
      'name': 'Utilisateur Test',
    }),
  );

  // Login pour récupérer le token
  final res = await http.post(
    Uri.parse('$_baseUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': _email, 'password': _password}),
  );

  expect(
    res.statusCode,
    200,
    reason: 'Login échoué (${res.statusCode}) : ${res.body}',
  );

  final json = jsonDecode(res.body) as Map<String, dynamic>;
  return json['accessToken'] as String;
}

/// Crée un tournoi et retourne son ID.
Future<String> _createTournament(String token) async {
  final res = await http.post(
    Uri.parse('$_baseUrl/tournaments'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'name': 'Tournoi Test ${DateTime.now().millisecondsSinceEpoch}',
      'game': 'Citoyens Armés',
      'numberOfTeams': 2,
    }),
  );

  expect(
    res.statusCode,
    200,
    reason: 'Impossible de créer le tournoi : ${res.body}',
  );

  final json = jsonDecode(res.body) as Map<String, dynamic>;
  return json['id'] as String;
}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  group('RoundService — intégration (vraie API)', () {
    late String token;
    late String tournamentId;

    setUpAll(() async {
      token = await _getToken();
      tournamentId = await _createTournament(token);
      print('\n Tournoi créé : $tournamentId');
    });

    test('createRound() crée une vraie manche en base', () async {
      final service = RoundService(baseUrl: _baseUrl, authToken: token);

      final round = await service.createRound(tournamentId, _roundName);

      print(' Manche créée : id=${round.id}, name=${round.name}');

      expect(round.id, isNotEmpty);
      expect(round.name, _roundName);
      expect(round.matchIds, isEmpty); // nouvelle manche = pas encore de matchs
    });

    test('getRounds() retrouve la manche créée en base', () async {
      final service = RoundService(baseUrl: _baseUrl, authToken: token);

      final rounds = await service.getRounds(tournamentId);

      print(' Manches trouvées : ${rounds.map((r) => r.name).toList()}');

      expect(rounds, isNotEmpty);
      expect(
        rounds.any((r) => r.name == _roundName),
        isTrue,
        reason: 'La manche "$_roundName" devrait être présente en base',
      );
    });
  });
}
