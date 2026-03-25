import 'dart:ui';
import 'package:flutter/material.dart';
import '../../user/auth_service.dart';
import '../../match/services/match_api_service.dart';
import '../../match/models/match_dto.dart';
import '../../Rounds/round_service.dart';
import '../../Rounds/Model/round.dart';
import '../../equipes/controller_equipe.dart';
import '../../equipes/model_equipe.dart';
import '../../Tournois/modele_tournois.dart';
import '../../Tournois/repository_tournois.dart';

// Represents a series of matches (BO1, BO3, etc.) between two teams
class Encounter {
  String? team1Id;
  String? team2Id;
  List<MatchDTO> matches = [];

  bool matchesTeams(MatchDTO m) {
    if (m.team1Id.isEmpty || m.team2Id.isEmpty) return false;
    // Handle potential team swapping between games
    return (m.team1Id == team1Id && m.team2Id == team2Id) ||
           (m.team1Id == team2Id && m.team2Id == team1Id);
  }
}

class BracketView extends StatefulWidget {
  final Tournament tournament;
  final bool isAdmin;

  const BracketView({super.key, required this.tournament, required this.isAdmin});

  @override
  State<BracketView> createState() => _BracketViewState();
}

class _BracketViewState extends State<BracketView> {
  final MatchApiService _matchApiService = MatchApiService();
  final RoundService _roundService = RoundService();
  final EquipeController _equipeController = EquipeController();
  final TournamentApiService _tournamentApiService = TournamentApiService();

  bool _isLoading = true;
  List<Round> _rounds = [];
  List<Round> _allRounds = [];
  List<MatchDTO> _allMatches = [];
  Map<String, String> _teamNames = {};
  String? _errorMessage;
  String? _authToken;

  // Bracket layout constants
  static const double cardWidth = 220;
  static const double cardHeight = 68;
  static const double gapX = 40;
  static const double gapY = 32;
  static const double slotHeight = cardHeight + gapY;
  static const double columnWidth = cardWidth + gapX;

  @override
  void initState() {
    super.initState();
    _loadBracketData();
  }

