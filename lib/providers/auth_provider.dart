import "package:flutter/material.dart";

import "../models/user_model.dart";

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String _password = "";
  DateTime? _passwordUpdatedAt;

  UserModel? get user => _user;
  bool get isAdmin => _user?.role == UserRole.admin;
  bool get isDriver => _user?.role == UserRole.driver;
  bool get hasPassword => _password.isNotEmpty;
  DateTime? get passwordUpdatedAt => _passwordUpdatedAt;

  void login({required String name, required UserRole role, String? password}) {
    _user = UserModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      role: role,
      isOnline: true,
    );
    if ((password ?? "").trim().isNotEmpty) {
      _password = password!.trim();
      _passwordUpdatedAt = DateTime.now();
    }
    notifyListeners();
  }

  void updateName(String name) {
    if (_user == null) return;
    _user = _user!.copyWith(name: name);
    notifyListeners();
  }

  bool updatePassword(String password) {
    final normalized = password.trim();
    if (normalized.length < 6) {
      return false;
    }
    _password = normalized;
    _passwordUpdatedAt = DateTime.now();
    notifyListeners();
    return true;
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}
