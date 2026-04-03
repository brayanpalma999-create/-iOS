import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/user_model.dart";
import "../utils/auth_security.dart";
import "../utils/constants.dart";

class DriverAccessProfile {
  const DriverAccessProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.accessCode,
    required this.createdAt,
    this.accessCodeTail,
    this.phoneNumber,
    this.governmentId,
    this.isActive = true,
    this.isActivated = true,
    this.activationSentAt,
    this.activatedAt,
  });

  final String id;
  final String displayName;
  final String email;
  final String accessCode;
  final String? accessCodeTail;
  final String? phoneNumber;
  final String? governmentId;
  final bool isActive;
  final bool isActivated;
  final DateTime? activationSentAt;
  final DateTime? activatedAt;
  final DateTime createdAt;

  bool get activationPending => isActive && !isActivated;

  String get maskedAccessCode {
    final tail = (accessCodeTail ?? "").trim();
    if (tail.isEmpty) return "••••••";
    return "••••••$tail";
  }

  DriverAccessProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? accessCode,
    String? accessCodeTail,
    String? phoneNumber,
    String? governmentId,
    bool? isActive,
    bool? isActivated,
    DateTime? activationSentAt,
    Object? activatedAt = _driverAccessUnset,
    DateTime? createdAt,
  }) {
    return DriverAccessProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      accessCode: accessCode ?? this.accessCode,
      accessCodeTail: accessCodeTail ?? this.accessCodeTail,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      governmentId: governmentId ?? this.governmentId,
      isActive: isActive ?? this.isActive,
      isActivated: isActivated ?? this.isActivated,
      activationSentAt: activationSentAt ?? this.activationSentAt,
      activatedAt: identical(activatedAt, _driverAccessUnset)
          ? this.activatedAt
          : activatedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "displayName": displayName,
    "email": email,
    "accessCode": accessCode,
    "accessCodeTail": accessCodeTail,
    "phoneNumber": phoneNumber,
    "governmentId": governmentId,
    "isActive": isActive,
    "isActivated": isActivated,
    "activationSentAt": activationSentAt?.toIso8601String(),
    "activatedAt": activatedAt?.toIso8601String(),
    "createdAt": createdAt.toIso8601String(),
  };

  factory DriverAccessProfile.fromJson(Map<String, dynamic> json) {
    return DriverAccessProfile(
      id: json["id"]?.toString() ?? "",
      displayName: json["displayName"]?.toString() ?? "",
      email: _nullableText(json["email"]) ?? "",
      accessCode: json["accessCode"]?.toString() ?? "",
      accessCodeTail:
          _nullableText(json["accessCodeTail"]) ??
          _nullableText(json["accessCodeHint"]),
      phoneNumber: _nullableText(json["phoneNumber"]),
      governmentId: _nullableText(json["governmentId"]),
      isActive: json["isActive"] as bool? ?? true,
      isActivated: json["isActivated"] as bool? ?? true,
      activationSentAt: DateTime.tryParse(
        json["activationSentAt"]?.toString() ?? "",
      ),
      activatedAt: DateTime.tryParse(json["activatedAt"]?.toString() ?? ""),
      createdAt:
          DateTime.tryParse(json["createdAt"]?.toString() ?? "") ??
          DateTime.now(),
    );
  }

  static String normalizeLookup(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r"\s+"), " ");
  }

  static String? _nullableText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

const Object _driverAccessUnset = Object();

class DriverAccessSaveResult {
  const DriverAccessSaveResult({
    this.profile,
    this.inviteEmailSent = false,
    this.inviteQueued = false,
    this.inviteSkipped = false,
    this.activationUrl,
    this.inviteError,
  });

  final DriverAccessProfile? profile;
  final bool inviteEmailSent;
  final bool inviteQueued;
  final bool inviteSkipped;
  final String? activationUrl;
  final String? inviteError;
}

class DriverRecordData {
  const DriverRecordData({
    required this.profile,
    required this.user,
    required this.accountKey,
    required this.passwordIdentity,
    this.passwordUpdatedAt,
  });

