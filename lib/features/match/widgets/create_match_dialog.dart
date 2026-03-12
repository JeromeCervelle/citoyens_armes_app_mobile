// Fichier : lib/features/match/widgets/create_match_dialog.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateMatchDialog extends StatefulWidget {
  final String tournamentId;
  final String roundId;
  final List<dynamic> teams; // Les vraies équipes de la BDD
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
      // 1. Créer le match dans le vrai round [cite: 18-19]
      final createResponse = await http.post(
        Uri.parse('http://localhost:9090/api/tournaments/${widget.tournamentId}/rounds/${widget.roundId}/matches'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer ${widget.token}"},
      );

      if (createResponse.statusCode == 200 || createResponse.statusCode == 201) {
        final createdMatch = jsonDecode(createResponse.body);
        final matchId = createdMatch['id'].toString();

        // 2. Inscrire les vraies équipes [cite: 63-64]
        final registerResponse = await http.post(
          Uri.parse('http://localhost:9090/api/tournaments/${widget.tournamentId}/matches/$matchId/teams'),
          headers: {"Content-Type": "application/json", "Authorization": "Bearer ${widget.token}"},
          body: jsonEncode({"team1Id": _selectedTeam1Id, "team2Id": _selectedTeam2Id}),
        );

        if (registerResponse.statusCode == 200) {
          Navigator.pop(context, true);
          return;
        }
      }
      throw Exception("Code erreur: ${createResponse.statusCode}");
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
                  value: t['id'].toString(),
                  child: Text(t['name'] ?? 'Équipe sans nom', style: const TextStyle(color: Colors.white))
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
                  value: t['id'].toString(),
                  child: Text(t['name'] ?? 'Équipe sans nom', style: const TextStyle(color: Colors.white))
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