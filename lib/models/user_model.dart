enum UserRole { admin, driver }

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.role,
    this.isOnline = true,
  });

  final String id;
  final String name;
  final UserRole role;
  final bool isOnline;

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "role": role.name,
    "isOnline": isOnline,
  };

  UserModel copyWith({
    String? id,
    String? name,
    UserRole? role,
    bool? isOnline,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["id"].toString(),
      name: json["name"].toString(),
      role: (json["role"]?.toString() == UserRole.admin.name)
          ? UserRole.admin
          : UserRole.driver,
      isOnline: json["isOnline"] as bool? ?? true,
    );
  }
}