  final DriverAccessProfile profile;
  final UserModel user;
  final String accountKey;
  final String passwordIdentity;
  final DateTime? passwordUpdatedAt;
}

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    unawaited(ensureLoaded());
  }

  static const String _authorizedDriversKey = "authorized_driver_profiles_v2";
  static const String _accountProfilesKey = "atob_account_profiles_v1";

  UserModel? _user;
  String _password = "";
  DateTime? _passwordUpdatedAt;
  final List<DriverAccessProfile> _authorizedDrivers =
      <DriverAccessProfile>[];
  final Map<String, Map<String, dynamic>> _storedAccounts =
      <String, Map<String, dynamic>>{};
  Future<void>? _loadFuture;
  bool _isReady = false;
  String? _currentAccountKey;
  String? _currentDriverAccessId;
  String? _currentPasswordIdentity;

  UserModel? get user => _user;
  bool get isAdmin => _user?.role == UserRole.admin;
  bool get isDriver => _user?.role == UserRole.driver;
  bool get hasPassword => _password.isNotEmpty;
  DateTime? get passwordUpdatedAt => _passwordUpdatedAt;
  String get languageCode => _user?.languageCode ?? "es";
  bool get isReady => _isReady;
  String? get currentAccountKey => _currentAccountKey;
  List<DriverAccessProfile> get authorizedDrivers =>
      List.unmodifiable(_authorizedDrivers);
  List<DriverRecordData> get driverRecords => _authorizedDrivers
      .map(_driverRecordFromProfile)
      .toList(growable: false);
  bool get hasAuthorizedDrivers =>
      _authorizedDrivers.any((profile) => profile.isActive);
  String get fixedAdminEmail => AuthSecurity.fixedAdminEmail;

  Future<void> refreshAdminPanelState() async {
    await ensureLoaded();
    await warmAccountProfile(
      role: UserRole.admin,
      loginIdentifier: AuthSecurity.fixedAdminEmail,
      email: AuthSecurity.fixedAdminEmail,
    );
  }

  Future<void> refreshAuthorizedDrivers() async {
    await ensureLoaded();
    await _refreshAuthorizedDriversFromServer();
  }

  Future<void> warmAuthorizedDriverRecords() async {
    await ensureLoaded();
    var changed = false;
    for (final profile in _authorizedDrivers) {
      final accountKey = _resolveAccountKey(
        role: UserRole.driver,
        loginIdentifier: profile.displayName,
        email: profile.email,
      );
      final remote = await _fetchStoredAccountFromServer(accountKey);
      if (remote == null) continue;
      _storedAccounts[accountKey] = _secureStoredAccountRecord(accountKey, remote);
      changed = true;
    }
    if (changed) {
      await _persistStoredAccounts();
      notifyListeners();
    }
  }

  Future<void> ensureLoaded() async {
    await (_loadFuture ??= _hydrateLocalState());
    await _refreshAuthorizedDriversFromServer();
  }

  Future<void> warmAccountProfile({
    required UserRole role,
    required String loginIdentifier,
    String? email,
  }) async {
    await ensureLoaded();
    final accountKey = _resolveAccountKey(
      role: role,
      loginIdentifier: loginIdentifier,
      email: email,
    );
    final remote = await _fetchStoredAccountFromServer(accountKey);
    if (remote == null) return;
    _storedAccounts[accountKey] = _secureStoredAccountRecord(accountKey, remote);
    await _persistStoredAccounts();
    notifyListeners();
  }

  bool authorizeAdminLogin({
    required String email,
    required String password,
  }) {
    final resolvedEmail = email.trim().isEmpty
        ? AuthSecurity.fixedAdminEmail
        : email;
    return AuthSecurity.matchesFixedAdmin(
      email: resolvedEmail,
      password: password,
    );
  }

  void login({
    required String name,
    required UserRole role,
    String? password,
    DriverAccessProfile? driverAccess,
    String? loginIdentifier,
  }) {
    final trimmedName = name.trim();
    final normalizedPassword = (password ?? "").trim();
    final accountKey = _resolveAccountKey(
      role: role,
      loginIdentifier: loginIdentifier ?? trimmedName,
      email: driverAccess?.email,
    );
    final stored = _secureStoredAccountRecord(
      accountKey,
      _storedAccounts[accountKey],
    );
    final storedUser = _userFromStoredAccount(stored);
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final shortId = now.substring(now.length - 6);
    final resolvedName =
        _nonEmpty(driverAccess?.displayName) ??
        _nonEmpty(storedUser?.name) ??
        trimmedName;
    final resolvedEmail =
        _nonEmpty(driverAccess?.email) ??
        _nonEmpty(storedUser?.email) ??
        _fallbackEmail(role, loginIdentifier ?? trimmedName, shortId);
    final resolvedPhone =
        _nonEmpty(driverAccess?.phoneNumber) ??
        _nonEmpty(storedUser?.phoneNumber) ??
        "+1 804 555 ${shortId.substring(2)}";
    final resolvedGovernmentId =
        _nonEmpty(driverAccess?.governmentId) ??
        _nonEmpty(storedUser?.governmentId) ??
        "${role == UserRole.admin ? "ADM" : "DRV"}-$shortId";
    final resolvedId =
        _nonEmpty(storedUser?.id) ??
        _nonEmpty(driverAccess?.id) ??
        _stableAccountId(
          role: role,
          loginIdentifier: loginIdentifier ?? trimmedName,
          email: resolvedEmail,
        );

    _currentAccountKey = accountKey;
    _currentDriverAccessId = driverAccess?.id;
    _currentPasswordIdentity = _resolvePasswordIdentity(
      role: role,
      accountKey: accountKey,
      driverAccessId: driverAccess?.id,
      storedUser: storedUser,
    );
    _user = UserModel(
      id: resolvedId,
      name: resolvedName,
      role: role,
      legalName: _nonEmpty(storedUser?.legalName) ?? resolvedName,
      email: resolvedEmail,
      phoneNumber: resolvedPhone,
      address:
          _nonEmpty(storedUser?.address) ??
          (role == UserRole.admin
              ? "Virginia dispatch lane"
              : "Virginia driver zone"),
      governmentId: resolvedGovernmentId,
      languageCode: _nonEmpty(storedUser?.languageCode) ?? "es",
      mapThemeMode: _nonEmpty(storedUser?.mapThemeMode) ?? "flow",
      avatarPath: _nonEmpty(storedUser?.avatarPath),
      vehicleMake: _nonEmpty(storedUser?.vehicleMake),
      vehicleModel: _nonEmpty(storedUser?.vehicleModel),
      vehicleColor: _nonEmpty(storedUser?.vehicleColor),
      vehiclePlate: _nonEmpty(storedUser?.vehiclePlate),
      vehicleYear: _nonEmpty(storedUser?.vehicleYear),
      isOnline: true,
    );
    _password = normalizedPassword.isNotEmpty
        ? _hashAccountPassword(
            identity: _currentPasswordIdentity!,
            password: normalizedPassword,
          )
        : _passwordFromStoredAccount(stored);
    _passwordUpdatedAt =
        _passwordUpdatedAtFromStoredAccount(stored) ?? DateTime.now();
    unawaited(_persistCurrentAccount());
    notifyListeners();
  }

  Future<DriverAccessProfile?> authorizeDriverLogin({
    required String email,
    required String password,
  }) async {
    await ensureLoaded();
    final normalizedEmail = DriverAccessProfile.normalizeLookup(email);
    final normalizedPassword = password.trim();
    if (normalizedEmail.isEmpty || normalizedPassword.isEmpty) {
      return null;
    }
    final localCandidate = _findAuthorizedDriverByEmail(normalizedEmail);
    final remote = localCandidate == null
        ? null
        : await _authorizeDriverLoginFromServer(
            email: email,
            passwordHash: _hashDriverAccessPassword(
              driverAccessId: localCandidate.id,
              password: normalizedPassword,
            ),
          );
    if (remote != null) {
      _upsertAuthorizedDriver(_secureDriverAccessProfile(remote));
      await _persistAuthorizedDrivers();
      notifyListeners();
      return _secureDriverAccessProfile(remote);
    }
    if (localCandidate == null) {
      return null;
    }
    final secureCandidate = _secureDriverAccessProfile(localCandidate);
    if (!secureCandidate.isActive || !secureCandidate.isActivated) {
      return null;
    }
    final matches = AuthSecurity.matchesSecret(
      scope: "driver-access",
      identity: secureCandidate.id,
      candidate: normalizedPassword,
      storedHash: secureCandidate.accessCode,
    );
    return matches ? secureCandidate : null;
  }

  Future<DriverAccessSaveResult> saveAuthorizedDriver({
    String? id,
    required String displayName,
    required String email,
    required String accessCode,
    String? phoneNumber,
    String? governmentId,
  }) async {
    await ensureLoaded();
    final normalizedEmail = DriverAccessProfile.normalizeLookup(email);
    final normalizedName = DriverAccessProfile.normalizeLookup(displayName);
    if (normalizedEmail.isEmpty ||
        normalizedName.isEmpty ||
        (accessCode.trim().isEmpty && id == null)) {
      return const DriverAccessSaveResult();
    }

    final cleanPhone = _nullableTrim(phoneNumber);
    final cleanGovernmentId = _nullableTrim(governmentId);
    final existing = _findAuthorizedDriverForEdit(
      id: id,
      normalizedEmail: normalizedEmail,
    );
    final resolvedId =
        _nonEmpty(id) ??
        existing?.id ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final normalizedAccessCode = accessCode.trim();
    final secureAccessCode = normalizedAccessCode.isEmpty
        ? (existing?.accessCode ?? "")
        : _hashDriverAccessPassword(
            driverAccessId: resolvedId,
            password: normalizedAccessCode,
          );
    final accessCodeTail = normalizedAccessCode.isEmpty
        ? (existing?.accessCodeTail ?? "")
        : AuthSecurity.secretTail(normalizedAccessCode);
    if (secureAccessCode.isEmpty) {
      return const DriverAccessSaveResult();
    }

    final remote = await _saveAuthorizedDriverToServer(
      id: resolvedId,
      displayName: displayName.trim(),
      email: email.trim(),
      accessCode: secureAccessCode,
      accessCodeTail: accessCodeTail,
      phoneNumber: cleanPhone,
      governmentId: cleanGovernmentId,
    );
    if (remote.profile != null) {
      _upsertAuthorizedDriver(_secureDriverAccessProfile(remote.profile!));
      await _persistAuthorizedDrivers();
      notifyListeners();
      return remote;
    }
    final index = _authorizedDrivers.indexWhere((profile) => profile.id == resolvedId);

    if (index >= 0) {
      final current = _authorizedDrivers[index];
      _authorizedDrivers[index] = current.copyWith(
        displayName: displayName.trim(),
        email: email.trim(),
        accessCode: secureAccessCode,
        accessCodeTail: accessCodeTail,
        phoneNumber: cleanPhone,
        governmentId: cleanGovernmentId,
      );
    } else {
      _authorizedDrivers.insert(
        0,
        DriverAccessProfile(
          id: resolvedId,
          displayName: displayName.trim(),
          email: email.trim(),
          accessCode: secureAccessCode,
          accessCodeTail: accessCodeTail,
          phoneNumber: cleanPhone,
          governmentId: cleanGovernmentId,
          createdAt: DateTime.now(),
        ),
      );
    }

    await _persistAuthorizedDrivers();
    notifyListeners();
    return DriverAccessSaveResult(
      profile: _authorizedDrivers.firstWhere(
        (profile) => profile.id == resolvedId,
        orElse: () => DriverAccessProfile(
          id: resolvedId,
          displayName: displayName.trim(),
          email: email.trim(),
          accessCode: secureAccessCode,
          accessCodeTail: accessCodeTail,
          phoneNumber: cleanPhone,
          governmentId: cleanGovernmentId,
          createdAt: DateTime.now(),
        ),
      ),
      inviteSkipped: existing != null,
    );
  }

  Future<void> setAuthorizedDriverActive(String id, bool isActive) async {
    await ensureLoaded();
    final remote = await _toggleAuthorizedDriverOnServer(id, isActive);
    if (remote != null) {
      _upsertAuthorizedDriver(remote);
      await _persistAuthorizedDrivers();
      notifyListeners();
      return;
    }
    final index = _authorizedDrivers.indexWhere((profile) => profile.id == id);
    if (index < 0) return;
    _authorizedDrivers[index] = _authorizedDrivers[index].copyWith(
      isActive: isActive,
    );
    await _persistAuthorizedDrivers();
    notifyListeners();
  }

  Future<void> removeAuthorizedDriver(String id) async {
    await ensureLoaded();
    final removedOnServer = await _removeAuthorizedDriverFromServer(id);
    if (removedOnServer) {
      _authorizedDrivers.removeWhere((profile) => profile.id == id);
      await _persistAuthorizedDrivers();
      notifyListeners();
      return;
    }
    _authorizedDrivers.removeWhere((profile) => profile.id == id);
    await _persistAuthorizedDrivers();
    notifyListeners();
  }

  Future<bool> updateAuthorizedDriverRecord({
    required String id,
    required String displayName,
    required String legalName,
    required String email,
    String? phoneNumber,
    String? governmentId,
    String? address,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColor,
    String? vehiclePlate,
    String? vehicleYear,
    String? newPassword,
  }) async {
    await ensureLoaded();
    final currentProfile = _authorizedDrivers
        .where((profile) => profile.id == id)
        .cast<DriverAccessProfile?>()
        .firstWhere((profile) => profile != null, orElse: () => null);
    if (currentProfile == null) return false;

    final currentRecord = _driverRecordFromProfile(currentProfile);
    final normalizedEmail = email.trim();
    if (displayName.trim().isEmpty ||
        legalName.trim().isEmpty ||
        normalizedEmail.isEmpty) {
      return false;
    }

    final passwordText = (newPassword ?? "").trim();
    final result = await saveAuthorizedDriver(
      id: id,
      displayName: legalName.trim(),
      email: normalizedEmail,
      phoneNumber: phoneNumber,
      governmentId: governmentId,
      accessCode: passwordText,
    );
    final nextProfile =
        result.profile ??
        _authorizedDrivers.firstWhere(
          (profile) => profile.id == id,
          orElse: () => currentProfile,
        );
    final nextAccountKey = _resolveAccountKey(
      role: UserRole.driver,
      loginIdentifier: legalName.trim(),
      email: normalizedEmail,
    );
    final previousAccountKey = currentRecord.accountKey;
    final nextPasswordIdentity = _resolvePasswordIdentity(
      role: UserRole.driver,
      accountKey: nextAccountKey,
      driverAccessId: nextProfile.id,
      storedUser: currentRecord.user,
    );
    final resolvedPassword = passwordText.isNotEmpty
        ? _hashAccountPassword(
            identity: nextPasswordIdentity,
            password: passwordText,
          )
        : (_nonEmpty(_storedAccounts[previousAccountKey]?["password"]?.toString()) ??
            _nonEmpty(_storedAccounts[nextAccountKey]?["password"]?.toString()) ??
            nextProfile.accessCode);
    final resolvedPasswordUpdatedAt = passwordText.isNotEmpty
        ? DateTime.now()
        : (_passwordUpdatedAtFromStoredAccount(_storedAccounts[previousAccountKey]) ??
            _passwordUpdatedAtFromStoredAccount(_storedAccounts[nextAccountKey]) ??
            currentRecord.passwordUpdatedAt ??
            DateTime.now());

    final nextUser = currentRecord.user.copyWith(
      id: currentRecord.user.id.isEmpty ? nextProfile.id : currentRecord.user.id,
      name: displayName.trim(),
      legalName: legalName.trim(),
      email: normalizedEmail,
      phoneNumber: (phoneNumber ?? "").trim().isEmpty ? "" : phoneNumber!.trim(),
      governmentId:
          (governmentId ?? "").trim().isEmpty ? "" : governmentId!.trim(),
      address: (address ?? "").trim().isEmpty ? "" : address!.trim(),
      vehicleMake: (vehicleMake ?? "").trim().isEmpty ? "" : vehicleMake!.trim(),
      vehicleModel:
          (vehicleModel ?? "").trim().isEmpty ? "" : vehicleModel!.trim(),
      vehicleColor:
          (vehicleColor ?? "").trim().isEmpty ? "" : vehicleColor!.trim(),
      vehiclePlate:
          (vehiclePlate ?? "").trim().isEmpty ? "" : vehiclePlate!.trim(),
      vehicleYear: (vehicleYear ?? "").trim().isEmpty ? "" : vehicleYear!.trim(),
      role: UserRole.driver,
      isOnline: currentRecord.user.isOnline,
    );

    if (previousAccountKey != nextAccountKey) {
      _storedAccounts.remove(previousAccountKey);
    }
    _storedAccounts[nextAccountKey] = _secureStoredAccountRecord(
      nextAccountKey,
      {
        "user": nextUser.toJson(),
        "password": resolvedPassword,
        "passwordIdentity": nextPasswordIdentity,
        "passwordUpdatedAt": resolvedPasswordUpdatedAt.toIso8601String(),
        "savedAt": DateTime.now().toIso8601String(),
      },
    );
    await _persistStoredAccounts();
    await _saveStoredAccountRecordToServer(
      accountKey: nextAccountKey,
      user: nextUser,
      passwordHash: resolvedPassword,
      passwordIdentity: nextPasswordIdentity,
      passwordUpdatedAt: resolvedPasswordUpdatedAt,
    );
    notifyListeners();
    return true;
  }

  void updateName(String name) {
    final normalized = name.trim();
    if (_user == null || normalized.isEmpty) return;
    final nextUser = _user!.copyWith(name: normalized, legalName: normalized);
    _user = nextUser;
    _remapCurrentAccountKeyIfNeeded(nextUser);
    _syncCurrentDriverAccessFromUser(nextUser);
    unawaited(_persistCurrentAccount());
    notifyListeners();
  }

  void updateProfile({
    String? displayName,
    String? legalName,
    String? email,
    String? phoneNumber,
    String? address,
    String? governmentId,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColor,
    String? vehiclePlate,
    String? vehicleYear,
  }) {
    if (_user == null) return;
    final nextUser = _user!.copyWith(
      name: (displayName ?? "").trim().isEmpty ? null : displayName!.trim(),
      legalName: (legalName ?? "").trim().isEmpty ? null : legalName!.trim(),
      email: _user!.role == UserRole.admin
          ? AuthSecurity.fixedAdminEmail
          : (email ?? "").trim().isEmpty
          ? null
          : email!.trim(),
      phoneNumber: (phoneNumber ?? "").trim().isEmpty
          ? null
          : phoneNumber!.trim(),
      address: (address ?? "").trim().isEmpty ? null : address!.trim(),
      governmentId: (governmentId ?? "").trim().isEmpty
          ? null
          : governmentId!.trim(),
      vehicleMake: (vehicleMake ?? "").trim().isEmpty ? null : vehicleMake!.trim(),
      vehicleModel: (vehicleModel ?? "").trim().isEmpty
          ? null
          : vehicleModel!.trim(),
      vehicleColor: (vehicleColor ?? "").trim().isEmpty
          ? null
          : vehicleColor!.trim(),
      vehiclePlate: (vehiclePlate ?? "").trim().isEmpty
          ? null
          : vehiclePlate!.trim(),
      vehicleYear: (vehicleYear ?? "").trim().isEmpty ? null : vehicleYear!.trim(),
    );
    _user = nextUser;
    _remapCurrentAccountKeyIfNeeded(nextUser);
    _syncCurrentDriverAccessFromUser(nextUser);
    unawaited(_persistCurrentAccount());
    notifyListeners();
  }

  void updateAvatarPath(String? avatarPath) {
    if (_user == null) return;
    _user = _user!.copyWith(
      avatarPath: (avatarPath ?? "").trim().isEmpty ? "" : avatarPath!.trim(),
    );
    unawaited(_persistCurrentAccount());
    notifyListeners();
  }

  void setLanguageCode(String code) {
    if (_user == null) return;
    _user = _user!.copyWith(languageCode: code);
    unawaited(_persistCurrentAccount());
    notifyListeners();
  }

  void setMapThemeMode(String mode) {
    if (_user == null) return;
    _user = _user!.copyWith(mapThemeMode: mode);
    unawaited(_persistCurrentAccount());
    notifyListeners();
  }

  bool updatePassword(String password) {
    if (_user?.role == UserRole.admin) {
      return false;
    }
    final normalized = password.trim();
    if (normalized.length < 6) {
      return false;
    }
    final identity = _currentPasswordIdentity;
    if (identity == null || identity.trim().isEmpty) return false;
    _password = _hashAccountPassword(identity: identity, password: normalized);
    _passwordUpdatedAt = DateTime.now();
    _syncCurrentDriverAccessPassword(normalized);
    unawaited(_persistCurrentAccount());
    notifyListeners();
    return true;
  }

  String? changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    if (_user?.role == UserRole.admin) {
      return "password_locked";
    }
    final currentNormalized = currentPassword.trim();
    final nextNormalized = newPassword.trim();
    final identity = _currentPasswordIdentity;
    if (identity == null || identity.trim().isEmpty) {
      return "current_password_mismatch";
    }
    if (_password.isNotEmpty &&
        !_matchesAccountPassword(identity: identity, candidate: currentNormalized)) {
      return "current_password_mismatch";
    }
    if (nextNormalized.length < 6) {
      return "password_too_short";
    }
    _password = _hashAccountPassword(identity: identity, password: nextNormalized);
    _passwordUpdatedAt = DateTime.now();
    _syncCurrentDriverAccessPassword(nextNormalized);
    unawaited(_persistCurrentAccount());
    notifyListeners();
    return null;
  }

  void logout() {
    _user = null;
    _password = "";
    _passwordUpdatedAt = null;
    _currentAccountKey = null;
    _currentDriverAccessId = null;
    _currentPasswordIdentity = null;
    notifyListeners();
  }

  Future<void> _refreshAuthorizedDriversFromServer() async {
    final remote = await _fetchAuthorizedDriversFromServer();
    if (remote == null) return;
    if (remote.isEmpty && _authorizedDrivers.isNotEmpty) {
      await _restoreAuthorizedDriversOnServer();
      notifyListeners();
      return;
    }
    _authorizedDrivers
      ..clear()
      ..addAll(remote.map(_secureDriverAccessProfile));
    await _persistAuthorizedDrivers();
    notifyListeners();
  }

  Future<void> _hydrateLocalState() async {
    var shouldPersistDrivers = false;
    var shouldPersistAccounts = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawDrivers = prefs.getString(_authorizedDriversKey);
      if (rawDrivers == null || rawDrivers.trim().isEmpty) {
        _authorizedDrivers.clear();
      } else {
        final decoded = jsonDecode(rawDrivers);
        if (decoded is List) {
          _authorizedDrivers
            ..clear()
            ..addAll(
              decoded
                  .whereType<Map>()
                  .map((item) => DriverAccessProfile.fromJson(item.cast()))
                  .map(_secureDriverAccessProfile)
                  .where(
                    (profile) =>
                        profile.id.isNotEmpty &&
                        profile.email.trim().isNotEmpty,
                  ),
            );
          shouldPersistDrivers = true;
        }
      }

      final rawAccounts = prefs.getString(_accountProfilesKey);
      _storedAccounts.clear();
      if (rawAccounts != null && rawAccounts.trim().isNotEmpty) {
        final decoded = jsonDecode(rawAccounts);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key.toString();
            final value = entry.value;
            if (value is Map) {
              _storedAccounts[key] = _secureStoredAccountRecord(
                key,
                value.cast<String, dynamic>(),
              );
              shouldPersistAccounts = true;
            }
          }
        }
      }
      _ensureFixedAdminAccountSeeded();
      shouldPersistAccounts = true;
    } catch (_) {
      _authorizedDrivers.clear();
      _storedAccounts.clear();
      _ensureFixedAdminAccountSeeded();
    } finally {
      if (shouldPersistDrivers) {
        await _persistAuthorizedDrivers();
      }
      if (shouldPersistAccounts) {
        await _persistStoredAccounts();
      }
      _isReady = true;
      notifyListeners();
    }
  }

  Future<void> _persistAuthorizedDrivers() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = jsonEncode(
      _authorizedDrivers.map((profile) => profile.toJson()).toList(),
    );
    await prefs.setString(_authorizedDriversKey, serialized);
  }

  Future<void> _persistStoredAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountProfilesKey, jsonEncode(_storedAccounts));
  }

  Future<List<DriverAccessProfile>?> _fetchAuthorizedDriversFromServer() async {
    final response = await _sendJsonRequest(
      method: "GET",
      path: "/access/drivers",
    );
    if (response == null) return null;
    final drivers = response["drivers"];
    if (drivers is! List) return null;
    return drivers
        .whereType<Map>()
        .map((item) => DriverAccessProfile.fromJson(item.cast<String, dynamic>()))
        .where((profile) => profile.id.isNotEmpty && profile.email.isNotEmpty)
        .toList();
  }

  Future<DriverAccessProfile?> _authorizeDriverLoginFromServer({
    required String email,
    required String passwordHash,
  }) async {
    final response = await _sendJsonRequest(
      method: "POST",
      path: "/access/drivers/auth",
      body: {
        "email": email.trim(),
        "accessCode": passwordHash,
      },
    );
    if (response == null || response["ok"] != true) return null;
    final profile = response["profile"];
    if (profile is! Map) return null;
    return _secureDriverAccessProfile(
      DriverAccessProfile.fromJson(profile.cast<String, dynamic>()),
    );
  }

  Future<DriverAccessSaveResult> _saveAuthorizedDriverToServer({
    required String? id,
    required String displayName,
    required String email,
    required String accessCode,
    required String accessCodeTail,
    String? phoneNumber,
    String? governmentId,
  }) async {
    final response = await _sendJsonRequest(
      method: "POST",
      path: "/access/drivers/upsert",
      body: {
        "id": id,
        "displayName": displayName,
        "email": email,
        "accessCode": accessCode,
        "accessCodeTail": accessCodeTail,
        "phoneNumber": phoneNumber,
        "governmentId": governmentId,
      },
    );
    if (response == null || response["ok"] != true) {
      return const DriverAccessSaveResult();
    }
    final profile = response["profile"];
    if (profile is! Map) {
      return DriverAccessSaveResult(
        inviteEmailSent: response["inviteEmailSent"] == true,
        inviteQueued: response["inviteQueued"] == true,
        inviteSkipped: response["inviteSkipped"] == true,
        activationUrl: _nonEmpty(response["activationUrl"]?.toString()),
        inviteError: _nonEmpty(response["inviteError"]?.toString()),
      );
    }
    return DriverAccessSaveResult(
      profile: _secureDriverAccessProfile(
        DriverAccessProfile.fromJson(profile.cast<String, dynamic>()),
      ),
      inviteEmailSent: response["inviteEmailSent"] == true,
      inviteQueued: response["inviteQueued"] == true,
      inviteSkipped: response["inviteSkipped"] == true,
      activationUrl: _nonEmpty(response["activationUrl"]?.toString()),
      inviteError: _nonEmpty(response["inviteError"]?.toString()),
    );
  }

  Future<void> _restoreAuthorizedDriversOnServer() async {
    for (final profile in _authorizedDrivers) {
      await _sendJsonRequest(
        method: "POST",
        path: "/access/drivers/upsert",
        body: {
          "id": profile.id,
          "displayName": profile.displayName,
          "email": profile.email,
          "accessCode": profile.accessCode,
          "accessCodeTail": profile.accessCodeTail,
          "phoneNumber": profile.phoneNumber,
          "governmentId": profile.governmentId,
          "isActive": profile.isActive,
          "isActivated": profile.isActivated,
          "activationSentAt": profile.activationSentAt?.toIso8601String(),
          "activatedAt": profile.activatedAt?.toIso8601String(),
          "skipInvite": true,
        },
      );
    }
  }

  Future<DriverAccessProfile?> _toggleAuthorizedDriverOnServer(
    String id,
    bool isActive,
  ) async {
    final response = await _sendJsonRequest(
      method: "POST",
      path: "/access/drivers/toggle",
      body: {
        "id": id,
        "isActive": isActive,
      },
    );
    if (response == null || response["ok"] != true) return null;
    final profile = response["profile"];
    if (profile is! Map) return null;
    return DriverAccessProfile.fromJson(profile.cast<String, dynamic>());
  }

  Future<bool> _removeAuthorizedDriverFromServer(String id) async {
    final response = await _sendJsonRequest(
      method: "POST",
      path: "/access/drivers/remove",
      body: {"id": id},
    );
    return response?["ok"] == true;
  }

  Future<Map<String, dynamic>?> _fetchStoredAccountFromServer(
    String accountKey,
  ) async {
    final response = await _sendJsonRequest(
      method: "GET",
      path: "/accounts/profile",
      queryParameters: {"accountKey": accountKey},
    );
    if (response == null || response["ok"] != true) return null;
    final profile = response["profile"];
    if (profile is Map<String, dynamic>) {
      return profile;
    }
    if (profile is Map) {
      return profile.cast<String, dynamic>();
    }
    return null;
  }

  Future<void> _saveStoredAccountToServer({
    required String accountKey,
    required UserModel user,
  }) async {
    await _saveStoredAccountRecordToServer(
      accountKey: accountKey,
      user: user,
      passwordHash: _password,
      passwordIdentity: _currentPasswordIdentity,
      passwordUpdatedAt: _passwordUpdatedAt,
    );
  }

  Future<void> _saveStoredAccountRecordToServer({
    required String accountKey,
    required UserModel user,
    required String passwordHash,
    required String? passwordIdentity,
    required DateTime? passwordUpdatedAt,
  }) async {
    await _sendJsonRequest(
      method: "POST",
      path: "/accounts/profile/upsert",
      body: {
        "accountKey": accountKey,
        "role": user.role.name,
        "password": passwordHash,
        "passwordIdentity": passwordIdentity,
        "passwordUpdatedAt": passwordUpdatedAt?.toIso8601String(),
        "user": user.toJson(),
      },
    );
  }

  Future<Map<String, dynamic>?> _sendJsonRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    final client = HttpClient();
    try {
      var uri = Uri.parse("${AppConstants.socketUrl}$path");
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }
      final request = await client.openUrl(
        method,
        uri,
      );
      request.headers.set(HttpHeaders.acceptHeader, "application/json");
      if (body != null) {
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          "application/json; charset=utf-8",
        );
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _persistCurrentAccount() async {
    final user = _user;
    final accountKey = _currentAccountKey;
    if (user == null || accountKey == null || accountKey.trim().isEmpty) {
      return;
    }
    _storedAccounts[accountKey] = {
      "user": user.toJson(),
      "password": _password,
      "passwordIdentity": _currentPasswordIdentity,
      "passwordUpdatedAt": _passwordUpdatedAt?.toIso8601String(),
      "savedAt": DateTime.now().toIso8601String(),
    };
    await _persistStoredAccounts();
    await _saveStoredAccountToServer(accountKey: accountKey, user: user);
    if (user.role == UserRole.driver && _currentDriverAccessId != null) {
      await _saveAuthorizedDriverToServer(
        id: _currentDriverAccessId,
        displayName: user.legalName,
        email: user.email,
        accessCode: _password,
        accessCodeTail: _driverAccessTail(_currentDriverAccessId!),
        phoneNumber: _nullableTrim(user.phoneNumber),
        governmentId: _nullableTrim(user.governmentId),
      );
    }
  }

  void _upsertAuthorizedDriver(DriverAccessProfile profile) {
    final secureProfile = _secureDriverAccessProfile(profile);
    final normalizedEmail = DriverAccessProfile.normalizeLookup(profile.email);
    final index = _authorizedDrivers.indexWhere(
      (item) =>
          item.id == secureProfile.id ||
          DriverAccessProfile.normalizeLookup(item.email) == normalizedEmail,
    );
    if (index >= 0) {
      _authorizedDrivers[index] = secureProfile;
      return;
    }
    _authorizedDrivers.insert(0, secureProfile);
  }

  void _remapCurrentAccountKeyIfNeeded(UserModel nextUser) {
    final currentKey = _currentAccountKey;
    if (currentKey == null) return;
    final nextKey = _resolveAccountKey(
      role: nextUser.role,
      loginIdentifier: nextUser.name,
      email: nextUser.email,
    );
    if (nextKey == currentKey) return;
    final existing = _storedAccounts.remove(currentKey);
    if (existing != null) {
      _storedAccounts[nextKey] = existing;
    }
    _currentAccountKey = nextKey;
  }

  void _syncCurrentDriverAccessFromUser(UserModel user) {
    if (user.role != UserRole.driver || _currentDriverAccessId == null) return;
    final index = _authorizedDrivers.indexWhere(
      (profile) => profile.id == _currentDriverAccessId,
    );
    if (index < 0) return;
    _authorizedDrivers[index] = _authorizedDrivers[index].copyWith(
      displayName: user.legalName,
      email: user.email,
      phoneNumber: user.phoneNumber,
      governmentId: user.governmentId,
    );
    unawaited(_persistAuthorizedDrivers());
  }

  void _syncCurrentDriverAccessPassword(String password) {
    final user = _user;
    if (user?.role != UserRole.driver || _currentDriverAccessId == null) return;
    final index = _authorizedDrivers.indexWhere(
      (profile) => profile.id == _currentDriverAccessId,
    );
    if (index < 0) return;
    final normalized = password.trim();
    if (normalized.isEmpty) return;
    _authorizedDrivers[index] = _authorizedDrivers[index].copyWith(
      accessCode: _hashDriverAccessPassword(
        driverAccessId: _currentDriverAccessId!,
        password: normalized,
      ),
      accessCodeTail: AuthSecurity.secretTail(normalized),
    );
    unawaited(_persistAuthorizedDrivers());
  }

  UserModel? _userFromStoredAccount(Map<String, dynamic>? stored) {
    final raw = stored?["user"];
    if (raw is Map) {
      return UserModel.fromJson(raw.cast<String, dynamic>());
    }
    return null;
  }

  String _passwordFromStoredAccount(Map<String, dynamic>? stored) {
    return _nonEmpty(stored?["password"]?.toString()) ?? "";
  }

  String? _passwordIdentityFromStoredAccount(Map<String, dynamic>? stored) {
    return _nonEmpty(stored?["passwordIdentity"]?.toString());
  }

  DateTime? _passwordUpdatedAtFromStoredAccount(Map<String, dynamic>? stored) {
    return DateTime.tryParse(stored?["passwordUpdatedAt"]?.toString() ?? "");
  }

  String _resolveAccountKey({
    required UserRole role,
    required String loginIdentifier,
    String? email,
  }) {
    final roleName = role.name;
    final emailKey = _nonEmpty(email)?.toLowerCase();
    if (emailKey != null) {
      return "$roleName:${DriverAccessProfile.normalizeLookup(emailKey)}";
    }
    final identifier = DriverAccessProfile.normalizeLookup(loginIdentifier);
    return "$roleName:$identifier";
  }

  String _fallbackEmail(UserRole role, String identifier, String shortId) {
    final normalized = identifier.toLowerCase().replaceAll(
      RegExp(r"[^a-z0-9]+"),
      "",
    );
    return "${normalized.isEmpty ? role.name : normalized}@atob.app";
  }

  String _stableAccountId({
    required UserRole role,
    required String loginIdentifier,
    String? email,
  }) {
    final base = DriverAccessProfile.normalizeLookup(
      _nonEmpty(email) ?? loginIdentifier,
    ).replaceAll(RegExp(r"[^a-z0-9]+"), "_");
    final prefix = role == UserRole.admin ? "adm" : "drv";
    return "${prefix}_${base.isEmpty ? "account" : base}";
  }

  String? _nullableTrim(String? value) {
    final text = (value ?? "").trim();
    return text.isEmpty ? null : text;
  }

  String? _nonEmpty(String? value) {
    final text = (value ?? "").trim();
    return text.isEmpty ? null : text;
  }

  DriverAccessProfile? _findAuthorizedDriverByEmail(String normalizedEmail) {
    for (final profile in _authorizedDrivers) {
      if (!profile.isActive) continue;
      if (DriverAccessProfile.normalizeLookup(profile.email) ==
          normalizedEmail) {
        return profile;
      }
    }
    return null;
  }

  DriverAccessProfile? _findAuthorizedDriverForEdit({
    String? id,
    required String normalizedEmail,
  }) {
    for (final profile in _authorizedDrivers) {
      if (id != null && profile.id == id) return profile;
      if (DriverAccessProfile.normalizeLookup(profile.email) ==
          normalizedEmail) {
        return profile;
      }
    }
    return null;
  }

  DriverAccessProfile _secureDriverAccessProfile(DriverAccessProfile profile) {
    final resolvedTail =
        _nonEmpty(profile.accessCodeTail) ??
        (AuthSecurity.isSecureHash(profile.accessCode)
            ? null
            : AuthSecurity.secretTail(profile.accessCode));
    final resolvedAccessCode = profile.accessCode.trim().isEmpty
        ? ""
        : AuthSecurity.ensureSecretHash(
            scope: "driver-access",
            identity: profile.id,
            secretOrHash: profile.accessCode,
          );
    return profile.copyWith(
      accessCode: resolvedAccessCode,
      accessCodeTail: resolvedTail,
    );
  }

  Map<String, dynamic> _secureStoredAccountRecord(
    String accountKey,
    Map<String, dynamic>? stored,
  ) {
    final current = <String, dynamic>{...?stored};
    final storedUser = _userFromStoredAccount(current);
    final passwordIdentity =
        _passwordIdentityFromStoredAccount(current) ??
        _resolvePasswordIdentity(
          role: storedUser?.role ?? UserRole.driver,
          accountKey: accountKey,
          storedUser: storedUser,
        );
    final securePassword = AuthSecurity.ensureSecretHash(
      scope: "account",
      identity: passwordIdentity,
      secretOrHash: current["password"]?.toString() ?? "",
    );
    current["password"] = securePassword;
    current["passwordIdentity"] = passwordIdentity;
    current["passwordUpdatedAt"] =
        current["passwordUpdatedAt"]?.toString() ?? DateTime.now().toIso8601String();
    current["savedAt"] =
        current["savedAt"]?.toString() ?? DateTime.now().toIso8601String();
    return current;
  }

  void _ensureFixedAdminAccountSeeded() {
    final accountKey = _resolveAccountKey(
      role: UserRole.admin,
      loginIdentifier: AuthSecurity.fixedAdminEmail,
      email: AuthSecurity.fixedAdminEmail,
    );
    final current = _secureStoredAccountRecord(accountKey, _storedAccounts[accountKey]);
    final currentUser = _userFromStoredAccount(current);
    final adminUser = UserModel(
      id: currentUser?.id ?? "adm_dispatch_primary",
      name: _nonEmpty(currentUser?.name) ?? "Admin",
      role: UserRole.admin,
      legalName: _nonEmpty(currentUser?.legalName) ?? "Admin Dispatch",
      email: AuthSecurity.fixedAdminEmail,
      phoneNumber: _nonEmpty(currentUser?.phoneNumber) ?? "+1 804 555 1200",
      address: _nonEmpty(currentUser?.address) ?? "Virginia dispatch lane",
      governmentId: _nonEmpty(currentUser?.governmentId) ?? "ADM-PRIMARY",
      languageCode: _nonEmpty(currentUser?.languageCode) ?? "es",
      mapThemeMode: _nonEmpty(currentUser?.mapThemeMode) ?? "flow",
      avatarPath: _nonEmpty(currentUser?.avatarPath),
      isOnline: true,
    );
    _storedAccounts[accountKey] = {
      ...current,
      "user": adminUser.toJson(),
      "passwordIdentity": AuthSecurity.fixedAdminCredentialId,
      "password": AuthSecurity.fixedAdminPasswordHash,
      "passwordUpdatedAt":
          current["passwordUpdatedAt"]?.toString() ?? DateTime.now().toIso8601String(),
      "savedAt": current["savedAt"]?.toString() ?? DateTime.now().toIso8601String(),
    };
  }

  String _resolvePasswordIdentity({
    required UserRole role,
    required String accountKey,
    String? driverAccessId,
    UserModel? storedUser,
  }) {
    if (role == UserRole.admin) {
      return AuthSecurity.fixedAdminCredentialId;
    }
    return _nonEmpty(driverAccessId) ??
        _nonEmpty(storedUser?.id) ??
        accountKey;
  }

  String _hashAccountPassword({
    required String identity,
    required String password,
  }) {
    return AuthSecurity.hashSecret(
      scope: "account",
      identity: identity,
      secret: password,
    );
  }

  bool _matchesAccountPassword({
    required String identity,
    required String candidate,
  }) {
    return AuthSecurity.matchesSecret(
      scope: "account",
      identity: identity,
      candidate: candidate,
      storedHash: _password,
    );
  }

  String _hashDriverAccessPassword({
    required String driverAccessId,
    required String password,
  }) {
    return AuthSecurity.hashSecret(
      scope: "driver-access",
      identity: driverAccessId,
      secret: password,
    );
  }

  String _driverAccessTail(String driverAccessId) {
    for (final profile in _authorizedDrivers) {
      if (profile.id == driverAccessId) {
        return profile.accessCodeTail ?? "";
      }
    }
    return "";
  }

  DriverRecordData _driverRecordFromProfile(DriverAccessProfile profile) {
    final accountKey = _resolveAccountKey(
      role: UserRole.driver,
      loginIdentifier: profile.displayName,
      email: profile.email,
    );
    final stored = _secureStoredAccountRecord(accountKey, _storedAccounts[accountKey]);
    final storedUser = _userFromStoredAccount(stored);
    final user =
        storedUser ??
        UserModel(
          id: profile.id,
          name: profile.displayName,
          role: UserRole.driver,
          legalName: profile.displayName,
          email: profile.email,
          phoneNumber: profile.phoneNumber ?? "",
          address: "",
          governmentId: profile.governmentId ?? "",
          languageCode: "es",
          mapThemeMode: "flow",
          isOnline: true,
          avatarPath: null,
          vehicleMake: "",
          vehicleModel: "",
          vehicleColor: "",
          vehiclePlate: "",
          vehicleYear: "",
        );
    return DriverRecordData(
      profile: profile,
      user: user,
      accountKey: accountKey,
      passwordIdentity:
          _passwordIdentityFromStoredAccount(stored) ??
          _resolvePasswordIdentity(
            role: UserRole.driver,
            accountKey: accountKey,
            driverAccessId: profile.id,
            storedUser: storedUser,
          ),
      passwordUpdatedAt: _passwordUpdatedAtFromStoredAccount(stored),
    );
  }
}
