/// Modèle représentant un tournoi.
class Tournament {
  final String id;
  final String name;
  final String game;
  final String status;
  final int numberOfTeams;

  Tournament({
    required this.id,
    required this.name,
    required this.game,
    required this.status,
    required this.numberOfTeams,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'] as String,
      name: json['name'] as String,
      game: json['game'] as String,
      status: json['status'] as String,
      numberOfTeams: json['numberOfTeams'] is int
          ? json['numberOfTeams'] as int
          : int.tryParse(json['numberOfTeams']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'game': game,
      'status': status,
      'numberOfTeams': numberOfTeams,
    };
  }

  /// Calcule la puissance de 2 immédiatement supérieure ou égale à un nombre donné.
  static int calculateNextPowerOf2(int count) {
    if (count <= 1) return 1;
    int nextPowerOf2 = 1;
    while (nextPowerOf2 < count) {
      nextPowerOf2 *= 2;
    }
    return nextPowerOf2;
  }

  /// Calcule le nombre de rounds nécessaires pour un arbre direct.
  static int calculateBracketRounds(int teamsCount) {
    int power = calculateNextPowerOf2(teamsCount);
    int rounds = 0;
    while (power > 1) {
      power ~/= 2;
      rounds++;
    }
    return rounds;
  }

  /// Retourne un label humain pour un round selon le nombre de matchs qu'il contient.
  static String getRoundLabel(int matchesInRound) {
    if (matchesInRound == 1) return "Finale";
    if (matchesInRound == 2) return "Demi-finale";
    if (matchesInRound == 4) return "Quart de finale";
    return "${matchesInRound}ème de finale";
  }

  /// Calcule le classement d'une poule à partir d'une liste de matchs.
  static List<TeamStanding> computePoolStandings(
    List<dynamic> roundMatches,
    Map<String, String> teamNames,
  ) {
    final Map<String, int> wins = {};
    final Map<String, int> goals = {};
    final Map<String, int> goalsAgainst = {};

    for (var m in roundMatches) {
      if (m.status == 'FINISHED') {
        final t1Id = m.team1Id as String;
        final t2Id = m.team2Id as String;
        final t1Point = (m.team1Point as num).toInt();
        final t2Point = (m.team2Point as num).toInt();

        goals[t1Id] = (goals[t1Id] ?? 0) + t1Point;
        goalsAgainst[t1Id] = (goalsAgainst[t1Id] ?? 0) + t2Point;
        goals[t2Id] = (goals[t2Id] ?? 0) + t2Point;
        goalsAgainst[t2Id] = (goalsAgainst[t2Id] ?? 0) + t1Point;

        if (t1Point > t2Point) {
          wins[t1Id] = (wins[t1Id] ?? 0) + 1;
        } else if (t2Point > t1Point) {
          wins[t2Id] = (wins[t2Id] ?? 0) + 1;
        }
      }
    }

    final sortedTeamIds = teamNames.keys
        .where((id) => roundMatches.any((m) => m.team1Id == id || m.team2Id == id))
        .toList();
    sortedTeamIds.sort((a, b) {
      // 1. Victoires
      int winComp = (wins[b] ?? 0).compareTo(wins[a] ?? 0);
      if (winComp != 0) return winComp;
      
      // 2. Buts marqués (BP)
      int goalComp = (goals[b] ?? 0).compareTo(goals[a] ?? 0);
      if (goalComp != 0) return goalComp;
      
      // 3. Buts encaissés (BC) - Le moins est le mieux
      int gaComp = (goalsAgainst[a] ?? 0).compareTo(goalsAgainst[b] ?? 0);
      if (gaComp != 0) return gaComp;

      return (teamNames[a] ?? '').compareTo(teamNames[b] ?? '');
    });

    return sortedTeamIds
        .map(
          (id) => TeamStanding(
            teamId: id,
            teamName: teamNames[id] ?? 'Inconnu',
            wins: wins[id] ?? 0,
            goals: goals[id] ?? 0,
            goalsAgainst: goalsAgainst[id] ?? 0,
          ),
        )
        .toList();
  }
}

/// Classe représentant une ligne du classement d'une poule.
class TeamStanding {
  final String teamId;
  final String teamName;
  final int wins;
  final int goals;
  final int goalsAgainst;

  TeamStanding({
    required this.teamId,
    required this.teamName,
    required this.wins,
    required this.goals,
    required this.goalsAgainst,
  });
}
