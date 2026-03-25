// Fichier : lib/features/match/widgets/create_match_dialog.dart
import 'package:flutter/material.dart';
import '../services/match_api_service.dart';
import '../../equipes/model_equipe.dart';

class CreateMatchDialog extends StatefulWidget {
  final String tournamentId;
  final String roundId;
  final List<Equipe> teams; // Les vraies équipes de la BDD
  final String token;

  const CreateMatchDialog({
    super.key,
    required this.tournamentId,
    required this.roundId,
    required this.teams,
    required this.token
  });

  @override
  State<CreateMatchDialog> createState() => _CreateMatchDialogState();
}

class _CreateMatchDialogState extends State<CreateMatchDialog> {
  String? _selectedTeam1Id;
  String? _selectedTeam2Id;
  bool _isSubmitting = false;

  Future<void> _submitToApi() async {
    if (_selectedTeam1Id == null || _selectedTeam2Id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sélectionnez deux équipes.")));
      return;
    }
    if (_selectedTeam1Id == _selectedTeam2Id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Une équipe ne peut pas s'affronter elle-même !")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Créer le match dans le vrai round
      final MatchApiService _matchApiService = MatchApiService();
      final createdMatch = await _matchApiService.createMatch(widget.tournamentId, widget.roundId, widget.token);
      final matchId = createdMatch['id'].toString();

      // 2. Inscrire les vraies équipes
      await _matchApiService.registerTeamsToMatch(
        widget.tournamentId,
        matchId,
        _selectedTeam1Id!,
        _selectedTeam2Id!,
        widget.token,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Erreur: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de la création.")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B2A3B),
      title: const Text('Créer un match', style: TextStyle(color: Colors.white)),
      content: _isSubmitting
          ? const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()))
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            dropdownColor: const Color(0xFF0D1B2A),
            decoration: const InputDecoration(labelText: 'Équipe 1', labelStyle: TextStyle(color: Colors.blue)),
            value: _selectedTeam1Id,
            items: widget.teams.map((t) {
              return DropdownMenuItem<String>(
                  value: t.id,
                  child: Text(t.name, style: const TextStyle(color: Colors.white))
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedTeam1Id = val),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            dropdownColor: const Color(0xFF0D1B2A),
            decoration: const InputDecoration(labelText: 'Équipe 2', labelStyle: TextStyle(color: Colors.red)),
            value: _selectedTeam2Id,
            items: widget.teams.map((t) {
              return DropdownMenuItem<String>(
                  value: t.id,
                  child: Text(t.name, style: const TextStyle(color: Colors.white))
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedTeam2Id = val),
          ),
        ],
      ),
      actions: [
        if (!_isSubmitting)
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
        if (!_isSubmitting)
          ElevatedButton(onPressed: _submitToApi, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Créer le match')),
      ],
    );
  }
}