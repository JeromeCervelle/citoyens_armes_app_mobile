import 'package:flutter/material.dart';
import '../user/auth_service.dart';
import '../user/user_service.dart';
import '../user/user_model.dart';
import 'user/login_view.dart';
import 'user/admin_list_view.dart';
import 'theme/neon_components.dart';
import '../main.dart';
import '../Tournois/repository_tournois.dart';
import '../Tournois/modele_tournois.dart';
import 'tournois/tournois_detail_view.dart';
import '../Tournois/view_tournois_form.dart';
import '../equipes/controller_equipe.dart';
import '../match/models/match_dto.dart';
import '../match/services/match_api_service.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with RouteAware {
  User? _currentUser;
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final TournamentApiService _tournamentApiService = TournamentApiService();
  final EquipeController _equipeController = EquipeController();

  List<Tournament> _tournaments = [];
  List<Map<String, dynamic>> _ongoingMatches = [];
  Map<String, String> _teamNames = {};

  @override
  void initState() {
    super.initState();
    _refresh();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }
  
  @override
  void didPopNext() {
    // This is called when the top route has been popped off, and this route shows up.
    debugPrint("Dashboard redevient visible, actualisation...");
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      // Parallel fetch main data
      final results = await Future.wait([
        _userService.getCurrentUser(),
        _tournamentApiService.getTournaments(),
      ]);

      final user = results[0] as User?;
      final tournaments = results[1] as List<Tournament>;
      
      List<Map<String, dynamic>> ongoing = [];
      Map<String, String> teams = {};

      // Fetch all matches and teams in parallel for active tournaments
      final List<Future<void>> detailFutures = [];

      for (var t in tournaments) {
        if (t.status.toUpperCase() != 'FINISHED' && t.status.toUpperCase() != 'CANCELLED') {
          detailFutures.add(() async {
            try {
              final matches = await MatchApiService().getMatches(t.id);
              final pMatches = matches.where((m) => 
                m.status?.toUpperCase() == 'IN_PROGRESS' || 
                m.status?.toUpperCase() == 'STARTED'
              ).toList();
              
              if (pMatches.isNotEmpty) {
                final tTeams = await _equipeController.getEquipes(t.id);
                for (var team in tTeams) {
                  if (team.id != null) {
                    teams[team.id!] = team.name;
                  }
                }

                for (var m in pMatches) {
                  ongoing.add({
                    'match': m,
                    'tournament': t,
                  });
                }
              }
            } catch (e) {
              debugPrint("Erreur matches pour ${t.name}: $e");
            }
          }());
        }
      }

      await Future.wait(detailFutures);

      setState(() {
        _currentUser = user;
        _tournaments = tournaments;
        _ongoingMatches = ongoing;
        _teamNames = teams;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur globale _refresh: $e");
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur au chargement: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToForm([Tournament? tournament]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TournamentFormScreen(tournament: tournament)),
    );
    if (result == true && mounted) {
      _refresh();
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1526),
        title: const Text("Déconnexion"),
        content: const Text("Voulez-vous vous déconnecter ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await _authService.logout();
              _refresh();
            },
            child: const Text("DÉCONNEXION"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00FF85))),
      );
    }

    final filteredTournaments = _tournaments
        .where((t) => t.name.toLowerCase().contains(_searchQuery) || t.game.toLowerCase().contains(_searchQuery))
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          const NeonBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFF00FF85),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.emoji_events_outlined, color: Color(0xFF00FF85)),
                            SizedBox(width: 8),
                            Text("Tournois Citoyens", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (_currentUser != null) {
                                _showLogoutDialog(context);
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const LoginView()),
                                ).then((_) => _refresh());
                              }
                            },
                            borderRadius: BorderRadius.circular(25),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  if (_currentUser != null) ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(_currentUser!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text(_currentUser!.roleLabel, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _currentUser != null ? const Color(0xFF00FF85) : Colors.grey[800],
                                    child: Icon(
                                      _currentUser?.isSuperAdmin == true ? Icons.verified_user : (_currentUser?.isAdmin == true ? Icons.admin_panel_settings : Icons.person),
                                      size: 20,
                                      color: _currentUser != null ? Colors.black : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Section Administration (Accessible par tous les admins)
                    if (_currentUser?.isAdmin == true || _currentUser?.isSuperAdmin == true) ...[
                      Text(
                        _currentUser?.isSuperAdmin == true ? "SUPER ADMINISTRATION" : "MON PROFIL",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00FF85), letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminListView()));
                        },
                        child: GlassCard(
                          icon: _currentUser?.isSuperAdmin == true ? Icons.group_outlined : Icons.person_outline,
                          title: _currentUser?.isSuperAdmin == true ? "Gestion des admins" : "Gérer mon compte",
                          subtitle: _currentUser?.isSuperAdmin == true 
                            ? "Gérer, créer ou supprimer des modérateurs." 
                            : "Modifier votre nom, email ou mot de passe.",
                          accentColor: const Color(0xFF00FF85),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],

                    // Section Administration
                    if (_currentUser?.isAdmin == true || _currentUser?.isSuperAdmin == true) ...[
                      const Text("ACTIONS RAPIDES", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.2)),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _navigateToForm(),
                              child: const GlassCard(icon: Icons.emoji_events, title: "Tournoi", subtitle: "Créer un évènement"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],

                    const Text("RECHERCHE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        hintText: "Chercher un jeu ou tournoi...",
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Text("MATCHS EN COURS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 15),
                    _ongoingMatches.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: const Center(
                            child: Text("Aucun match en cours pour le moment", style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic)),
                          ),
                        )
                      : SizedBox(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _ongoingMatches.length,
                            itemBuilder: (context, index) {
                              final item = _ongoingMatches[index];
                              final match = item['match'] as MatchDTO;
                              final tournament = item['tournament'] as Tournament;

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TournoisDetailView(tournament: tournament),
                                    ),
                                  );
                                },
                                child: MatchNeonCard(
                                  team1: _teamNames[match.team1Id] ?? match.team1Id,
                                  team2: _teamNames[match.team2Id] ?? match.team2Id,
                                  score1: match.team1Point,
                                  score2: match.team2Point,
                                  tournamentName: tournament.name,
                                ),
                              );
                            },
                          ),
                        ),
                    const SizedBox(height: 30),

                    const Text("TOURNOIS DISPONIBLES", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 15),

                    filteredTournaments.isEmpty 
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Text('Aucun tournoi trouvé', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          )
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredTournaments.length,
                          itemBuilder: (context, index) {
                            final tournament = filteredTournaments[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => TournoisDetailView(tournament: tournament)),
                                ).then((_) => _refresh());
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TournamentTile(title: tournament.name, game: tournament.game, status: tournament.status),
                              ),
                            );
                          },
                        ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
