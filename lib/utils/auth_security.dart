import "dart:convert";

import "package:crypto/crypto.dart";

class AuthSecurity {
  const AuthSecurity._();

  static const String _pepper = "atob::dispatch::secure::2026";
  static const String _prefix = "hmac-sha256:";
  static const String fixedAdminEmail = "devb12004@gmail.com";
  static const String fixedAdminCredentialId = "admin:primary";
  static const String fixedAdminPasswordHash =
      "hmac-sha256:6cd3ac218bd61b2d0e2068e68778ca8ded4b0b140fa67edde51d1109f19c4de5";

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static bool isSecureHash(String value) {
    final text = value.trim();
    return text.startsWith(_prefix) && text.length > _prefix.length;
  }

  static String hashSecret({
    required String scope,
    required String identity,
    required String secret,
  }) {
    final normalizedScope = scope.trim().toLowerCase();
    final normalizedIdentity = identity.trim().toLowerCase();
    final normalizedSecret = secret.trim();
    if (normalizedScope.isEmpty ||
        normalizedIdentity.isEmpty ||
        normalizedSecret.isEmpty) {
      return "";
    }
    final key = utf8.encode("$_pepper|$normalizedScope");
    final payload = utf8.encode(
      "$normalizedScope|$normalizedIdentity|$normalizedSecret",
    );
    final digest = Hmac(sha256, key).convert(payload).toString();
    return "$_prefix$digest";
  }

  static String ensureSecretHash({
    required String scope,
    required String identity,
    required String secretOrHash,
  }) {
    final value = secretOrHash.trim();
    if (value.isEmpty) return "";
    if (isSecureHash(value)) return value;
    return hashSecret(scope: scope, identity: identity, secret: value);
  }

  static bool matchesSecret({
    required String scope,
    required String identity,
    required String candidate,
    required String storedHash,
  }) {
    final normalizedHash = storedHash.trim();
    if (normalizedHash.isEmpty) return false;
    final hashedCandidate = ensureSecretHash(
      scope: scope,
      identity: identity,
      secretOrHash: candidate,
    );
    return hashedCandidate == normalizedHash;
  }

  static String secretTail(String secret) {
    final value = secret.trim();
    if (value.isEmpty) return "";
    return value.length <= 2 ? value : value.substring(value.length - 2);
  }

  static bool matchesFixedAdmin({
    required String email,
    required String password,
  }) {
    return normalizeEmail(email) == fixedAdminEmail &&
        matchesSecret(
          scope: "admin",
          identity: fixedAdminCredentialId,
          candidate: password,
          storedHash: fixedAdminPasswordHash,
        );
  }
}
