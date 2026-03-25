/// Modèle de données représentant une manche (round) d'un tournoi
class Round {
  final String id;
  final String name;
  final List<String> matchIds;
  final int format;

  const Round({
    required this.id,
    required this.name,
    required this.matchIds,
    this.format = 1,
  });

  /// Crée un [Round] à partir d'un objet JSON reçu de l'API
  factory Round.fromJson(Map<String, dynamic> json) {
    return Round(
      id: json['id'] as String,
      name: json['name'] as String,
      matchIds: List<String>.from(json['matchIds'] ?? []),
      format: json['format'] as int? ?? 1,
    );
  }

  /// Convertit ce [Round] en objet JSON pour l'envoyer à l'API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'matchIds': matchIds,
      'format': format,
    };
  }

  @override
  String toString() => 'Round(id: $id, name: $name, matchIds: $matchIds)';
}
