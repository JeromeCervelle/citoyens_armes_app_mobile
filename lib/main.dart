// Fichier : lib/main.dart
import 'package:flutter/material.dart';
import 'features/match/screens/match_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aux Claviers Citoyens',
      theme: ThemeData.dark(),
      home: const MatchListScreen(
        token: "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbiIsImlhdCI6MTc3MzMzMDA1NSwiZXhwIjoxNzczNDE2NDU1fQ.LyjzPzFuPyLwMVGEMscvob3gx-xoaxC5AGRRHMfBVTPli4LUd8w71g7dqgdD1eF3KDOur2gVwq6cUPVAHRJcJg",
      ),
    );
  }
}