import 'dart:ui';
import 'package:flutter/material.dart';
import '../../equipes/controller_equipe.dart';
import '../../equipes/model_equipe.dart';
import '../../Tournois/modele_tournois.dart';
import '../match/match_list_view.dart';

class EquipesListView extends StatefulWidget {
  final Tournament tournament;
  final bool isAdmin;
  const EquipesListView({super.key, required this.tournament, required this.isAdmin});

  @override
  State<EquipesListView> createState() => _EquipesListViewState();
}

class _EquipesListViewState extends State<EquipesListView> {
  final EquipeController _equipeController = EquipeController();

  List<Equipe> _equipes = [];
  bool _isLoadingEquipes = true;

  @override
  void initState() {
    super.initState();
    _loadEquipes();
  }

  Future<void> _loadEquipes() async {
    setState(() => _isLoadingEquipes = true);
    try {
      final equipes = await _equipeController.getEquipes(widget.tournament.id);
      setState(() {
        _equipes = equipes;
        _isLoadingEquipes = false;
      });
    } catch (e) {
      setState(() => _isLoadingEquipes = false);
      _showError('Erreur chargement équipes: $e');
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
    final int maxTeams = widget.tournament.numberOfTeams;
    final bool isFull = _equipes.where((e) => !e.name.toUpperCase().contains('EXEMPT')).length >= maxTeams;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoadingEquipes
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
                    'Chargement des équipes...',
                    style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 1),
                  ),
                ],
              ),
            )
          : _buildEquipesList(),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: isFull ? null : () => _showCreateDialog(),
              backgroundColor: isFull ? Colors.grey.shade800 : const Color(0xFF00FF85),
              icon: Icon(isFull ? Icons.lock : Icons.add, color: Colors.black),
              label: Text(
                '${_equipes.where((e) => !e.name.toUpperCase().contains("EXEMPT")).length}/$maxTeams',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildEquipesList() {
    final filteredEquipes = _equipes.where((e) => e.name != "EXEMPTÉ").toList();
    
    if (filteredEquipes.isEmpty) {
      return const Center(
        child: Text('Aucune équipe trouvée', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredEquipes.length,
      itemBuilder: (context, index) {
        final eq = filteredEquipes[index];
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MatchListView(
                        tournament: widget.tournament,
                        teamId: eq.id,
                        title: 'Matchs de ${eq.name}',
                        isAdmin: widget.isAdmin,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF00FF85).withOpacity(0.1),
                        child: eq.imageUrl != null
                            ? Image.network(eq.imageUrl!)
                            : const Icon(Icons.group, color: Color(0xFF00FF85)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eq.name.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, letterSpacing: 1.1),
                            ),
                            Text('Points: ${eq.points ?? 0}', style: const TextStyle(color: Color(0xFF00FF85), fontSize: 12)),
                          ],
                        ),
                      ),
                      if (widget.isAdmin) ...[                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                          onPressed: () => _showEditDialog(eq),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _confirmDelete(eq),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
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

  void _showCreateDialog() {
    final int maxTeams = widget.tournament.numberOfTeams;
    final int realCount = _equipes.where((e) => !e.name.toUpperCase().contains('EXEMPT')).length;
    
    // Sécurité : bloquer si déjà plein
    if (realCount >= maxTeams) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Limite atteinte ($realCount/$maxTeams équipes)'), backgroundColor: Colors.orange),
      );
      return;
    }

    final nameController = TextEditingController();
    final imageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1526),
        title: const Text('CRÉER UNE ÉQUIPE', style: TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNeonField(nameController, 'Nom de l\'équipe'),
            _buildNeonField(imageController, 'URL du logo (facultatif)'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              final messenger = ScaffoldMessenger.of(context);
              final newEquipe = Equipe(
                name: nameController.text.trim(),
                imageUrl: imageController.text.trim().isEmpty ? null : imageController.text.trim(),
              );

              Navigator.pop(context);
              setState(() => _isLoadingEquipes = true);

              try {
                await _equipeController.createEquipe(widget.tournament.id, newEquipe);
                _loadEquipes();
                messenger.showSnackBar(const SnackBar(content: Text('✅ Équipe créée')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
              } finally {
                if (mounted) setState(() => _isLoadingEquipes = false);
              }
            },
            child: const Text('CRÉER', style: TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Equipe equipe) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1526),
        title: const Text('SUPPRIMER', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Supprimer "${equipe.name}" ?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANNULER', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoadingEquipes = true);
              try {
                await _equipeController.deleteEquipe(widget.tournament.id, equipe.id!);
                _loadEquipes();
                messenger.showSnackBar(const SnackBar(content: Text('🗑️ Équipe supprimée')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
                if (mounted) setState(() => _isLoadingEquipes = false);
              }
            },
            child: const Text('SUPPRIMER', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Equipe equipe) {
    final nameController = TextEditingController(text: equipe.name);
    final imageController = TextEditingController(text: equipe.imageUrl ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1526),
        title: const Text('MODIFIER L\'ÉQUIPE', style: TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNeonField(nameController, 'Nom de l\'équipe'),
            _buildNeonField(imageController, 'URL du logo'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              final messenger = ScaffoldMessenger.of(context);
              
              final updatedEquipe = Equipe(
                id: equipe.id,
                name: nameController.text.trim(),
                imageUrl: imageController.text.trim().isEmpty ? null : imageController.text.trim(),
                points: equipe.points,
              );

              Navigator.pop(context);
              setState(() => _isLoadingEquipes = true);

              try {
                await _equipeController.updateEquipe(widget.tournament.id, updatedEquipe);
                _loadEquipes();
                messenger.showSnackBar(const SnackBar(content: Text('✅ Équipe mise à jour')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
              } finally {
                if (mounted) setState(() => _isLoadingEquipes = false);
              }
            },
            child: const Text('ENREGISTRER', style: TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildNeonField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF85))),
        ),
      ),
    );
  }
}
