class User {
  final String id;
  final String email;
  final String name;
  final String? role;
  final String? createdAt;
  final String? updatedAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  bool get isSuperAdmin => role == 'SUPERADMIN';
  bool get isAdmin => role == 'ADMIN';

  String get roleLabel {
    switch (role) {
      case 'SUPERADMIN': return 'Super Admin';
      case 'ADMIN': return 'Admin';
      default: return role ?? '—';
    }
  }
}