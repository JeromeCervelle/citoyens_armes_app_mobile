import 'package:flutter/material.dart';
import '../../Tournois/modele_tournois.dart';
import '../../Tournois/repository_tournois.dart';
import '../../Tournois/view_tournois_form.dart';
import '../../user/user_service.dart';
import '../../user/auth_service.dart';
import '../../user/user_model.dart';
import '../equipes/equipes_list_view.dart';
import '../rounds/rounds_list_view.dart';
import '../../Rounds/round_service.dart';
import 'bracket_view.dart';
import 'scoreboard_view.dart';
import '../theme/neon_components.dart';

class TournoisDetailView extends StatefulWidget {
  final Tournament tournament;

  const TournoisDetailView({super.key, required this.tournament});

  @override
  State<TournoisDetailView> createState() => _TournoisDetailViewState();
}

class _TournoisDetailViewState extends State<TournoisDetailView>
    with TickerProviderStateMixin {
  final UserService _userService = UserService();
  final TournamentApiService _apiService = TournamentApiService();
  final RoundService _roundService = RoundService();

  late TabController _tabController;
  String _authToken = '';
  User? _currentUser;
  bool _isGenerating = false;
  String _loadingMessage = 'Veuillez patienter...';
  late Tournament _currentTournament;
  int _roundsCount = -1; // -1 means loading/unknown state
  bool _hasPoules = false;
  bool _hasBracket = false;
  bool _dataChanged = false;

  @override
  void initState() {
    super.initState();
    _currentTournament = widget.tournament;
    _tabController = TabController(
      length: 4,
      vsync: this,
    ); // Initial length, will be updated
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _checkUserRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    final user = await _userService.getCurrentUser();
    final token = await AuthService().getToken() ?? '';
    if (mounted) {
      setState(() {
        _currentUser = user;
        _authToken = token;
      });
      _fetchRoundsCount();
    }
  }

  Future<void> _refreshTournament() async {
    try {
      final updated = await _apiService.getTournament(_currentTournament.id);
      if (mounted) {
        setState(() => _currentTournament = updated);
        _fetchRoundsCount();
      }
    } catch (e) {
      debugPrint("Could not refresh tournament: $e");
    }
  }

  Future<void> _fetchRoundsCount() async {
    try {
      final rounds = await _roundService.getRounds(
        _currentTournament.id,
        token: _authToken,
      );
      final hasPoules = rounds.any(
        (r) => r.name.toUpperCase().startsWith('POULE'),
      );
      final hasBracket = rounds.any(
        (r) => !r.name.toUpperCase().startsWith('POULE'),
      );
      if (mounted) {
        setState(() {
          _roundsCount = rounds.length;
          _hasPoules = hasPoules;
          _hasBracket = hasBracket;
        });
      }
    } catch (e) {
      debugPrint("Could not fetch rounds count: $e");
    }
  }

  void _deleteTournament() async {
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1526),
        title: const Text(
          'CONFIRMER LA SUPPRESSION',
          style: TextStyle(
            color: Color(0xFF00FF85),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer le tournoi "${_currentTournament.name}" ?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'ANNULER',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context, true);
              _performDelete(messenger);
            },
            child: const Text(
              'SUPPRIMER',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _performDelete(ScaffoldMessengerState messenger) async {
    if (!mounted) return;
    setState(() {
      _isGenerating = true;
      _loadingMessage = 'Suppression du tournoi';
    });
    try {
      await _apiService.deleteTournament(_currentTournament.id, _authToken);
      if (mounted) Navigator.pop(context, true); // Return to list
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TournamentFormScreen(tournament: _currentTournament),
      ),
    );
    if (result == true) {
      setState(() => _dataChanged = true);
      _refreshTournament();
    }
  }

  void _showTournamentStatusDialog() {
    String currentStatus = _currentTournament.status;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1526),
          title: const Text(
            'CHANGER LE STATUT',
            style: TextStyle(
              color: Color(0xFF00FF85),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: DropdownButtonFormField<String>(
            value: currentStatus,
            dropdownColor: const Color(0xFF16213E),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Statut',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00FF85)),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'DRAFT', child: Text('Brouillon')),
              DropdownMenuItem(value: 'OPEN', child: Text('Ouvert')),
              DropdownMenuItem(value: 'ONGOING', child: Text('En cours')),
              DropdownMenuItem(value: 'FINISHED', child: Text('Terminé')),
              DropdownMenuItem(value: 'CANCELLED', child: Text('Annulé')),
            ],
            onChanged: (val) => setDialogState(() => currentStatus = val!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'ANNULER',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                setState(() {
                  _isGenerating = true;
                  _loadingMessage = 'Mis à jour du statut';
                });
                try {
                  await _apiService.updateTournamentStatus(
                    _currentTournament.id,
                    currentStatus,
                    _authToken,
                  );
                  setState(() => _dataChanged = true);
                  await _refreshTournament();
                } catch (e) {
                  if (mounted)
                    messenger.showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                } finally {
                  if (mounted) setState(() => _isGenerating = false);
                }
              },
              child: const Text(
                'VALIDER',
                style: TextStyle(
                  color: Color(0xFF00FF85),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGeneratePoolsDialog() {
    final poolsController = TextEditingController(text: '4');
    final qualifiedController = TextEditingController(text: '2');
    final poolBoController = TextEditingController(text: '1');
    final Map<int, TextEditingController> bracketControllers = {};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          int totalQualified =
              (int.tryParse(poolsController.text) ?? 0) *
              (int.tryParse(qualifiedController.text) ?? 0);
          int nextPowerOf2 = Tournament.calculateNextPowerOf2(totalQualified);
          int bracketRounds = Tournament.calculateBracketRounds(totalQualified);

          if (bracketControllers.length != bracketRounds) {
            bracketControllers.clear();
            for (int i = 0; i < bracketRounds; i++)
              bracketControllers[i] = TextEditingController(text: '1');
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF0D1526),
            title: const Text(
              'POULES + ARBRE',
              style: TextStyle(
                color: Color(0xFF00FF85),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNeonField(
                    poolsController,
                    'Nombre de poules',
                    (val) => setDialogState(() {}),
                  ),
                  _buildNeonField(
                    qualifiedController,
                    'Qualifiés par poule',
                    (val) => setDialogState(() {}),
                  ),
                  _buildNeonField(poolBoController, 'Format Poules (BO)'),
                  if (bracketRounds > 0) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'FORMATS ARBRE (BO) :',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(bracketRounds, (i) {
                      String roundLabel = Tournament.getRoundLabel(
                        nextPowerOf2 >> (i + 1),
                      );
                      return _buildNeonField(
                        bracketControllers[i]!,
                        roundLabel,
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'ANNULER',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () async {
                  int p = int.tryParse(poolsController.text) ?? 2;
                  int q = int.tryParse(qualifiedController.text) ?? 2;
                  int pBo = int.tryParse(poolBoController.text) ?? 1;
                  List<int> bFormats = bracketControllers.values
                      .map((c) => int.tryParse(c.text) ?? 1)
                      .toList();

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  setState(() {
                    _isGenerating = true;
                    _loadingMessage = 'Génération du tournoi';
                  });
                  try {
                    await _apiService.generatePools(
                      _currentTournament.id,
                      p,
                      q,
                      _authToken,
                      poolFormat: pBo,
                      bracketFormats: bFormats,
                    );
                    setState(() => _dataChanged = true);
                    await _refreshTournament();
                  } catch (e) {
                    if (mounted)
                      messenger.showSnackBar(
                        SnackBar(content: Text('Erreur: $e')),
                      );
                  } finally {
                    if (mounted) setState(() => _isGenerating = false);
                  }
                },
                child: const Text(
                  'GÉNÉRER',
                  style: TextStyle(
                    color: Color(0xFF00FF85),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showGenerateBracketDialog() {
    int nextPowerOf2 = Tournament.calculateNextPowerOf2(
      _currentTournament.numberOfTeams,
    );
    int totalRounds = Tournament.calculateBracketRounds(
      _currentTournament.numberOfTeams,
    );
    List<TextEditingController> controllers = List.generate(
      totalRounds,
      (_) => TextEditingController(text: '1'),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1526),
        title: const Text(
          'ARBRE DIRECT',
          style: TextStyle(
            color: Color(0xFF00FF85),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(totalRounds, (i) {
              String roundName = Tournament.getRoundLabel(
                nextPowerOf2 >> (i + 1),
              );
              return _buildNeonField(controllers[i], 'Format $roundName (BO)');
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ANNULER',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              List<int> formats = controllers
                  .map((c) => int.tryParse(c.text) ?? 1)
                  .toList();
              final messenger = ScaffoldMessenger.of(
                context,
              ); // Capture avant le pop
              Navigator.pop(context);
              setState(() {
                _isGenerating = true;
                _loadingMessage = 'Génération de l\'arbre';
              });
              try {
                await _apiService.generateBracket(
                  _currentTournament.id,
                  _authToken,
                  formats: formats,
                );
                setState(() => _dataChanged = true);
                await _refreshTournament();
              } catch (e) {
                if (mounted)
                  messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
              } finally {
                if (mounted) setState(() => _isGenerating = false);
              }
            },
            child: const Text(
              'GÉNÉRER',
              style: TextStyle(
                color: Color(0xFF00FF85),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin =
        (_currentUser?.isAdmin == true) || (_currentUser?.isSuperAdmin == true);

    final List<Widget> tabs = [
      const Tab(text: 'Détails', icon: Icon(Icons.info_outline)),
    ];
    if (_hasPoules) {
      tabs.add(const Tab(text: 'Poules', icon: Icon(Icons.grid_view)));
    }
    if (_hasBracket) {
      tabs.add(const Tab(text: 'Arbre', icon: Icon(Icons.account_tree)));
    }
    tabs.addAll([
      const Tab(text: 'Équipes', icon: Icon(Icons.group)),
      const Tab(text: 'Classement', icon: Icon(Icons.emoji_events)),
      const Tab(text: 'Rounds', icon: Icon(Icons.layers)),
    ]);

    final List<Widget> tabViews = [_buildInfoTab(isAdmin)];
    if (_hasPoules) {
      tabViews.add(
        RoundsListView(
          tournament: _currentTournament,
          isPoulesOnly: true,
          isAdmin: isAdmin,
        ),
      );
    }
    if (_hasBracket) {
      tabViews.add(
        BracketView(tournament: _currentTournament, isAdmin: isAdmin),
      );
    }
    tabViews.addAll([
      EquipesListView(tournament: _currentTournament, isAdmin: isAdmin),
      ScoreboardView(tournament: _currentTournament),
      RoundsListView(tournament: _currentTournament, isAdmin: isAdmin),
    ]);

    int teamsTabIndex = 1 + (_hasPoules ? 1 : 0) + (_hasBracket ? 1 : 0);

    // Update tab controller if length changed
    if (_tabController.length != tabs.length) {
      _tabController.dispose();
      _tabController = TabController(
        length: tabs.length,
        vsync: this,
        initialIndex: 0,
      );
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging && mounted) {
          setState(() {});
        }
      });
    }

    final scaffoldBody = Stack(
      children: [
        const NeonBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton:
              (isAdmin &&
                  _roundsCount == 0 &&
                  !_isGenerating &&
                  _tabController.index != teamsTabIndex)
              ? _buildFab()
              : null,
          appBar: AppBar(
            title: Text(
              _currentTournament.name.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF00FF85),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context, _dataChanged),
            ),
            actions: [
              if (isAdmin && !_isGenerating)
                PopupMenuButton<String>(
                  color: const Color(0xFF0D1526),
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _navigateToEdit();
                        break;
                      case 'status':
                        _showTournamentStatusDialog();
                        break;
                      case 'pools':
                        _showGeneratePoolsDialog();
                        break;
                      case 'bracket':
                        _showGenerateBracketDialog();
                        break;
                      case 'delete':
                        _deleteTournament();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit, color: Colors.blue),
                        title: Text(
                          'Éditer Tournoi',
                          style: TextStyle(color: Colors.white),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'status',
                      child: ListTile(
                        leading: Icon(
                          Icons.compare_arrows,
                          color: Colors.orange,
                        ),
                        title: Text(
                          'Changer Statut',
                          style: TextStyle(color: Colors.white),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (_roundsCount == 0) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'pools',
                        child: ListTile(
                          leading: Icon(
                            Icons.grid_on,
                            color: Color(0xFF00FF85),
                          ),
                          title: Text(
                            'Générer Poules + Arbre',
                            style: TextStyle(color: Colors.white),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'bracket',
                        child: ListTile(
                          leading: Icon(
                            Icons.account_tree,
                            color: Colors.purpleAccent,
                          ),
                          title: Text(
                            'Générer Arbre direct',
                            style: TextStyle(color: Colors.white),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.redAccent),
                        title: Text(
                          'Supprimer',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFF00FF85),
              labelColor: const Color(0xFF00FF85),
              unselectedLabelColor: Colors.white54,
              tabs: tabs,
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: tabViews,
          ),
        ),
        // Overlay bloquant pendant la génération
        if (_isGenerating)
          AbsorbPointer(
            absorbing: true,
            child: Container(
              color: Colors.black.withOpacity(0.75),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 32,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1526),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00FF85).withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FF85).withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 52,
                          height: 52,
                          child: CircularProgressIndicator(
                            color: Color(0xFF00FF85),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _loadingMessage.toUpperCase(),
                          style: TextStyle(
                            color: Color(0xFF00FF85),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Veuillez patienter...',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result == null && _dataChanged) {
          // Handled by return value of Navigator.pop if needed,
          // but DashboardView uses .then((_) => refresh) which catches everything.
        }
      },
      child: scaffoldBody,
    );
  }

  Widget _buildInfoTab(bool isAdmin) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gamepad, color: Color(0xFF00FF85)),
              const SizedBox(width: 12),
              Text(
                'Jeu: ${_currentTournament.game}',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.info, color: Color(0xFF00FF85)),
              const SizedBox(width: 12),
              Text(
                'Statut: ${_currentTournament.status}',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.group, color: Color(0xFF00FF85)),
              const SizedBox(width: 12),
              Text(
                'Nombre d\'équipes: ${_currentTournament.numberOfTeams}',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (isAdmin) ...[
            const SizedBox(height: 48),
            const Text(
              'ZONE DE DÉBOGAGE (ADMIN ONLY) :',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.orangeAccent,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildDebugBtn(
                  'Auto-remplir Équipes',
                  Icons.group_add,
                  Colors.blue,
                  () => _handleDebugAction(
                    () => _apiService.debugCreateAllTeams(
                      _currentTournament.id,
                      _currentTournament.numberOfTeams,
                      _authToken,
                    ),
                    'Équipes créées avec succès',
                  ),
                ),
                _buildDebugBtn(
                  'Auto-scores Poules',
                  Icons.casino,
                  Colors.orange,
                  () => _handleDebugAction(
                    () => _apiService.debugFillPoolScores(
                      _currentTournament.id,
                      _authToken,
                    ),
                    'Scores de poules remplis',
                  ),
                ),
                _buildDebugBtn(
                  'Stats Scoreboard',
                  Icons.refresh,
                  Colors.green,
                  _refreshTournament,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleDebugAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isGenerating = true;
      _loadingMessage = 'Action debug en cours';
    });
    try {
      await action();
      setState(() => _dataChanged = true);
      await _refreshTournament();
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Widget _buildDebugBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: _isGenerating ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget? _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _isGenerating ? null : _showGenerateOptions,
      backgroundColor: const Color(0xFF3B82F6),
      icon: const Icon(Icons.bolt, color: Colors.white),
      label: const Text(
        'Générer le tournoi',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showGenerateOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1526),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFF00FF85), width: 0.5),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OPTIONS DE GÉNÉRATION',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF85),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.grid_on, color: Color(0xFF00FF85)),
              title: const Text(
                'Poules + Arbre final',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Répartit les équipes en groupes',
                style: TextStyle(color: Colors.white54),
              ),
              onTap: () {
                Navigator.pop(context);
                _showGeneratePoolsDialog();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.account_tree,
                color: Colors.purpleAccent,
              ),
              title: const Text(
                'Arbre direct',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Élimination directe immédiate',
                style: TextStyle(color: Colors.white54),
              ),
              onTap: () {
                Navigator.pop(context);
                _showGenerateBracketDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNeonField(
    TextEditingController controller,
    String label, [
    Function(String)? onChanged,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00FF85)),
          ),
        ),
      ),
    );
  }
}
