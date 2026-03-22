class Equipe {
  final String? id;
  final String name;
  final int? points;
  final String? imageUrl;

  //constructeur
  Equipe({
    this.id,
    required this.name,
    this.points,
    this.imageUrl,
  });

  factory Equipe.fromJson(Map<String, dynamic> json) {
    return Equipe(
      id: json['id'],
      name: json['name'],
      points: json['points'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "imageUrl": imageUrl,
    };
  }
}