import 'package:flutter/material.dart';
import '../../Tournois/repository_tournois.dart';
import '../../Tournois/modele_tournois.dart';
import '../../Tournois/view_tournois_form.dart';
import '../../user/user_service.dart';
import '../../user/user_model.dart';
import 'tournois_detail_view.dart';

class TournoisListView extends StatefulWidget {
  const TournoisListView({super.key});

  @override
  State<TournoisListView> createState() => _TournoisListViewState();
}

class _TournoisListViewState extends State<TournoisListView> {
  final TournamentApiService _apiService = TournamentApiService();
  final UserService _userService = UserService();
  
  List<Tournament> _tournaments = [];
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      final tournaments = await _apiService.getTournaments();
      final user = await _userService.getCurrentUser();
      setState(() {
        _tournaments = tournaments;
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToForm([Tournament? tournament]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentFormScreen(tournament: tournament),
      ),
    );
    if (result == true && mounted) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _tournaments.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Aucun tournoi trouvé', style: TextStyle(color: Colors.grey, fontSize: 18)),
                    if ((_currentUser?.isAdmin == true) || (_currentUser?.isSuperAdmin == true))
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToForm(),
                          icon: const Icon(Icons.add),
                          label: const Text('Créer un tournoi'),
                        ),
                      ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _tournaments.length,
                itemBuilder: (context, index) {
                  final t = _tournaments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Jeu: ${t.game}', style: TextStyle(color: Colors.blue.shade700)),
                          Text('Équipes: ${t.numberOfTeams}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusBadge(status: t.status),
                          if ((_currentUser?.isAdmin == true) || (_currentUser?.isSuperAdmin == true)) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _navigateToForm(t),
                            ),
                          ],
                        ],
                      ),
                      onTap: () {
                        // For the unified view, when an admin taps on a tournament, 
                        // they go to the detail view and from there they can manage it.
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TournoisDetailView(tournament: t),
                          ),
                        ).then((_) {
                          // Refresh on back in case status or details changed inside
                          _refresh();
                        });
                      },
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: ((_currentUser?.isAdmin == true) || (_currentUser?.isSuperAdmin == true))
          ? FloatingActionButton(
              onPressed: () => _navigateToForm(),
              backgroundColor: Colors.blue.shade800,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toUpperCase()) {
      case 'OPEN':
        color = Colors.green;
        break;
      case 'DRAFT':
        color = Colors.orange;
        break;
      case 'FINISHED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
