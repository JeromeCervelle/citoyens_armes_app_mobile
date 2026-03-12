import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'modele_tournois.dart';
import 'repository_tournois.dart';

class TournamentFormScreen extends StatefulWidget {
  final Tournament? tournament;

  const TournamentFormScreen({super.key, this.tournament});

  @override
  State<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends State<TournamentFormScreen> {
  final String _authToken = dotenv.get('AUTH_TOKEN');
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

  Future<void> _saveTournament() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    print('Form saved. _numberOfTeams: $_numberOfTeams');

    setState(() {
      _isLoading = true;
    });

    try {
      final service = context.read<TournamentApiService>();
      if (widget.tournament == null) {
        final createdTournament = await service.createTournament(_name, _game, _numberOfTeams, _authToken);
        
        await service.generateRoundsAutomatically(
          createdTournament.id, 
          _numberOfTeams, 
          _authToken
        );   
      } else {
        await service.updateTournament(
          widget.tournament!.id,
          _name,
          _game,
          _numberOfTeams,
          _authToken,
        );
      }
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
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
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier Tournoi' : 'Nouveau Tournoi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Nom du tournoi'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  return null;
                },
                onSaved: (value) {
                  _name = value!;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _game,
                decoration: const InputDecoration(
                  labelText: 'Nom du jeu',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom du jeu';
                  }
                  return null;
                },
                onSaved: (value) {
                  _game = value!;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _numberOfTeams.toString(),
                decoration: const InputDecoration(labelText: 'Nombre d\'équipes'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nombre';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Veuillez entrer un nombre valide';
                  }
                  return null;
                },
                onSaved: (value) {
                  _numberOfTeams = int.parse(value!);
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveTournament,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
