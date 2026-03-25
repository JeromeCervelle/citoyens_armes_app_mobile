import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../match/services/match_api_service.dart';
import '../equipes/controller_equipe.dart';
import '../equipes/model_equipe.dart';
import '../Rounds/round_service.dart';
import '../Rounds/Model/round.dart';
import 'modele_tournois.dart';

class TournamentApiService {
  final MatchApiService _matchService = MatchApiService();
  final String baseUrl = dotenv.get('API_URL');

  Map<String, String> _getHeaders([String? token]) {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<List<Tournament>> getTournaments() async {
    final response = await http
        .get(Uri.parse('$baseUrl/tournaments'), headers: _getHeaders())
        .timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Tournament.fromJson(json)).toList();
    }
    throw Exception('Erreur chargement tournois : ${response.statusCode}');
  }

  Future<Tournament> getTournament(String id) async {
    final response = await http
        .get(Uri.parse('$baseUrl/tournaments/$id'), headers: _getHeaders())
        .timeout(const Duration(seconds: 5));
    if (response.statusCode == 200)
      return Tournament.fromJson(jsonDecode(response.body));
    throw Exception('Erreur chargement tournoi $id : ${response.statusCode}');
  }

  Future<Tournament> createTournament(
    String name,
    String game,
    int numberOfTeams,
    String token,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/tournaments'),
          headers: _getHeaders(token),
          body: jsonEncode({
            'name': name,
            'game': game,
            'numberOfTeams': numberOfTeams,
          }),
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode == 200 || response.statusCode == 201)
      return Tournament.fromJson(jsonDecode(response.body));
    throw Exception('Erreur création tournoi : ${response.body}');
  }

  Future<Tournament> updateTournament(
    String id,
    String name,
    String game,
    int numberOfTeams,
    String token,
  ) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/tournaments/$id'),
          headers: _getHeaders(token),
          body: jsonEncode({
            'name': name,
            'game': game,
            'numberOfTeams': numberOfTeams,
          }),
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode == 200)
      return Tournament.fromJson(jsonDecode(response.body));
    throw Exception('Erreur modification tournoi : ${response.body}');
  }

  Future<void> deleteTournament(String id, String token) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/tournaments/$id'),
          headers: _getHeaders(token),
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode >= 400)
      throw Exception('Erreur suppression tournoi : ${response.statusCode}');
  }

  Future<void> updateTournamentStatus(
    String tournamentId,
    String status,
    String token,
  ) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/tournaments/$tournamentId/status'),
          headers: _getHeaders(token),
          body: jsonEncode({"status": status}),
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200)
      throw Exception('Erreur mise à jour statut: ${response.body}');
  }

  Future<void> generateBracket(
    String tournamentId,
    String token, {
    List<int>? formats,
  }) async {
    try {

      final teams = (await EquipeController().getEquipes(
        tournamentId,
      )).where((t) => !t.name.toUpperCase().contains('EXEMPT')).toList();

      if (teams.length < 2)
        throw Exception('Il faut au moins 2 équipes réelles.');

      int nextPowerOf2 = Tournament.calculateNextPowerOf2(teams.length);
      int totalRounds = Tournament.calculateBracketRounds(teams.length);

      List<dynamic> firstRoundMatchIds = [];

      for (int i = 0; i < totalRounds; i++) {
        int matchesInRound = (nextPowerOf2 >> i) ~/ 2;
        String roundName = Tournament.getRoundLabel(matchesInRound);
        int currentFormat = (formats != null && i < formats.length)
            ? formats[i]
            : 1;

        final roundData = await RoundService().createRound(
          tournamentId,
          roundName,
          currentFormat,
          token,
        );

        // BULK : Un seul appel au lieu de N appels individuels
        final matchesData = await _matchService.bulkCreateMatches(
          tournamentId,
          roundData.id,
          matchesInRound,
          token,
        );

        if (i == 0) {
          firstRoundMatchIds.addAll(matchesData.map((m) => m['id'] as String));
        }
      }

      if (teams.length < nextPowerOf2) {
        int diff = nextPowerOf2 - teams.length;
        final teamFactories = List.generate(
          diff,
          (_) =>
              () => EquipeController().createEquipe(
                tournamentId,
                Equipe(name: "EXEMPTÉ"),
              ),
        );
        await _chunkedFutureWait(teamFactories, chunkSize: 5);

        final updated = await EquipeController().getEquipes(tournamentId);
        teams.clear();
        teams.addAll(updated);
      }

      final realTeams =
          teams.where((t) => !t.name.toUpperCase().contains('EXEMPT')).toList()
            ..shuffle();
      final sortedTeams = [
        ...realTeams,
        ...teams.where((t) => t.name.toUpperCase().contains('EXEMPT')),
      ];

      List<int> order = _getSeedingOrder(nextPowerOf2);
      List<Equipe> reordered = [];
      for (int s in order) {
        if (s <= sortedTeams.length) {
          reordered.add(sortedTeams[s - 1]);
        }
      }

      final List<Future Function()> registrationFactories = [];
      for (int m = 0; m < firstRoundMatchIds.length; m++) {
        String matchId = firstRoundMatchIds[m];
        int t1Idx = m * 2;
        int t2Idx = m * 2 + 1;

        String t1Id = (t1Idx < reordered.length)
            ? (reordered[t1Idx].id ?? "")
            : "";
        String t2Id = (t2Idx < reordered.length)
            ? (reordered[t2Idx].id ?? "")
            : "";

        if (t1Id.isNotEmpty && t2Id.isNotEmpty) {
          registrationFactories.add(() async {
            await _matchService.registerTeamsToMatch(
              tournamentId,
              matchId,
              t1Id,
              t2Id,
              token,
            );

            if (reordered[t1Idx].name.contains("EXEMPTÉ") ||
                reordered[t2Idx].name.contains("EXEMPTÉ")) {
              String realTeamId = reordered[t1Idx].name.contains("EXEMPTÉ")
                  ? t2Id
                  : t1Id;
              await _matchService.updateMatchPoints(
                tournamentId,
                matchId,
                realTeamId,
                1,
                token,
              );
              await _matchService.updateMatchStatus(
                tournamentId,
                matchId,
                'FINISHED',
                token,
              );
            }
          });
        }
      }
      if (registrationFactories.isNotEmpty) {
        await _chunkedFutureWait(registrationFactories, chunkSize: 10);
      }

      await advanceTournament(tournamentId, token);
    } catch (e) {
      throw Exception('Erreur génération arbre: $e');
    }
  }

  Future<void> createEmptyBracket(
    String tournamentId,
    int numberOfTeams,
    String token, {
    List<int>? formats,
  }) async {
    if (numberOfTeams < 2) return;
    int nextPowerOf2 = Tournament.calculateNextPowerOf2(numberOfTeams);
    int totalRounds = Tournament.calculateBracketRounds(numberOfTeams);
    for (int i = 0; i < totalRounds; i++) {
      int matchesInRound = (nextPowerOf2 >> i) ~/ 2;
      String roundName = Tournament.getRoundLabel(matchesInRound);
      int currentFormat = (formats != null && i < formats.length)
          ? formats[i]
          : 1;

      final roundData = await RoundService().createRound(
        tournamentId,
        roundName,
        currentFormat,
        token,
      );
      // BULK : Un seul appel au lieu de N appels individuels
      await _matchService.bulkCreateMatches(
        tournamentId,
        roundData.id,
        matchesInRound,
        token,
      );
    }
  }

  Future<void> generatePools(
    String tournamentId,
    int numPools,
    int qualifiedPerPool,
    String token, {
    int poolFormat = 1,
    List<int>? bracketFormats,
  }) async {
    try {

      final teams = (await EquipeController().getEquipes(
        tournamentId,
      )).where((t) => !t.name.toUpperCase().contains('EXEMPT')).toList();

      if (teams.length < 2)
        throw Exception('Il faut au moins 2 équipes réelles.');

      final shuffledTeams = List.from(teams)..shuffle();
      List<List<dynamic>> poolsTeams = List.generate(numPools, (_) => []);
      for (int i = 0; i < shuffledTeams.length; i++) {
        poolsTeams[i % numPools].add(shuffledTeams[i]);
      }

      for (int i = 0; i < numPools; i++) {
        String roundName = "Poule ${String.fromCharCode(65 + i)}";
        final roundData = await RoundService().createRound(
          tournamentId,
          roundName,
          poolFormat,
          token,
        );

        List<dynamic> pool = poolsTeams[i];
        if (pool.length < 2) continue;

        int matchCount = (pool.length * (pool.length - 1)) ~/ 2;

        final List<dynamic> matchesData = await _matchService.bulkCreateMatches(
          tournamentId,
          roundData.id,
          matchCount,
          token,
        );

        int currentMatchIdx = 0;
        final List<Future Function()> registrationFactories = [];

        for (int t1 = 0; t1 < pool.length; t1++) {
          for (int t2 = t1 + 1; t2 < pool.length; t2++) {
            if (currentMatchIdx < matchesData.length) {
              final String matchId = matchesData[currentMatchIdx]['id'];
              final String id1 = pool[t1].id!;
              final String id2 = pool[t2].id!;
              registrationFactories.add(
                () => _matchService.registerTeamsToMatch(
                  tournamentId,
                  matchId,
                  id1,
                  id2,
                  token,
                ),
              );
              currentMatchIdx++;
            }
          }
        }

        if (registrationFactories.isNotEmpty) {
          await _chunkedFutureWait(registrationFactories, chunkSize: 5);
        }
      }

      await createEmptyBracket(
        tournamentId,
        numPools * qualifiedPerPool,
        token,
        formats: bracketFormats,
      );
    } catch (e) {
      throw Exception('Erreur génération poules: $e');
    }
  }

  Future<void> advanceDuel(
    String tournamentId,
    String team1Id,
    String team2Id,
    String currentRoundId,
    String token,
  ) async {
    try {
      if (team1Id.isEmpty && team2Id.isEmpty) return;
      final rounds = await RoundService().getRounds(tournamentId);
      final currentRound = rounds.firstWhere((r) => r.id == currentRoundId);
      int idx = rounds.indexOf(currentRound);

      if (idx + 1 < rounds.length) {
        final teams = await EquipeController().getEquipes(tournamentId);
        final byeIds = teams
            .where((t) => t.name.toUpperCase().contains("EXEMPT"))
            .map((t) => t.id!)
            .toSet();
        final allMatches = await _matchService.getMatches(tournamentId);
        await _advanceWinnersToNextRound(
          tournamentId,
          currentRound,
          rounds[idx + 1],
          allMatches,
          token,
          byeIds,
        );
      }
    } catch (e) {
      print("Erreur progress duel: $e");
    }
  }

  Future<void> completeMatch(
    String tournamentId,
    String matchId,
    String t1,
    int s1,
    String t2,
    int s2,
    String status,
    String roundId,
    String token,
  ) async {
    // Mise à jour des points
    await _matchService.updateMatchPoints(tournamentId, matchId, t1, s1, token);
    await _matchService.updateMatchPoints(tournamentId, matchId, t2, s2, token);

    // Mise à jour du statut
    await _matchService.updateMatchStatus(tournamentId, matchId, status, token);

    // Avancement automatique si terminé
    if (status == 'FINISHED') {
      await advanceTournament(tournamentId, token);
    }
  }

  Future<void> advanceTournament(String tournamentId, String token) async {
    try {
      final rounds = await RoundService().getRounds(tournamentId);
      final teams = await EquipeController().getEquipes(tournamentId);
      final byeIds = teams
          .where((t) => t.name.toUpperCase().contains("EXEMPT"))
          .map((t) => t.id!)
          .toSet();
      var allMatches = await _matchService.getMatches(tournamentId);

      for (int i = 0; i < rounds.length; i++) {
        final round = rounds[i];
        final matches = allMatches
            .where((m) => round.matchIds.contains(m.id))
            .toList();

        // Check if round needs to expand its BO series
        await _isRoundFinished(tournamentId, round, matches, token, byeIds);

        // Stream Advancement: Try to push winners to the next round immediately
        if (round.name.startsWith('Poule')) {
          if (await _isRoundFinished(
            tournamentId,
            round,
            matches,
            token,
            byeIds,
          )) {
            bool allPoolsDone = true;
            for (var r in rounds.where((r) => r.name.startsWith('Poule'))) {
              if (!(await _isRoundFinished(
                tournamentId,
                r,
                allMatches.where((m) => r.matchIds.contains(m.id)).toList(),
                token,
                byeIds,
              ))) {
                allPoolsDone = false;
                break;
              }
            }
            if (allPoolsDone) {
              await _resolvePoolsAndSeedBracket(
                tournamentId,
                round,
                allMatches,
                token,
              );
              // Refresh matches after seeding bracket from pools
              allMatches = await _matchService.getMatches(tournamentId);
            }
          }
        } else if (i + 1 < rounds.length) {
          await _advanceWinnersToNextRound(
            tournamentId,
            round,
            rounds[i + 1],
            allMatches,
            token,
            byeIds,
          );
          // REFRESH matches to pick up the winners pushed to the next round
          allMatches = await _matchService.getMatches(tournamentId);
        }
      }
    } catch (e) {
    }
  }

  Future<bool> _isRoundFinished(
    String tournamentId,
    Round r,
    List<dynamic> matches,
    String token,
    Set<String> byeIds,
  ) async {
    final Map<String, List<dynamic>> groups = {};
    for (var m in matches) {
      if (m.team1Id.isEmpty && m.team2Id.isEmpty) continue;
      final k = m.team1Id.compareTo(m.team2Id) < 0
          ? '${m.team1Id}_${m.team2Id}'
          : '${m.team2Id}_${m.team1Id}';
      groups.putIfAbsent(k, () => []).add(m);
    }

    if (groups.isEmpty) return false;

    int needed = (r.format ~/ 2) + 1;
    bool allDone = true;

    for (var s in groups.values) {
      int w1 = s
          .where((m) => m.status == 'FINISHED' && m.team1Point > m.team2Point)
          .length;
      int w2 = s
          .where((m) => m.status == 'FINISHED' && m.team2Point > m.team1Point)
          .length;

      bool containsExemption = s.any(
        (m) => byeIds.contains(m.team1Id) || byeIds.contains(m.team2Id),
      );
      bool isTbd = s.any((m) => m.team1Id.isEmpty || m.team2Id.isEmpty);

      if (containsExemption || isTbd || w1 >= needed || w2 >= needed) {
        continue;
      }

      allDone = false;

      if (s.every((m) => m.status == 'FINISHED') && s.length < r.format) {
        try {
          final next = await _matchService.createMatch(
            tournamentId,
            r.id,
            token,
          );
          if (next != null && next['id'] != null) {
            await _matchService.registerTeamsToMatch(
              tournamentId,
              next['id'],
              s[0].team1Id,
              s[0].team2Id,
              token,
            );
          }
        } catch (e) {
          print("Erreur création match BO: $e");
        }
      }
    }
    return allDone;
  }

  Future<void> _resolvePoolsAndSeedBracket(
    String tournamentId,
    Round poolRound,
    List<dynamic> allMatches,
    String token,
  ) async {
    final teams = await EquipeController().getEquipes(tournamentId);
    final allRounds = await RoundService().getRounds(tournamentId);
    final Map<String, String> teamNames = {for (var t in teams) t.id!: t.name};

    Map<String, int> wins = {};
    Map<String, int> goals = {};
    Map<String, int> goalsAgainst = {};

    for (var pr in allRounds.where((r) => r.name.startsWith('Poule'))) {
      final prMatches = allMatches
          .where((m) => pr.matchIds.contains(m.id))
          .toList();
      final Map<String, List<dynamic>> series = {};
      for (var m in prMatches) {
        final k = m.team1Id.compareTo(m.team2Id) < 0
            ? '${m.team1Id}_${m.team2Id}'
            : '${m.team2Id}_${m.team1Id}';
        series.putIfAbsent(k, () => []).add(m);
      }

      for (var s in series.values) {
        int w1 = 0, w2 = 0;
        for (var m in s) {
          if (m.status != 'FINISHED') continue;
          goals[m.team1Id] = (goals[m.team1Id] ?? 0) + (m.team1Point as int);
          goals[m.team2Id] = (goals[m.team2Id] ?? 0) + (m.team2Point as int);
          goalsAgainst[m.team1Id] =
              (goalsAgainst[m.team1Id] ?? 0) + (m.team2Point as int);
          goalsAgainst[m.team2Id] =
              (goalsAgainst[m.team2Id] ?? 0) + (m.team1Point as int);
          if (m.team1Point > m.team2Point)
            w1++;
          else if (m.team2Point > m.team1Point)
            w2++;
        }
        if (w1 > w2)
          wins[s[0].team1Id] = (wins[s[0].team1Id] ?? 0) + 1;
        else if (w2 > w1)
          wins[s[0].team2Id] = (wins[s[0].team2Id] ?? 0) + 1;
      }
    }

    final nextRound = allRounds.firstWhere(
      (r) => !r.name.startsWith('Poule'),
      orElse: () => allRounds.first,
    );
    final nextRoundMatches = allMatches
        .where((m) => nextRound.matchIds.contains(m.id))
        .toList();
    int targetSlots = nextRoundMatches.length * 2;
    final poolRounds = allRounds
        .where((r) => r.name.startsWith('Poule'))
        .toList();
    int qPerPool = 2; // Par défaut
    if (poolRounds.isNotEmpty) {
      int prevPowerOf2 = targetSlots ~/ 2;
      qPerPool = (prevPowerOf2 / poolRounds.length).floor() + 1;
      int maxPerPool = (teamNames.length / poolRounds.length).ceil();
      if (qPerPool > maxPerPool) qPerPool = maxPerPool;
    }

    List<String> qualifiers = [];
    for (var pr in poolRounds) {
      final mIds = pr.matchIds;
      final pTeams = teamNames.keys
          .where(
            (id) => allMatches
                .where((m) => mIds.contains(m.id))
                .any((m) => m.team1Id == id || m.team2Id == id),
          )
          .toList();
      pTeams.sort(
        (a, b) => _compareTeams(a, b, wins, goals, goalsAgainst, teamNames),
      );

      for (int k = 0; k < qPerPool; k++) {
        if (pTeams.length > k) {
          qualifiers.add(pTeams[k]);
        }
      }
    }

    qualifiers.sort(
      (a, b) => _compareTeams(a, b, wins, goals, goalsAgainst, teamNames),
    );

    if (qualifiers.length < targetSlots) {
      int diff = targetSlots - qualifiers.length;
      final allTeams = await EquipeController().getEquipes(tournamentId);
      final dummyTeams = allTeams.where((t) => t.name == "EXEMPTÉ").toList();

      for (int i = 0; i < diff; i++) {
        if (i < dummyTeams.length) {
          qualifiers.add(dummyTeams[i].id!);
        } else {
          await EquipeController().createEquipe(
            tournamentId,
            Equipe(name: "EXEMPTÉ"),
          );
          final updated = await EquipeController().getEquipes(tournamentId);
          final newDummy = updated.lastWhere((t) => t.name == "EXEMPTÉ");
          qualifiers.add(newDummy.id!);
        }
      }
    }

    final allTeams = await EquipeController().getEquipes(tournamentId);
    final sortedBase = [
      ...allTeams
          .where((t) => qualifiers.contains(t.id) && t.name != "EXEMPTÉ")
          .toList()
        ..sort((a, b) => qualifiers.indexOf(a.id!) - qualifiers.indexOf(b.id!)),
      ...allTeams
          .where((t) => qualifiers.contains(t.id) && t.name == "EXEMPTÉ")
          .toList(),
    ];

    List<int> order = _getSeedingOrder(targetSlots);
    List<String> reorderedIds = [];
    for (int s in order) {
      if (s <= sortedBase.length) {
        reorderedIds.add(sortedBase[s - 1].id!);
      }
    }

    final nextRoundMatchObjects = nextRoundMatches
        .where((m) => m.id != null)
        .toList();

    for (int i = 0; i < nextRound.matchIds.length; i++) {
      int t1Idx = i * 2;
      int t2Idx = i * 2 + 1;

      if (t1Idx >= reorderedIds.length || t2Idx >= reorderedIds.length) break;

      final existingMatch = nextRoundMatchObjects.cast<dynamic>().firstWhere(
        (m) => m?.id == nextRound.matchIds[i],
        orElse: () => null,
      );
      if (existingMatch != null &&
          existingMatch.team1Id.isNotEmpty &&
          existingMatch.team2Id.isNotEmpty) {
        continue; // Déjà seédé, ne pas écraser
      }

      String t1 = reorderedIds[t1Idx];
      String t2 = reorderedIds[t2Idx];

      await _matchService.registerTeamsToMatch(
        tournamentId,
        nextRound.matchIds[i],
        t1,
        t2,
        token,
      );

      final t1Name = allTeams.firstWhere((t) => t.id == t1).name;
      final t2Name = allTeams.firstWhere((t) => t.id == t2).name;

      bool isExemption1 = t1Name.toUpperCase().contains('EXEMPT');
      bool isExemption2 = t2Name.toUpperCase().contains('EXEMPT');

      if (isExemption1 || isExemption2) {
        String winnerId = isExemption1 ? t2 : t1;
        await _matchService.updateMatchPoints(
          tournamentId,
          nextRound.matchIds[i],
          winnerId,
          1,
          token,
        );
        await _matchService.updateMatchStatus(
          tournamentId,
          nextRound.matchIds[i],
          'FINISHED',
          token,
        );
      }
    }
  }

  List<int> _getSeedingOrder(int n) {
    List<int> seeds = [1];
    while (seeds.length < n) {
      List<int> nextSeeds = [];
      for (int s in seeds) {
        nextSeeds.add(s);
        nextSeeds.add(seeds.length * 2 + 1 - s);
      }
      seeds = nextSeeds;
    }
    return seeds;
  }

  int _compareTeams(
    String a,
    String b,
    Map<String, int> wins,
    Map<String, int> goals,
    Map<String, int> goalsAgainst,
    Map<String, String> names,
  ) {
    int winComp = (wins[b] ?? 0).compareTo(wins[a] ?? 0);
    if (winComp != 0) return winComp;
    int goalComp = (goals[b] ?? 0).compareTo(goals[a] ?? 0);
    if (goalComp != 0) return goalComp;
    int gaComp = (goalsAgainst[a] ?? 0).compareTo(
      goalsAgainst[b] ?? 0,
    ); // Moins de buts pris est mieux (tri croissant)
    if (gaComp != 0) return gaComp;
    return (names[a] ?? '').compareTo(names[b] ?? '');
  }

  Future<void> _advanceWinnersToNextRound(
    String tId,
    Round curr,
    Round next,
    List<dynamic> all,
    String token,
    Set<String> byeIds,
  ) async {
    try {
      for (int i = 0; i < next.matchIds.length; i++) {
        final pos1 = 2 * i;
        final pos2 = 2 * i + 1;
        if (pos2 >= curr.matchIds.length) break;

        final m1 = _findMatchById(all, curr.matchIds[pos1]);
        final m2 = _findMatchById(all, curr.matchIds[pos2]);

        if (m1 == null || m2 == null) {
          print(
            "DEBUG: Round ${curr.name} slot $i: UN MATCH PARENT EST NULL (M1: $m1, M2: $m2)",
          );
          break;
        }

        print(
          "DEBUG: Slot $i pairing: Match ${m1.id} (T1: ${m1.team1Id}, T2: ${m1.team2Id}) v Match ${m2.id} (T1: ${m2.team1Id}, T2: ${m2.team2Id})",
        );

        String w1 = _getSeriesWinner(m1, all, curr, byeIds);
        String w2 = _getSeriesWinner(m2, all, curr, byeIds);

        print("DEBUG: Round ${curr.name} slot $i: W1='$w1', W2='$w2'");

        if (w1.isNotEmpty && w2.isNotEmpty) {
          // GARDE IDEMPOTENCE : On ne réinscrit pas si le match suivant a déjà des équipes.
          final nextMatch = _findMatchById(all, next.matchIds[i]);
          if (nextMatch != null &&
              nextMatch.team1Id.isNotEmpty &&
              nextMatch.team2Id.isNotEmpty) {
            continue; // Match déjà seédé, ne pas écraser
          }

          print("DEBUG: Match ${next.matchIds[i]} rempli avec $w1 et $w2");
          await _matchService.registerTeamsToMatch(
            tId,
            next.matchIds[i],
            w1,
            w2,
            token,
          );
        } else if (w1.isNotEmpty || w2.isNotEmpty) {
          print(
            "DEBUG: Round suivant - attente du deuxième vainqueur pour ${next.matchIds[i]} (W1: '$w1', W2: '$w2')",
          );
        }
      }
    } catch (e) {
      print("Erreur progression: $e");
    }
  }

  dynamic _findMatchById(List<dynamic> all, String id) {
    for (var m in all) {
      if (m.id == id) return m;
    }
    return null;
  }

  String _getSeriesWinner(
    dynamic baseMatch,
    List<dynamic> allMatches,
    Round round,
    Set<String> byeIds,
  ) {
    if (baseMatch == null) return "";
    final t1 = baseMatch.team1Id;
    final t2 = baseMatch.team2Id;
    if (t1.isEmpty || t2.isEmpty) return "";

    // ESSENTIEL : On ne se limite pas à round.matchIds car le backend peut avoir du retard
    // sur la mise à jour de la liste des IDs du round. On cherche par équipes.
    final series = allMatches
        .where(
          (m) =>
              ((m.team1Id == t1 && m.team2Id == t2) ||
              (m.team1Id == t2 && m.team2Id == t1)),
        )
        .toList();

    int w1 = 0;
    int w2 = 0;
    for (var m in series) {
      String s = m.status?.toString().toUpperCase() ?? "";
      if (s == 'FINISHED') {
        // Check if teams are in the same or swapped order vs t1/t2
        bool swapped = m.team1Id != t1;
        int mS1 = swapped ? m.team2Point : m.team1Point; // score for t1
        int mS2 = swapped ? m.team1Point : m.team2Point; // score for t2
        if (mS1 > mS2)
          w1++;
        else if (mS2 > mS1)
          w2++;
      }
    }

    int needed = (round.format ~/ 2) + 1;
    if (w1 >= needed) return t1;
    if (w2 >= needed) return t2;

    // CAS DES EXEMPTIONS : Si l'une des équipes est une équipe fantôme (BYE),
    // on avance dès qu'un match est fini (le seeding initial en crée un fini).
    bool containsExemption = byeIds.contains(t1) || byeIds.contains(t2);
    if (containsExemption &&
        series.any((m) => m.status?.toString().toUpperCase() == 'FINISHED')) {
      // Return the real team (the one that is NOT the exemption)
      String byeId = byeIds.contains(t1) ? t1 : t2;
      String realId = (byeId == t1) ? t2 : t1;
      return realId;
    }

    return "";
  }


  /// Exécute une liste de fonctions asynchrones (factories) par vagues (chunks)
  /// pour Truly contrôler le départ des requêtes et ne pas saturer le serveur.
  /// Cette version est RÉSILIENTE : un échec d'une tâche n'arrête pas les autres.
  Future<List<T>> _chunkedFutureWait<T>(
    List<Future<T> Function()> factories, {
    int chunkSize = 50,
  }) async {
    List<T> results = [];
    for (int i = 0; i < factories.length; i += chunkSize) {
      int end = (i + chunkSize < factories.length)
          ? i + chunkSize
          : factories.length;
      final chunk = factories.sublist(i, end);

      final futures = chunk.map((f) async {
        try {
          return await _retryFuture(f);
        } catch (e) {
          if (kDebugMode)
            print("ÉCHEC DÉFINITIF sur une requête de génération : $e");
          return null;
        }
      }).toList();

      final chunkResults = await Future.wait(futures);
      for (var res in chunkResults) {
        if (res != null) results.add(res as T);
      }
    }
    return results;
  }

  /// Tente d'exécuter un futur plusieurs fois avant d'abandonner.
  Future<T> _retryFuture<T>(
    Future<T> Function() factory, {
    int retries = 3,
  }) async {
    int attempts = 0;
    while (attempts < retries) {
      try {
        return await factory();
      } catch (e) {
        attempts++;
        if (attempts >= retries) {
          print("ERROR: Abandon après $attempts tentatives : $e");
          rethrow;
        }
        print("RETRY: Tentative $attempts échouée, on réessaie...");
        await Future.delayed(Duration(milliseconds: 250 * attempts));
      }
    }
    throw Exception("Échec après $retries tentatives");
  }
}
