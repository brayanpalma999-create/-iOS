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
  String get languageCode => _user?.languageCode ?? "es";

  void login({required String name, required UserRole role, String? password}) {
    final trimmed = name.trim();
    final slug = trimmed.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "");
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final shortId = now.substring(now.length - 6);
    _user = UserModel(
      id: now,
      name: trimmed,
      role: role,
      legalName: trimmed,
      email: "${slug.isEmpty ? role.name : slug}@atob.app",
      phoneNumber: "+1 804 555 ${shortId.substring(2)}",
      address: role == UserRole.admin
          ? "Virginia dispatch lane"
          : "Virginia driver zone",
      governmentId: "${role == UserRole.admin ? 'ADM' : 'DRV'}-$shortId",
      languageCode: "es",
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
    _user = _user!.copyWith(name: name, legalName: name);
    notifyListeners();
  }

  void updateProfile({
    String? displayName,
    String? legalName,
    String? email,
    String? phoneNumber,
    String? address,
    String? governmentId,
  }) {
    if (_user == null) return;
    _user = _user!.copyWith(
      name: (displayName ?? "").trim().isEmpty ? null : displayName!.trim(),
      legalName: (legalName ?? "").trim().isEmpty ? null : legalName!.trim(),
      email: (email ?? "").trim().isEmpty ? null : email!.trim(),
      phoneNumber: (phoneNumber ?? "").trim().isEmpty
          ? null
          : phoneNumber!.trim(),
      address: (address ?? "").trim().isEmpty ? null : address!.trim(),
      governmentId: (governmentId ?? "").trim().isEmpty
          ? null
          : governmentId!.trim(),
    );
    notifyListeners();
  }

  void updateAvatarPath(String? avatarPath) {
    if (_user == null) return;
    _user = _user!.copyWith(
      avatarPath: (avatarPath ?? "").trim().isEmpty ? "" : avatarPath!.trim(),
    );
    notifyListeners();
  }

  void setLanguageCode(String code) {
    if (_user == null) return;
    _user = _user!.copyWith(languageCode: code);
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

  String? changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    final currentNormalized = currentPassword.trim();
    final nextNormalized = newPassword.trim();
    if (_password.isNotEmpty && currentNormalized != _password) {
      return "current_password_mismatch";
    }
    if (nextNormalized.length < 6) {
      return "password_too_short";
    }
    _password = nextNormalized;
    _passwordUpdatedAt = DateTime.now();
    notifyListeners();
    return null;
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}
