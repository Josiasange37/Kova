// Dart data model for Parent
class Parent {
  final String id;
  final String name;
  final String phone;
  final DateTime createdAt;

  Parent({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
  });

  factory Parent.fromJson(Map<String, dynamic> json) {
    return Parent(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'createdAt': createdAt.toIso8601String(),
  };
}
