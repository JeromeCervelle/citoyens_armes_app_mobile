// Fichier : lib/features/match/widgets/match_card.dart

import 'package:flutter/material.dart';
import '../models/match_dto.dart';


class MatchCard extends StatelessWidget {
  final MatchDTO match;

  const MatchCard({Key? key, required this.match}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Match",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Équipe 1
                Column(
                  children: [
                    Text("Équipe ${match.team1Id.substring(0, 4)}..."), // On raccourcit l'ID pour l'affichage
                    const SizedBox(height: 8),
                    Text(
                      "${match.team1Point}",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
                
                const Text("VS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),

                // Équipe 2
                Column(
                  children: [
                    Text("Équipe ${match.team2Id.substring(0, 4)}..."),
                    const SizedBox(height: 8),
                    Text(
                      "${match.team2Point}",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}