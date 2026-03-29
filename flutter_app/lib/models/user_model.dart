class UserModel {
  final String id;
  final String name;
  final String role; // "Chef" or "Cook"

  UserModel({required this.id, required this.name, required this.role});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};
}