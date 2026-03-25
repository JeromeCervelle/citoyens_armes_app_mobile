import 'dart:ui';
import 'package:flutter/material.dart';
import '../../Rounds/round_service.dart';
import '../../Rounds/Model/round.dart';
import '../../Tournois/modele_tournois.dart';
import '../match/match_list_view.dart';
import '../../match/services/match_api_service.dart';
import '../../match/models/match_dto.dart';
import '../../equipes/controller_equipe.dart';

class RoundsListView extends StatefulWidget {
  final Tournament tournament;
  final bool isPoulesOnly;
  final bool isAdmin;

  const RoundsListView({
    super.key,
    required this.tournament,
    required this.isAdmin,
    this.isPoulesOnly = false,
  });

  @override
  State<RoundsListView> createState() => _RoundsListViewState();
}

class _RoundsListViewState extends State<RoundsListView> {
  final RoundService _roundService = RoundService();
  final MatchApiService _matchService = MatchApiService();
  final EquipeController _equipeController = EquipeController();

  List<Round> _rounds = [];
  List<MatchDTO> _allMatches = [];
  Map<String, String> _teamNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final roundsFuture = _roundService.getRounds(widget.tournament.id);
      final matchesFuture = _matchService.getMatches(widget.tournament.id);
      final teamsFuture = _equipeController.getEquipes(widget.tournament.id);

      final results = await Future.wait([
        roundsFuture,
        matchesFuture,
        teamsFuture,
      ]);

      final rounds = results[0] as List<Round>;
      final matches = results[1] as List<MatchDTO>;
      final teams = results[2] as List<dynamic>;

      if (mounted) {
        setState(() {
          _teamNames = {for (var t in teams) t.id: t.name};
          _allMatches = matches;
          if (widget.isPoulesOnly) {
            _rounds = rounds
                .where((r) => r.name.toUpperCase().startsWith('POULE'))
                .toList();
          } else {
            _rounds = rounds
                .where((r) => !r.name.toUpperCase().startsWith('POULE'))
                .toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError('Erreur chargement: $e');
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(color: Color(0xFF00FF85), strokeWidth: 3),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Chargement des rounds...',
                    style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 1),
                  ),
                ],
              ),
            )
          : _buildRoundList(),
    );
  }

  Widget _buildRoundList() {
    if (_rounds.isEmpty) {
      return const Center(
        child: Text(
          'Aucun round trouvé',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rounds.length,
      itemBuilder: (context, index) {
        final r = _rounds[index];

        if (widget.isPoulesOnly) {
          final poolMatches = _allMatches
              .where((m) => r.matchIds.contains(m.id))
              .toList();
          final standings = Tournament.computePoolStandings(
            poolMatches,
            _teamNames,
          );

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
                child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF00FF85).withOpacity(0.1),
                foregroundColor: const Color(0xFF00FF85),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                r.name.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
              subtitle: Text(
                'Format: BO${r.format} • ${standings.length} équipes',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: const Icon(Icons.expand_more, color: Color(0xFF00FF85)),
              iconColor: const Color(0xFF00FF85),
              collapsedIconColor: Colors.white54,
              children: [
                _buildStandingsTable(standings),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () => _navigateToMatches(r),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF85).withOpacity(0.1),
                      foregroundColor: const Color(0xFF00FF85),
                      side: const BorderSide(
                        color: Color(0xFF00FF85),
                        width: 0.5,
                      ),
                    ),
                    child: const Text('VOIR TOUS LES MATCHS'),
                  ),
                ),
                ],
              ),
            ),
          ),
        );
      }

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
              child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF00FF85).withOpacity(0.1),
              foregroundColor: const Color(0xFF00FF85),
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              r.name.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
            subtitle: Text(
              'Format: BO${r.format}',
              style: const TextStyle(color: Color(0xFF00FF85), fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => _navigateToMatches(r),
          ),
        ),
      ),
    );
  },
    );
  }

  Widget _buildStandingsTable(List<TeamStanding> standings) {
    if (standings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Aucun match terminé',
          style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingTextStyle: const TextStyle(
          color: Color(0xFF00FF85),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        columns: const [
          DataColumn(label: Text('POS')),
          DataColumn(label: Text('ÉQUIPE')),
          DataColumn(label: Text('V')),
          DataColumn(label: Text('Buts +')),
          DataColumn(label: Text('Buts -')),
        ],
        rows: standings.asMap().entries.map((entry) {
          int i = entry.key;
          TeamStanding s = entry.value;
          return DataRow(
            cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(s.teamName)),
              DataCell(Text('${s.wins}')),
              DataCell(Text('${s.goals}')),
              DataCell(Text('${s.goalsAgainst}')),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _navigateToMatches(Round r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchListView(
          tournament: widget.tournament,
          roundId: r.id,
          title: 'Matchs: ${r.name}',
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }
}
