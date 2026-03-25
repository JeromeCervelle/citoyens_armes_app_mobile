import 'dart:ui';
import 'package:flutter/material.dart';
import '../../user/auth_service.dart';
import '../../match/services/match_api_service.dart';
import '../../match/models/match_dto.dart';
import '../../Tournois/repository_tournois.dart';
import '../../Tournois/modele_tournois.dart';
import '../../equipes/controller_equipe.dart';
import '../../equipes/model_equipe.dart';
import '../../Rounds/round_service.dart';
import '../../Rounds/Model/round.dart';
import '../theme/neon_components.dart';

class MatchListView extends StatefulWidget {
  final Tournament tournament;
  final bool isAdmin;
  final String? roundId;
  final String? teamId;
  final String? title;

  const MatchListView({
    super.key,
    required this.tournament,
    required this.isAdmin,
    this.roundId,
    this.teamId,
    this.title,
  });

  @override
  State<MatchListView> createState() => _MatchListViewState();
}

class _MatchListViewState extends State<MatchListView> {
  final MatchApiService _matchApiService = MatchApiService();
  final TournamentApiService _tournamentApiService = TournamentApiService();
  final EquipeController _equipeController = EquipeController();
  final RoundService _roundService = RoundService();

  List<MatchDTO> _matches = [];
  List<Round> _allRounds = [];
  Map<String, String> _teamNames = {};
  bool _isLoadingMatches = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoadingMatches = true);
    try {
      // Parallel fetch for matches, teams, and optionally the round
      final List<Future<dynamic>> futures = [
        _matchApiService.getMatches(widget.tournament.id),
        _equipeController.getEquipes(widget.tournament.id),
        _roundService.getRounds(widget.tournament.id),
      ];
      
      if (widget.roundId != null) {
        futures.add(_roundService.getRound(widget.tournament.id, widget.roundId!));
      }

      final results = await Future.wait(futures);

      List<MatchDTO> matches = (results[0] as List<dynamic>)
          .map((m) => m is MatchDTO ? m : MatchDTO.fromJson(m as Map<String, dynamic>))
          .toList();
      final equipes = results[1] as List<Equipe>;
      final rounds = results[2] as List<Round>;
      Round? targetRound;
      if (widget.roundId != null) {
        targetRound = results[3] as Round;
      }

      final Map<String, String> teamMap = {};
      for (var eq in equipes) {
        if (eq.id != null) {
          teamMap[eq.id!] = eq.name;
        }
      }

      // Apply filters
      if (targetRound != null) {
        final roundMatchIds = targetRound.matchIds.toSet();
        matches = matches.where((m) => roundMatchIds.contains(m.id)).toList();
      }
      
      if (widget.teamId != null) {
        matches = matches.where((m) => m.team1Id == widget.teamId || m.team2Id == widget.teamId).toList();
      }

      setState(() {
        _matches = matches;
        _teamNames = teamMap;
        _allRounds = rounds;
        _isLoadingMatches = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMatches = false);
      _showError('Erreur chargement matchs/équipes: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFiltered = widget.roundId != null || widget.teamId != null;

    Widget body = _buildMatchList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const NeonBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: isFiltered
                ? AppBar(
                    title: Text((widget.title ?? 'MATCHS').toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF00FF85),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 16)),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                  )
                : null,
            body: body,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchList() {
    if (_isLoadingMatches) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF85)));
    }
    if (_matches.isEmpty) {
      return const Center(child: Text('Aucun match trouvé', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final m = _matches[index];
        final name1 = _teamNames[m.team1Id] ?? 'Équipe 1';
        final name2 = _teamNames[m.team2Id] ?? 'Équipe 2';

        return ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              child: InkWell(
                onTap: widget.isAdmin ? () => _showEditMatchDialog(m, name1, name2) : null,
                borderRadius: BorderRadius.circular(15),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name1.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF85).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF00FF85).withOpacity(0.3)),
                            ),
                            child: Text(
                              '${m.team1Point} - ${m.team2Point}',
                              style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              name2.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Statut: ${m.status}', style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.1)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditMatchDialog(MatchDTO match, String name1, String name2) {
    int s1 = match.team1Point;
    int s2 = match.team2Point;
    String currentStatus = match.status ?? 'PENDING';
    bool isSaving = false;

    // Find the round for this match
    String? matchRoundId = widget.roundId;
    if (matchRoundId == null) {
      for (var r in _allRounds) {
        if (r.matchIds.contains(match.id)) {
          matchRoundId = r.id;
          break;
        }
      }
    }

    // Attempt to find BO progress (scanning other matches in the same round with same teams)
    int win1 = 0;
    int win2 = 0;
    int boCount = 0;
    if (matchRoundId != null) {
      for (var m in _matches) {
        if (((m.team1Id == match.team1Id && m.team2Id == match.team2Id) || 
             (m.team1Id == match.team2Id && m.team2Id == match.team1Id)) &&
             _allRounds.firstWhere((r) => r.id == matchRoundId, orElse: () => Round(id: '', name: '', format: 1, matchIds: [])).matchIds.contains(m.id)) {
          boCount++;
          if (m.status?.toUpperCase() == 'FINISHED') {
            int mS1 = m.team1Id == match.team1Id ? m.team1Point : m.team2Point;
            int mS2 = m.team2Id == match.team1Id ? m.team2Point : m.team1Point;
            if (mS1 > mS2) win1++; else if (mS2 > mS1) win2++;
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> updateScore(String teamId, int newScore) async {
            final token = await AuthService().getToken() ?? '';
            setDialogState(() => isSaving = true);
            try {
              await _matchApiService.updateMatchPoints(widget.tournament.id, match.id, teamId, newScore, token);
              if (teamId == match.team1Id) s1 = newScore; else s2 = newScore;
              _loadMatches();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
            } finally {
              setDialogState(() => isSaving = false);
            }
          }

          Future<void> updateStatus(String status) async {
            final token = await AuthService().getToken() ?? '';
            setDialogState(() => isSaving = true);
            try {
              if (status == 'FINISHED' && matchRoundId != null) {
                await _tournamentApiService.completeMatch(
                  widget.tournament.id, 
                  match.id, 
                  match.team1Id, s1, 
                  match.team2Id, s2, 
                  status, 
                  matchRoundId, 
                  token
                );
              } else {
                await _matchApiService.updateMatchStatus(widget.tournament.id, match.id, status, token);
              }
              currentStatus = status;
              _loadMatches();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Statut mis à jour')));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
            } finally {
              setDialogState(() => isSaving = false);
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
                if (boCount > 1)
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
    );
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
