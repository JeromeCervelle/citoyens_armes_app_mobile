import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:citoyens_armes_app_mobile/Rounds/round_service.dart';

// ---------------------------------------------------------------------------
// Données de test
// ---------------------------------------------------------------------------

const _tournamentId = 'tournoi-abc';
const _roundId = 'manche-001';

final _fakeRound = {
  'id': _roundId,
  'name': 'Quarts de finale',
  'matchIds': ['m1', 'm2'],
};

final _fakeRoundList = [_fakeRound];

// ---------------------------------------------------------------------------
// Helper : crée un RoundService avec un MockClient qui répond toujours
// avec [statusCode] et [body].
// ---------------------------------------------------------------------------
RoundService _makeService(int statusCode, Object body) {
  final client = MockClient(
    (_) async => http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    ),
  );

  return RoundService(baseUrl: 'http://localhost:9090/api', client: client);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RoundService', () {
    // -----------------------------------------------------------------------
    // getRounds
    // -----------------------------------------------------------------------
    group('getRounds()', () {
      test('retourne la liste des manches en cas de succès (200)', () async {
        final service = _makeService(200, _fakeRoundList);
        final rounds = await service.getRounds(_tournamentId);

        expect(rounds.length, 1);
        expect(rounds.first.id, _roundId);
        expect(rounds.first.name, 'Quarts de finale');
        expect(rounds.first.matchIds, ['m1', 'm2']);
      });

      test('lève une Exception si la réponse est 401', () async {
        final service = _makeService(401, {'error': 'Non autorisé'});
        expect(() => service.getRounds(_tournamentId), throwsException);
      });
    });

    // -----------------------------------------------------------------------
    // getRound
    // -----------------------------------------------------------------------
    group('getRound()', () {
      test('retourne une manche spécifique en cas de succès (200)', () async {
        final service = _makeService(200, _fakeRound);
        final round = await service.getRound(_tournamentId, _roundId);

        expect(round.id, _roundId);
        expect(round.name, 'Quarts de finale');
      });

      test('lève une Exception si la manche est introuvable (404)', () async {
        final service = _makeService(404, {'error': 'Non trouvé'});
        expect(
          () => service.getRound(_tournamentId, 'inexistant'),
          throwsException,
        );
      });
    });

    // -----------------------------------------------------------------------
    // createRound
    // -----------------------------------------------------------------------
    group('createRound()', () {
      test('retourne la manche créée en cas de succès (200)', () async {
        final service = _makeService(200, _fakeRound);
        final round = await service.createRound(
          _tournamentId,
          'Quarts de finale',
        );

        expect(round.id, _roundId);
        expect(round.name, 'Quarts de finale');
      });

      test('retourne la manche créée en cas de succès (201)', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode(_fakeRound),
            201,
            headers: {'content-type': 'application/json'},
          ),
        );
        final service = RoundService(
          baseUrl: 'http://localhost:9090/api',
          client: client,
        );

        final round = await service.createRound(
          _tournamentId,
          'Quarts de finale',
        );
        expect(round.id, _roundId);
      });

      test('lève une Exception si le serveur répond 500', () async {
        final service = _makeService(500, {'error': 'Erreur serveur'});
        expect(
          () => service.createRound(_tournamentId, 'Finale'),
          throwsException,
        );
      });
    });
  });
}
