import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'modele_tournois.dart';
import 'repository_tournois.dart';
import 'package:provider/provider.dart';
import 'view_tournois_form.dart';
import 'view_tournois_detail.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  final String _authToken = dotenv.get('AUTH_TOKEN');
  late Future<List<Tournament>> _tournamentsFuture;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  void _loadTournaments() {
    setState(() {
      _tournamentsFuture = context
          .read<TournamentApiService>()
          .getTournaments(_authToken);
    });
  }

  void _navigateToForm([Tournament? tournament]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentFormScreen(tournament: tournament),
      ),
    );

    if (result == true && mounted) {
      _loadTournaments(); // Refresh list if a tournament was added/edited
    }
  }

  void _navigateToDetail(Tournament tournament) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TournamentDetailScreen(tournamentId: tournament.id),
      ),
    );

    if (result == true && mounted) {
      _loadTournaments(); // Refresh list if a tournament was deleted or edited within detail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournois')),
      body: FutureBuilder<List<Tournament>>(
        future: _tournamentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun tournoi trouvé.'));
          }

          final tournaments = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _loadTournaments(),
            child: ListView.builder(
              itemCount: tournaments.length,
              itemBuilder: (context, index) {
                final tournament = tournaments[index];
                return ListTile(
                  title: Text(tournament.name),
                  subtitle: Text(
                    'Jeu: ${tournament.game} - Statut: ${tournament.status}',
                  ),
                  onTap: () => _navigateToDetail(tournament),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _navigateToForm(tournament),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
