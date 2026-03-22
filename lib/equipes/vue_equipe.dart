import 'package:flutter/material.dart';
import 'controller_equipe.dart';
import 'model_equipe.dart';

class EquipesPage extends StatefulWidget {
  final String tournamentId;

  const EquipesPage({super.key, required this.tournamentId});

  @override
  State<EquipesPage> createState() => _EquipesPageState();
}

class _EquipesPageState extends State<EquipesPage> {
  final EquipeController controller = EquipeController();
  
  List<Equipe> equipes = []; // Liste source (toutes les équipes)
  List<Equipe> filteredEquipes = []; // Liste filtrée (ce qu'on affiche)
  List<Map<String, dynamic>> tournois = []; 
  
  String? selectedTournamentId; 
  bool isLoading = true;

  // Contrôleur pour la barre de recherche
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialLoad();
    // On écoute les changements du texte pour filtrer en temps réel
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      filteredEquipes = equipes
          .where((e) => e.name.toLowerCase().contains(searchController.text.toLowerCase()))
          .toList();
    });
  }

  Future<void> _initialLoad() async {
    try {
      final tData = await controller.getTournaments();
      setState(() {
        tournois = tData;
        if (tournois.isNotEmpty) {
          selectedTournamentId = tournois.first['id'];
        }
      });
      if (selectedTournamentId != null) {
        await loadEquipes();
      }
    } catch (e) {
      _showSnackBar("❌ Erreur chargement tournois", isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> loadEquipes() async {
    if (selectedTournamentId == null) return;
    setState(() => isLoading = true);
    try {
      final data = await controller.getEquipes(selectedTournamentId!);
      setState(() {
        equipes = data;
        filteredEquipes = data; // On réinitialise l'affichage
        searchController.clear(); // On vide la recherche lors d'un changement de tournoi
      });
    } catch (e) {
      _showSnackBar("❌ Erreur chargement équipes", isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  // --- DELETE / CREATE / UPDATE (Mêmes fonctions mais utilisant selectedTournamentId!) ---
  void deleteEquipe(String id) async {
    if (selectedTournamentId == null) return;
    try {
      await controller.deleteEquipe(selectedTournamentId!, id);
      _showSnackBar("🗑️ Équipe supprimée");
      loadEquipes();
    } catch (e) {
      _showSnackBar("❌ Erreur suppression", isError: true);
    }
  }

  void showForm({Equipe? equipe}) {
    final nameController = TextEditingController(text: equipe?.name ?? "");
    final imageController = TextEditingController(text: equipe?.imageUrl ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(equipe == null ? "Ajouter équipe" : "Modifier équipe"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nom équipe")),
            TextField(controller: imageController, decoration: const InputDecoration(labelText: "URL du logo")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            child: const Text("Sauvegarder"),
            onPressed: () async {
              if (nameController.text.trim().isEmpty || selectedTournamentId == null) return;
              final newEquipe = Equipe(
                id: equipe?.id,
                name: nameController.text.trim(),
                imageUrl: imageController.text.trim(),
              );
              try {
                if (equipe == null) {
                  await controller.createEquipe(selectedTournamentId!, newEquipe);
                  _showSnackBar("✅ Équipe ajoutée");
                } else {
                  await controller.updateEquipe(selectedTournamentId!, newEquipe);
                  _showSnackBar("✏️ Équipe modifiée");
                }
                Navigator.pop(context);
                loadEquipes();
              } catch (e) {
                _showSnackBar("❌ Erreur enregistrement", isError: true);
              }
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Tournois"),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130), // Hauteur augmentée pour la barre de recherche
          child: Column(
            children: [
              // Menu déroulant des tournois
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: DropdownButtonFormField<String>(
                  value: selectedTournamentId,
                  decoration: const InputDecoration(
                    filled: true, fillColor: Colors.white, border: OutlineInputBorder(),
                    labelText: "Tournoi sélectionné",
                  ),
                  items: tournois.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['name']))).toList(),
                  onChanged: (value) {
                    setState(() => selectedTournamentId = value);
                    loadEquipes();
                  },
                ),
              ),
              // Barre de recherche
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Rechercher une équipe...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: selectedTournamentId == null ? null : () => showForm(),
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredEquipes.isEmpty
              ? const Center(child: Text("Aucun résultat pour cette recherche."))
              : ListView.builder(
                  itemCount: filteredEquipes.length,
                  itemBuilder: (context, index) {
                    final equipe = filteredEquipes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: _buildLeading(equipe.imageUrl),
                        title: Text(equipe.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Points : ${equipe.points ?? 0}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => showForm(equipe: equipe)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => deleteEquipe(equipe.id ?? "")),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildLeading(String? url) {
    bool isValid = url != null && url.startsWith('http');
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
      child: isValid 
        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.group)))
        : const Icon(Icons.group),
    );
  }
}