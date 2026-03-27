// models/parent.dart — Parent data model
class Parent {
  final String id;
  final String name;
  final String phone;
  final String pinHash;
  final String pinSalt;
  final DateTime createdAt;

  Parent({
    required this.id,
    required this.name,
    required this.phone,
    required this.pinHash,
    required this.pinSalt,
    required this.createdAt,
  });

  factory Parent.fromMap(Map<String, dynamic> map) {
    return Parent(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      pinHash: map['pin_hash'] as String,
      pinSalt: map['pin_salt'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'pin_hash': pinHash,
    'pin_salt': pinSalt,
    'created_at': createdAt.toIso8601String(),
  };
}
