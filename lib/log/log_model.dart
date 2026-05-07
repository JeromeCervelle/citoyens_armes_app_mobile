class ConnectionLog {
  final String id;
  final String userId;
  final DateTime connectionDateTime;
  final String? ipAddress;

  ConnectionLog({
    required this.id,
    required this.userId,
    required this.connectionDateTime,
    this.ipAddress,
  });

  factory ConnectionLog.fromJson(Map<String, dynamic> json) {
    return ConnectionLog(
      id: json['id'] as String,
      userId: json['userId'] as String,
      connectionDateTime: DateTime.parse(json['connectionDateTime'] as String),
      ipAddress: json['ipAddress'] as String?,
    );
  }
}
