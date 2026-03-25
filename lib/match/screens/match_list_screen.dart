// Fichier : lib/features/match/screens/match_list_screen.dart
import 'package:flutter/material.dart';
import '../models/match_dto.dart';
import '../services/match_api_service.dart';
import '../../Tournois/repository_tournois.dart';
import '../../equipes/controller_equipe.dart';
import '../../equipes/model_equipe.dart';
import '../../Rounds/round_service.dart';
import '../widgets/match_card.dart';
import '../widgets/create_match_dialog.dart';

class MatchListScreen extends StatefulWidget {
  final String token;
  const MatchListScreen({super.key, required this.token});

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  final MatchApiService _apiService = MatchApiService();

  List<dynamic> _tournaments = [];
  List<dynamic> _rounds = [];
  List<Equipe> _teams = []; // On les charge ici pour les passer à la popup
  List<MatchDTO> _matches = [];

  String? _selectedTournamentId;
  String? _selectedRoundId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    setState(() => _isLoading = true);
    try {
      final tournois = await TournamentApiService().getTournaments();
      setState(() {
        _tournaments = tournois.map((t) => t.toJson()).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onTournamentSelected(String? tournamentId) async {
    if (tournamentId == null) return;
    setState(() {
      _selectedTournamentId = tournamentId;
      _selectedRoundId = null; // On réinitialise le round
      _isLoading = true;
    });

    try {
      // On charge tout ce qui concerne ce tournoi
      final rounds = await RoundService().getRounds(tournamentId);
      final teams = await EquipeController().getEquipes(tournamentId);
      final matches = await _apiService.getMatches(tournamentId);

      setState(() {
        _rounds = rounds.map((r) => r.toJson()).toList();
        _teams = teams;
        _matches = matches;
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Matchs"),
        backgroundColor: const Color(0xFF0D1B2A),
      ),
      body: Column(
        children: [
          // --- ZONE DES FILTRES ---
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1B2A3B),
            child: Column(
              children: [
                // Choix du Tournoi
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Sélectionner un Tournoi',
                  ),
                  dropdownColor: const Color(0xFF0D1B2A),
                  value: _selectedTournamentId,
                  items: _tournaments.map((t) {
                    return DropdownMenuItem<String>(
                      value: t['id']
                          .toString(), // Sécurité si l'ID est un entier
                      child: Text(t['name'] ?? 'Tournoi sans nom'),
                    );
                  }).toList(),
                  onChanged: _onTournamentSelected,
                ),
                const SizedBox(height: 10),

                // Choix du Round (Manche)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Sélectionner une Manche (Round)',
                  ),
                  dropdownColor: const Color(0xFF0D1B2A),
                  value: _selectedRoundId,
                  items: _rounds.map((r) {
                    return DropdownMenuItem<String>(
                      value: r['id'].toString(),
                      child: Text(r['name'] ?? 'Round sans nom'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedRoundId = val),
                ),
              ],
            ),
          ),

          // --- ZONE DE LA LISTE DES MATCHS ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _matches.isEmpty
                ? const Center(
                    child: Text(
                      "Sélectionnez un tournoi ou aucun match trouvé.",
                    ),
                  )
                : ListView.builder(
                    itemCount: _matches.length,
                    itemBuilder: (context, index) {
                      return MatchCard(match: _matches[index]);
                    },
                  ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_selectedTournamentId == null || _selectedRoundId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Veuillez d'abord sélectionner un tournoi et un round !",
                ),
              ),
            );
            return;
          }

          final matchCreated = await showDialog<bool>(
            context: context,
            builder: (context) => CreateMatchDialog(
              tournamentId: _selectedTournamentId!,
              roundId: _selectedRoundId!,
              teams: _teams, // On passe les vraies équipes à la popup !
              token: widget.token,
            ),
          );

          if (matchCreated == true) {
            _onTournamentSelected(_selectedTournamentId); // Rafraîchit la liste
          }
        },
        label: const Text(
          'Nouveau match',
          style: TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.green,
      ),
    );
  }
}
