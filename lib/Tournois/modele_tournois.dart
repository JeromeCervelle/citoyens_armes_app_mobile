class Tournament {
  final String id;
  final String name;
  final String game;
  final String status;
  final int numberOfTeams;

  Tournament({
    required this.id,
    required this.name,
    required this.game,
    required this.status,
    required this.numberOfTeams,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'] as String,
      name: json['name'] as String,
      game: json['game'] as String,
      status: json['status'] as String,
      numberOfTeams: json['numberOfTeams'] is int 
          ? json['numberOfTeams'] as int 
          : int.tryParse(json['numberOfTeams']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'game': game,
      'status': status,
      'numberOfTeams': numberOfTeams,
    };
  }
}