  @override
  void didUpdateWidget(BracketView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tournament.id != widget.tournament.id) {
      _loadBracketData();
    }
  }

  Future<void> _loadBracketData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final tournamentId = widget.tournament.id;
      final token = await AuthService().getToken();
      final results = await Future.wait([
        _roundService.getRounds(tournamentId, token: token),
        _matchApiService.getMatches(tournamentId),
        _equipeController.getEquipes(tournamentId),
      ]);

      var allFetchedRounds = results[0] as List<Round>;
      var rounds = allFetchedRounds.where((r) => !r.name.toUpperCase().startsWith('POULE')).toList();
      
      final matchesList = results[1] as List<dynamic>;
      final equipes = results[2] as List<Equipe>;

      final List<MatchDTO> parsedMatches = matchesList.map((m) => m is MatchDTO ? m : MatchDTO.fromJson(m as Map<String, dynamic>)).toList();

      final Map<String, String> teamMap = {};
      for (var eq in equipes) {
        if (eq.id != null) {
          teamMap[eq.id!] = eq.name;
        }
      }

      setState(() {
        _rounds = rounds;
        _allRounds = allFetchedRounds;
        _allMatches = parsedMatches;
        _teamNames = teamMap;
        _authToken = token;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement de l\'arbre : $e';
      });
    }
  }

  // Groups matches for a round into Encounters (BO series)
  List<Encounter> _getEncountersForRound(Round round) {
    // 1. Determine number of slots for this bracket round reliably
    int numSlots = _getExpectedSlots(round);
    List<Encounter> encounters = List.generate(numSlots, (_) => Encounter());

    // 2. Assign matches to these slots
    // First, use round.matchIds to find definite matches
    for (String id in round.matchIds) {
      var match = _allMatches.cast<MatchDTO?>().firstWhere((m) => m?.id == id, orElse: () => null);
      if (match == null) continue;

      if (match.team1Id.isNotEmpty && match.team2Id.isNotEmpty) {
        // Group by teams for known encounters
        bool grouped = false;
        for (var e in encounters) {
          if (e.matchesTeams(match)) {
            if (!e.matches.any((m) => m.id == match.id)) {
              e.matches.add(match);
            }
            grouped = true;
            break;
          }
        }
        if (!grouped) {
          // If not grouped by teams, find the first available slot or TBD with same teams
          for (var e in encounters) {
            if (e.matches.isEmpty) {
              e.matches.add(match);
              e.team1Id = match.team1Id;
              e.team2Id = match.team2Id;
              grouped = true;
              break;
            }
          }
        }
      } else {
        // TBD match: assign to the first available empty slot
        for (var e in encounters) {
          if (e.matches.isEmpty) {
            e.matches.add(match);
            e.team1Id = match.team1Id;
            e.team2Id = match.team2Id;
            break;
          }
        }
      }
    }

    // 3. Robust BO Aggregation: Check if ANY other match in the whole tournament 
    // belongs to this encounter (same teams and not in another round)
    // This fixed cases where round.matchIds might be missing some BO matched due to API lag
    for (var e in encounters) {
       if (e.team1Id != null && e.team1Id!.isNotEmpty && e.team2Id != null && e.team2Id!.isNotEmpty) {
         for (var m in _allMatches) {
           if (e.matchesTeams(m) && !e.matches.any((existing) => existing.id == m.id)) {
             // We check if this match belongs to another round to avoid false positives
             // but since MatchDTO doesn't have roundId, we rely on the fact that teams
             // only meet once per round.
             bool inOtherRound = false;
             for (var otherRound in _allRounds) {
               if (otherRound.id != round.id && otherRound.matchIds.contains(m.id)) {
                 inOtherRound = true;
                 break;
               }
             }
             if (!inOtherRound) {
               e.matches.add(m);
             }
           }
         }
       }
    }
    
    return encounters;
  }

  int _getExpectedSlots(Round round) {
    if (_rounds.isEmpty) return 0;
    
    // On base le calcul sur le nombre de matchs du PREMIER round de l'arbre affiché
    // (qui peut être différent du nombre total d'équipes du tournoi, ex: après des poules)
    int firstRoundMatches = _rounds[0].matchIds.length;
    int nextPowerOf2 = firstRoundMatches * 2;
    
    int roundIndex = _rounds.indexOf(round);
    return nextPowerOf2 >> (roundIndex + 1);
  }

  double _getOffsetForRound(int r) {
    return (slotHeight / 2) * ((1 << r) - 1);
  }

  double _getDistanceForRound(int r) {
    return slotHeight * (1 << r);
  }

  double _getY(int roundIndex, int encounterIndex) {
    return _getOffsetForRound(roundIndex) + encounterIndex * _getDistanceForRound(roundIndex);
  }

  double _getX(int roundIndex) {
    return roundIndex * columnWidth;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(color: Color(0xFF00FF85), strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chargement de l\'arbre...',
              style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 1),
            ),
          ],
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ElevatedButton(onPressed: _loadBracketData, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_rounds.isEmpty) {
      return const Center(
        child: Text('Aucun round pour ce tournoi.\nL\'arbre est vide.', textAlign: TextAlign.center),
      );
    }

    // A constant corresponding to the space taken by the round titles at top
    const double titleAreaHeight = 40.0;
    
    double maxTotalHeight = 0;
    for (int r = 0; r < _rounds.length; r++) {
      int encounterCount = _getEncountersForRound(_rounds[r]).length;
      if (encounterCount > 0) {
        double lastGroupY = _getY(r, encounterCount - 1);
        if (lastGroupY > maxTotalHeight) {
          maxTotalHeight = lastGroupY;
        }
      }
    }
    // Add cardHeight, titleAreaHeight, and generous padding for safety
    maxTotalHeight += cardHeight + titleAreaHeight + 200; // Even more padding

    double totalWidth = _rounds.length * columnWidth + 100;

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.1,
      maxScale: 2.5,
      child: Container(
        padding: const EdgeInsets.all(40),
        width: totalWidth,
        height: maxTotalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: BracketLinesPainter(
                  rounds: _rounds,
                  allMatches: _allMatches,
                  cardWidth: cardWidth,
                  cardHeight: cardHeight,
                  gapX: gapX,
                  slotHeight: slotHeight,
                  getEncountersForRound: _getEncountersForRound,
                ),
              ),
            ),
            ..._buildAllEncounters(),
            ..._buildRoundTitles(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRoundTitles() {
    List<Widget> titles = [];
    for (int r = 0; r < _rounds.length; r++) {
      titles.add(
        Positioned(
          left: _getX(r),
          top: 0,
          width: cardWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF85).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00FF85).withOpacity(0.2)),
            ),
            child: Text(
              '${_rounds[r].name.toUpperCase()} (BO${_rounds[r].format})',
              style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return titles;
  }

  List<Widget> _buildAllEncounters() {
    List<Widget> encounterWidgets = [];
    const double titleAreaHeight = 40.0;

    for (int r = 0; r < _rounds.length; r++) {
      final encounters = _getEncountersForRound(_rounds[r]);
      
      for (int i = 0; i < encounters.length; i++) {
        final encounter = encounters[i];
        final x = _getX(r);
        final y = _getY(r, i) + titleAreaHeight;

        encounterWidgets.add(
          Positioned(
            left: x,
            top: y,
            width: cardWidth,
            height: cardHeight,
            child: InkWell(
              onTap: () => _showEncounterDetails(encounter, _rounds[r]),
              borderRadius: BorderRadius.circular(6),
              child: _buildEncounterCard(encounter, round: _rounds[r]),
            ),
          ),
        );
      }
    }
    return encounterWidgets;
  }

  Widget _buildEncounterCard(Encounter encounter, {required Round round}) {
    bool isFirstRound = _rounds.indexOf(round) == 0;
    final name1 = (encounter.team1Id == null || encounter.team1Id!.isEmpty) 
        ? (isFirstRound && (encounter.team2Id != null && encounter.team2Id!.isNotEmpty) ? 'EXEMPTÉ' : 'TBD') 
        : (_teamNames[encounter.team1Id] ?? 'TBD');
    final name2 = (encounter.team2Id == null || encounter.team2Id!.isEmpty) 
        ? (isFirstRound && (encounter.team1Id != null && encounter.team1Id!.isNotEmpty) ? 'EXEMPTÉ' : 'TBD') 
        : (_teamNames[encounter.team2Id] ?? 'TBD');
    
    int t1Wins = 0;
    int t2Wins = 0;
    bool anyFinished = false;

    for (var m in encounter.matches) {
      if (m.status?.toUpperCase() == 'FINISHED') {
        anyFinished = true;
        int mTeam1Score = m.team1Id == encounter.team1Id ? m.team1Point : m.team2Point;
        int mTeam2Score = m.team2Id == encounter.team2Id ? m.team2Point : m.team1Point;
        if (mTeam1Score > mTeam2Score) t1Wins++;
        else if (mTeam2Score > mTeam1Score) t2Wins++;
      }
    }

    int threshold = (round.format / 2).floor() + 1;

    bool isExemption1 = name1.toUpperCase().contains('EXEMPT');
    bool isExemption2 = name2.toUpperCase().contains('EXEMPT');
    bool wins1 = t1Wins >= threshold || (isExemption2 && anyFinished);
    bool wins2 = t2Wins >= threshold || (isExemption1 && anyFinished);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(child: _buildTeamRow(name1, t1Wins, isFinished: anyFinished, isWinner: wins1)),
              const Divider(height: 1, thickness: 1.5, color: Colors.grey),
              Expanded(child: _buildTeamRow(name2, t2Wins, isFinished: anyFinished, isWinner: wins2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRow(String teamName, int wins, {required bool isFinished, bool isWinner = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.emoji_events, color: Colors.amber, size: 16),
            ),
          Expanded(
            child: Text(
              teamName.toUpperCase(),
              style: TextStyle(
                fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
                color: isWinner ? const Color(0xFF00FF85) : (teamName == 'TBD' ? Colors.white24 : Colors.white70),
                fontSize: 11,
                letterSpacing: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isWinner ? const Color(0xFF00FF85).withOpacity(0.1) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              wins.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isWinner ? const Color(0xFF00FF85) : Colors.white38,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEncounterDetails(Encounter encounter, Round round) {
    if (encounter.matches.isEmpty) return;
    
    final name1 = _teamNames[encounter.team1Id] ?? 'TBD';
    final name2 = _teamNames[encounter.team2Id] ?? 'TBD';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D1526),
          title: Text('${round.name.toUpperCase()} - DÉTAILS DU MATCH', style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: encounter.matches.length,
              itemBuilder: (context, index) {
                final match = encounter.matches[index];
                
                bool isAdmin = widget.isAdmin;
                bool swapped = match.team1Id == encounter.team2Id;
                int score1 = swapped ? match.team2Point : match.team1Point;
                int score2 = swapped ? match.team1Point : match.team2Point;

                return ListTile(
                  title: Text('MATCH ${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('$name1 ($score1) - ($score2) $name2', style: const TextStyle(color: Colors.white54)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(match.status ?? 'PENDING', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (isAdmin) const Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                  onTap: isAdmin ? () {
                    Navigator.pop(context);
                    _showMatchEditDialog(match, name1, name2, encounter, roundId: round.id);
                  } : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('FERMER', style: TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showMatchEditDialog(MatchDTO match, String name1, String name2, Encounter encounter, {required String roundId}) {
    int s1 = match.team1Point;
    int s2 = match.team2Point;
    String currentStatus = match.status ?? 'PENDING';
    bool isSaving = false;

    // Calculate BO Aggregate Score
    int win1 = 0;
    int win2 = 0;
    for (var m in encounter.matches) {
       if (m.status?.toUpperCase() == 'FINISHED') {
         int mS1 = m.team1Id == encounter.team1Id ? m.team1Point : m.team2Point;
         int mS2 = m.team2Id == encounter.team2Id ? m.team2Point : m.team1Point;
         if (mS1 > mS2) win1++; else if (mS2 > mS1) win2++;
       }
    }

    bool dialogMounted = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> updateScore(String teamId, int newScore) async {
            if (_authToken == null) return;
            
            // OPTIMISTE : Mise à jour locale immédiate pour réactivité maximale
            setState(() {
              final idx = _allMatches.indexWhere((m) => m.id == match.id);
              if (idx != -1) {
                final old = _allMatches[idx];
                _allMatches[idx] = MatchDTO(
                  id: old.id,
                  team1Id: old.team1Id,
                  team2Id: old.team2Id,
                  team1Point: teamId == old.team1Id ? newScore : old.team1Point,
                  team2Point: teamId == old.team2Id ? newScore : old.team2Point,
                  status: old.status,
                );
              }
              if (teamId == match.team1Id) s1 = newScore; else s2 = newScore;
            });

            if (dialogMounted) setDialogState(() => isSaving = true);
            try {
              await _matchApiService.updateMatchPoints(widget.tournament.id, match.id, teamId, newScore, _authToken!);
              // Silent refresh pour synchroniser proprement sans clignotement
              if (mounted) await _loadBracketData(silent: true);
            } catch (e) {
              if (!mounted || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
            } finally {
              if (dialogMounted) setDialogState(() => isSaving = false);
            }
          }

          Future<void> updateStatus(String status) async {
            if (_authToken == null) return;
            if (dialogMounted) setDialogState(() => isSaving = true);
            try {
              if (status == 'FINISHED') {
                await _tournamentApiService.completeMatch(
                  widget.tournament.id, 
                  match.id, 
                  match.team1Id, s1, 
                  match.team2Id, s2, 
                  status, 
                  roundId, 
                  _authToken!
                );
              } else {
                await _matchApiService.updateMatchStatus(widget.tournament.id, match.id, status, _authToken!);
              }
              if (!mounted) return;
              currentStatus = status;
              // Silent refresh pour garder la position sur l'arbre
              await _loadBracketData(silent: true);
              if (!mounted || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Statut mis à jour')));
            } catch (e) {
              if (!mounted || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
            } finally {
              if (dialogMounted) setDialogState(() => isSaving = false);
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF0D1526),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SCORE EN DIRECT', style: TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
                    if (isSaving) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF00FF85), strokeWidth: 2)),
                  ],
                ),
                if (encounter.matches.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Série BO : $win1 - $win2', 
                      style: const TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.normal)
                    ),
                  ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLiveScoreRow(name1, s1, (val) => updateScore(match.team1Id, val)),
                const Divider(height: 32),
                _buildLiveScoreRow(name2, s2, (val) => updateScore(match.team2Id, val)),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: currentStatus,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Statut du match',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF85))),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF85))),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PENDING', child: Text('En attente')),
                    DropdownMenuItem(value: 'IN_PROGRESS', child: Text('En cours')),
                    DropdownMenuItem(value: 'FINISHED', child: Text('Terminé')),
                    DropdownMenuItem(value: 'CANCELLED', child: Text('Annulé')),
                  ],
                  onChanged: isSaving ? null : (val) => updateStatus(val!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('FERMER', style: TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() => dialogMounted = false);
  }

  Widget _buildLiveScoreRow(String teamName, int currentScore, Function(int) onUpdate) {
    return Column(
      children: [
        Text(teamName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, letterSpacing: 1.1), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: currentScore > 0 ? () => onUpdate(currentScore - 1) : null,
              icon: const Icon(Icons.remove_circle_outline, size: 32, color: Colors.red),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00FF85).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.05),
              ),
              child: Text(
                currentScore.toString(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            IconButton(
              onPressed: () => onUpdate(currentScore + 1),
              icon: const Icon(Icons.add_circle_outline, size: 32, color: Colors.green),
            ),
          ],
        ),
      ],
    );
  }
}

class BracketLinesPainter extends CustomPainter {
  final List<Round> rounds;
  final List<MatchDTO> allMatches;
  final double cardWidth;
  final double cardHeight;
  final double gapX;
  final double slotHeight;
  final List<Encounter> Function(Round round) getEncountersForRound;

  BracketLinesPainter({
    required this.rounds,
    required this.allMatches,
    required this.cardWidth,
    required this.cardHeight,
    required this.gapX,
    required this.slotHeight,
    required this.getEncountersForRound,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rounds.isEmpty) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double titleAreaHeight = 40.0;

    double getOffsetForRound(int r) => (slotHeight / 2) * ((1 << r) - 1);
    double getDistanceForRound(int r) => slotHeight * (1 << r);
    double getY(int r, int i) => getOffsetForRound(r) + i * getDistanceForRound(r) + titleAreaHeight;
    double getX(int r) => r * (cardWidth + gapX);

    for (int r = 1; r < rounds.length; r++) {
      final currentRoundEncounters = getEncountersForRound(rounds[r]);
      final previousRoundEncounters = getEncountersForRound(rounds[r - 1]);
      
      for (int i = 0; i < currentRoundEncounters.length; i++) {
        double inX = getX(r);
        double inY = getY(r, i) + cardHeight / 2;

        int childIndex1 = 2 * i;
        int childIndex2 = 2 * i + 1;

        double midX = inX - gapX / 2;

        canvas.drawLine(Offset(midX, inY), Offset(inX, inY), paint);

        if (childIndex1 < previousRoundEncounters.length) {
          double outX = getX(r - 1) + cardWidth;
          double outY1 = getY(r - 1, childIndex1) + cardHeight / 2;
          
          canvas.drawLine(Offset(outX, outY1), Offset(midX, outY1), paint);
          canvas.drawLine(Offset(midX, outY1), Offset(midX, inY), paint);
        }

        if (childIndex2 < previousRoundEncounters.length) {
          double outX = getX(r - 1) + cardWidth;
          double outY2 = getY(r - 1, childIndex2) + cardHeight / 2;
          
          canvas.drawLine(Offset(outX, outY2), Offset(midX, outY2), paint);
          canvas.drawLine(Offset(midX, outY2), Offset(midX, inY), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; 
  }
}
