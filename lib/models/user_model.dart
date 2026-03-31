enum UserRole { admin, driver }

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.legalName,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.governmentId,
    this.languageCode = "es",
    this.isOnline = true,
    this.avatarPath,
  });

  final String id;
  final String name;
  final UserRole role;
  final String legalName;
  final String email;
  final String phoneNumber;
  final String address;
  final String governmentId;
  final String languageCode;
  final bool isOnline;
  final String? avatarPath;

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "role": role.name,
    "legalName": legalName,
    "email": email,
    "phoneNumber": phoneNumber,
    "address": address,
    "governmentId": governmentId,
    "languageCode": languageCode,
    "isOnline": isOnline,
    "avatarPath": avatarPath,
  };

  UserModel copyWith({
    String? id,
    String? name,
    UserRole? role,
    String? legalName,
    String? email,
    String? phoneNumber,
    String? address,
    String? governmentId,
    String? languageCode,
    bool? isOnline,
    String? avatarPath,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      legalName: legalName ?? this.legalName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      governmentId: governmentId ?? this.governmentId,
      languageCode: languageCode ?? this.languageCode,
      isOnline: isOnline ?? this.isOnline,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["id"].toString(),
      name: json["name"].toString(),
      role: (json["role"]?.toString() == UserRole.admin.name)
          ? UserRole.admin
          : UserRole.driver,
      legalName:
          json["legalName"]?.toString() ?? json["name"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
      phoneNumber: json["phoneNumber"]?.toString() ?? "",
      address: json["address"]?.toString() ?? "",
      governmentId: json["governmentId"]?.toString() ?? "",
      languageCode: json["languageCode"]?.toString() ?? "es",
      isOnline: json["isOnline"] as bool? ?? true,
      avatarPath: json["avatarPath"]?.toString(),
    );
  }
}
