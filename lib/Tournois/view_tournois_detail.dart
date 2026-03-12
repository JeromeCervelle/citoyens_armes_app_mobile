import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'modele_tournois.dart';
import 'repository_tournois.dart';
import 'view_tournois_form.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final String _authToken = dotenv.get('AUTH_TOKEN');
  late Future<Tournament> _tournamentFuture;

  @override
  void initState() {
    super.initState();
    _loadTournament();
  }

  void _loadTournament() {
    setState(() {
      _tournamentFuture = context
          .read<TournamentApiService>()
          .getTournament(widget.tournamentId, _authToken);
    });
  }

  Future<void> _deleteTournament(
    BuildContext context,
    Tournament tournament,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer le tournoi "${tournament.name}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;

    try {
      await context
          .read<TournamentApiService>()
          .deleteTournament(widget.tournamentId, _authToken);
      if (mounted) {
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate parent should refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression: $e')),
        );
      }
    }
  }

  void _navigateToEdit(Tournament tournament) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentFormScreen(tournament: tournament),
      ),
    );

    if (result == true && mounted) {
      _loadTournament(); // Refresh details
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détails du tournoi')),
      body: FutureBuilder<Tournament>(
        future: _tournamentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Tournoi introuvable.'));
          }

          final tournament = snapshot.data!;

          // Sécurisation de la conversion du nombre d'équipes en entier
          // Le parsing est maintenant géré dans le modèle, donc on peut directement utiliser la valeur.
          int teams = tournament.numberOfTeams;

          // Calcul de la puissance de 2 supérieure pour obtenir les rounds
          int nextPowerOf2 = 1;
          int rounds = 0;
          if (teams > 1) {
            while (nextPowerOf2 < teams) {
              nextPowerOf2 *= 2;
              rounds++;
            }
          }

          // Calcul des exemptions (byes) et des matchs totaux
          int byes = (teams > 1) ? (nextPowerOf2 - teams) : 0;
          int totalMatches = (teams > 0) ? (teams - 1) : 0;
          // --------------------------------------

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nom: ${tournament.name}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Format: ${tournament.game}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: ${tournament.status}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nombre d\'équipes: $teams',
                  style: const TextStyle(fontSize: 16),
                ),

                // --- AFFICHAGE DES NOUVELLES DONNÉES ---
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(), // Une petite ligne pour séparer les infos de l'arbre
                ),
                Text(
                  'Nombre de rounds: $rounds',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Matchs au total: $totalMatches',
                  style: const TextStyle(fontSize: 16),
                ),
                if (byes > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Exemptions au 1er tour: $byes',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
                // ---------------------------------------

                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _navigateToEdit(tournament),
                      icon: const Icon(Icons.edit),
                      label: const Text('Modifier'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _deleteTournament(context, tournament),
                      icon: const Icon(Icons.delete),
                      label: const Text('Supprimer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}