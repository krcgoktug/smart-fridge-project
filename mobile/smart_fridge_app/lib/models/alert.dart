/// A notification stored under `/devices/<id>/alerts`.
class Alert {
  Alert({
    required this.id,
    required this.message,
    required this.severity,
    this.productId,
    required this.createdAt,
  });

  final String id;
  final String message;
  final String severity; // info | warning | danger
  final String? productId;
  final num createdAt; // seconds

  factory Alert.fromMap(String id, Map<dynamic, dynamic> map) {
    num n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    return Alert(
      id: id,
      message: (map['message'] ?? '').toString(),
      severity: (map['severity'] ?? 'info').toString(),
      productId: map['productId']?.toString(),
      createdAt: n(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'message': message,
        'severity': severity,
        'productId': productId,
        'createdAt': createdAt,
      };

  DateTime get createdDateTime =>
      DateTime.fromMillisecondsSinceEpoch(createdAt.toInt() * 1000);
}
