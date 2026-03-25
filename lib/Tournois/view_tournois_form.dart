import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'modele_tournois.dart';
import 'repository_tournois.dart';
import '../user/auth_service.dart';
import '../features_vue/theme/neon_components.dart';
import '../features_vue/tournois/tournois_detail_view.dart';

class TournamentFormScreen extends StatefulWidget {
  final Tournament? tournament;

  const TournamentFormScreen({super.key, this.tournament});

  @override
  State<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends State<TournamentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _game;
  late int _numberOfTeams;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _name = widget.tournament?.name ?? '';
    _game = widget.tournament?.game ?? '';
    _numberOfTeams = widget.tournament?.numberOfTeams ?? 0;
  }

  /// Enregistre le tournoi via l'API (Création ou Mise à jour).
  Future<void> _saveTournament() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      final service = context.read<TournamentApiService>();
      final String token = await AuthService().getToken() ?? '';
      
      if (widget.tournament == null) {
        final newTournament = await service.createTournament(_name, _game, _numberOfTeams, token);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TournoisDetailView(tournament: newTournament)),
          );
        }
      } else {
        await service.updateTournament(
          widget.tournament!.id,
          _name,
          _game,
          _numberOfTeams,
          token,
        );
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tournament != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const NeonBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                (isEditing ? 'Modifier Tournoi' : 'Nouveau Tournoi').toUpperCase(),
                style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 18),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildNeonFormField(
                      initialValue: _name,
                      label: 'NOM DU TOURNOI',
                      validator: (value) => (value == null || value.isEmpty) ? 'Veuillez entrer un nom' : null,
                      onSaved: (value) => _name = value!,
                    ),
                    const SizedBox(height: 20),
                    _buildNeonFormField(
                      initialValue: _game,
                      label: 'NOM DU JEU',
                      validator: (value) => (value == null || value.isEmpty) ? 'Veuillez entrer le nom du jeu' : null,
                      onSaved: (value) => _game = value!,
                    ),
                    const SizedBox(height: 20),
                    _buildNeonFormField(
                      initialValue: _numberOfTeams.toString(),
                      label: 'NOMBRE D\'ÉQUIPES',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Veuillez entrer un nombre';
                        if (int.tryParse(value) == null) return 'Veuillez entrer un nombre valide';
                        return null;
                      },
                      onSaved: (value) => _numberOfTeams = int.parse(value!),
                    ),
                    const SizedBox(height: 48),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeonFormField({
    required String initialValue,
    required String label,
    required FormFieldValidator<String> validator,
    required FormFieldSetter<String> onSaved,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      initialValue: initialValue,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF00FF85), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF85))),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveTournament,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF85),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Text('ENREGISTRER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
      ),
    );
  }
}
