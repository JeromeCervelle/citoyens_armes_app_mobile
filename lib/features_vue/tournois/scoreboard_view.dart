import 'package:flutter/material.dart';
import '../../match/services/match_api_service.dart';
import '../../match/models/match_dto.dart';
import '../../equipes/controller_equipe.dart';
import '../../equipes/model_equipe.dart';
import '../../Tournois/modele_tournois.dart';

class TeamStats {
  final Equipe equipe;
  int goalsScored = 0;
  int goalsAgainst = 0;
  int matchesPlayed = 0;
  int wins = 0;
  int losses = 0;
  int draws = 0;

  TeamStats(this.equipe);

  int get goalDiff => goalsScored - goalsAgainst;
  int get points => (wins * 3) + (draws * 1);
}

class ScoreboardView extends StatefulWidget {
  final Tournament tournament;

  const ScoreboardView({super.key, required this.tournament});

  @override
  State<ScoreboardView> createState() => _ScoreboardViewState();
}

class _ScoreboardViewState extends State<ScoreboardView> {
  final MatchApiService _matchApiService = MatchApiService();
  final EquipeController _equipeController = EquipeController();

  List<TeamStats> _stats = [];
  bool _isLoading = true;
  String? _error;
  String _sortColumn = 'VIC'; // Default sort
  bool _isAscending = false; // Default descending (better for ranking)

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(ScoreboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tournament.id != widget.tournament.id) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tournamentId = widget.tournament.id;
      final results = await Future.wait([
        _matchApiService.getMatches(tournamentId),
        _equipeController.getEquipes(tournamentId),
      ]);

      final List<MatchDTO> matches = (results[0] as List<dynamic>)
          .map((m) => m is MatchDTO ? m : MatchDTO.fromJson(m as Map<String, dynamic>))
          .toList();
      final List<Equipe> allEquipes = results[1] as List<Equipe>;
      final List<Equipe> equipes = allEquipes.where((e) => !e.name.toUpperCase().contains('EXEMPT')).toList();
      
      // Set of IDs for EXEMPTÉ teams to exclude their matches from stats
      final Set<String> byeIds = allEquipes
          .where((e) => e.name.toUpperCase().contains('EXEMPT'))
          .map((e) => e.id!)
          .toSet();

      final Map<String, TeamStats> statsMap = {
        for (var eq in equipes) eq.id!: TeamStats(eq)
      };

      for (var m in matches) {
        if (m.status?.toUpperCase() != 'FINISHED') continue;
        // Skip matches involving EXEMPTÉ teams - they are artificial and would falsify stats
        if (byeIds.contains(m.team1Id) || byeIds.contains(m.team2Id)) continue;
        
        final s1 = statsMap[m.team1Id];
        final s2 = statsMap[m.team2Id];

        if (s1 != null) {
          s1.goalsScored += m.team1Point;
          s1.goalsAgainst += m.team2Point;
          s1.matchesPlayed++;
          if (m.team1Point > m.team2Point) s1.wins++;
          else if (m.team1Point < m.team2Point) s1.losses++;
          else s1.draws++;
        }

        if (s2 != null) {
          s2.goalsScored += m.team2Point;
          s2.goalsAgainst += m.team1Point;
          s2.matchesPlayed++;
          if (m.team2Point > m.team1Point) s2.wins++;
          else if (m.team2Point < m.team1Point) s2.losses++;
          else s2.draws++;
        }
      }

      _sortStats(statsMap.values.toList());

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _sortStats(List<TeamStats> stats) {
    stats.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'VIC':
          cmp = a.wins.compareTo(b.wins);
          break;
        case 'BUTS':
          cmp = a.goalsScored.compareTo(b.goalsScored);
          break;
        case 'BC':
          cmp = a.goalsAgainst.compareTo(b.goalsAgainst);
          break;
        case 'TEAM':
          cmp = a.equipe.name.toLowerCase().compareTo(b.equipe.name.toLowerCase());
          break;
        // Removed 'POINTS' case
        default: // Default to sorting by wins if _sortColumn is not recognized
          cmp = a.wins.compareTo(b.wins);
          if (cmp == 0) cmp = a.goalsScored.compareTo(b.goalsScored);
          if (cmp == 0) cmp = b.goalsAgainst.compareTo(a.goalsAgainst); // Moins de buts encaissés = mieux
          break;
      }
      return _isAscending ? cmp : -cmp;
    });
    setState(() {
      _stats = stats;
    });
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _isAscending = !_isAscending;
      } else {
        _sortColumn = column;
        _isAscending = false;
      }
      _sortStats(_stats);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(color: Color(0xFF00FF85), strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(
              'Chargement du classement...',
              style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 1),
            ),
          ],
        ),
      );
    }
    if (_error != null) return Center(child: Text('Erreur: $_error', style: const TextStyle(color: Colors.redAccent)));
    if (_stats.isEmpty) return const Center(child: Text('Aucune donnée de classement disponible', style: TextStyle(color: Colors.white54)));

    return Container(
      color: Colors.transparent,
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF00FF85),
        backgroundColor: const Color(0xFF0D1526),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _stats.length,
                itemBuilder: (context, index) => _buildStatRow(index, _stats[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          _buildHeaderCell('#', width: 30, isSortable: false),
          Expanded(child: _buildHeaderCell('Équipe', column: 'TEAM', alignLeft: true)),
          _buildHeaderCell('VIC', width: 65, column: 'VIC'),
          _buildHeaderCell('BUTS +', width: 65, column: 'BUTS'),
          _buildHeaderCell('BUTS -', width: 65, column: 'BC'),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {double? width, String? column, bool isSortable = true, bool alignLeft = false}) {
    final bool isActive = _sortColumn == column;
    
    return GestureDetector(
      onTap: isSortable && column != null ? () => _onSort(column) : null,
      child: Container(
        width: width,
        child: Row(
          mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
            ),
            if (isActive)
              Icon(
                _isAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: Colors.white,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(int index, TeamStats stat) {
    final color = index % 2 == 0 ? Colors.white.withOpacity(0.02) : Colors.transparent;
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 2),
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: index < 3 ? FontWeight.bold : FontWeight.normal,
                  color: index == 0 ? Colors.amberAccent : (index == 1 ? Colors.grey.shade400 : (index == 2 ? Colors.brown.shade300 : Colors.white70)),
                ),
              ),
            ),
            Expanded(
              child: Text(
                stat.equipe.name,
                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 65, child: Text('${stat.wins}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
            SizedBox(
              width: 65,
              child: Text(
                '${stat.goalsScored}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF85)),
              ),
            ),
            SizedBox(width: 65, child: Text('${stat.goalsAgainst}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
          ],
        ),
      ),
    );
  }
}
