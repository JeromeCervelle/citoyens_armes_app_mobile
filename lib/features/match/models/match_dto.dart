// Fichier : lib/features/match/models/match_dto.dart

class MatchDTO {
  final String id;
  final String team1Id;
  final String team2Id;
  final int team1Point;
  final int team2Point;

  MatchDTO({
    required this.id,
    required this.team1Id,
    required this.team2Id,
    required this.team1Point,
    required this.team2Point,
  });

  // Fonction pour convertir le JSON de l'API en objet Dart
  factory MatchDTO.fromJson(Map<String, dynamic> json) {
    return MatchDTO(
      id: json['id'] ?? '',
      team1Id: json['team1Id'] ?? '',
      team2Id: json['team2Id'] ?? '',
      team1Point: json['team1Point'] ?? 0,
      team2Point: json['team2Point'] ?? 0,
    );
  }

  // Fonction pour convertir l'objet Dart en JSON (utile si besoin d'envoyer l'objet entier)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team1Id': team1Id,
      'team2Id': team2Id,
      'team1Point': team1Point,
      'team2Point': team2Point,
    };
  }
}