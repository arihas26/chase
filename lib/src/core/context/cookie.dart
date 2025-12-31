import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// SameSite cookie attribute.
enum SameSite {
  /// Cookie is sent with same-site and cross-site top-level navigations.
  lax('Lax'),

  /// Cookie is only sent with same-site requests.
  strict('Strict'),

  /// Cookie is sent with all requests (requires Secure attribute).
  none('None');

  const SameSite(this.value);
  final String value;
}

/// Cookie prefix for enhanced security.
enum CookiePrefix {
  /// No prefix.
  none,

  /// `__Secure-` prefix. Requires Secure attribute.
  secure,

  /// `__Host-` prefix. Requires Secure, Path=/, no Domain.
  host,
}

// -----------------------------------------------------------------------------
// Cookie Signing
// -----------------------------------------------------------------------------

/// Signs a cookie value using HMAC-SHA256.
///
/// Returns the value in format: `value.signature`
String signCookieValue(String value, String secret) {
  final signature = _createSignature(value, secret);
  return '$value.$signature';
}

/// Verifies and extracts the value from a signed cookie.
///
/// Returns null if the signature is invalid.
String? verifySignedCookieValue(String signedValue, String secret) {
  final lastDot = signedValue.lastIndexOf('.');
  if (lastDot == -1) return null;

  final value = signedValue.substring(0, lastDot);
  final signature = signedValue.substring(lastDot + 1);

  final expectedSignature = _createSignature(value, secret);
  if (!_secureCompare(signature, expectedSignature)) {
    return null;
  }

  return value;
}

String _createSignature(String value, String secret) {
  final hmac = Hmac(sha256, utf8.encode(secret));
  final digest = hmac.convert(utf8.encode(value));
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}

/// Constant-time comparison to prevent timing attacks.
bool _secureCompare(String a, String b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}

// -----------------------------------------------------------------------------
// Cookie Formatting
// -----------------------------------------------------------------------------

/// Formats a Set-Cookie header value.
String formatSetCookie(
  String name,
  String value, {
  Duration? maxAge,
  DateTime? expires,
  String? domain,
  String? path,
  bool httpOnly = true,
  bool secure = false,
  SameSite? sameSite,
  bool partitioned = false,
  CookiePrefix prefix = CookiePrefix.none,
}) {
  // Apply prefix
  final cookieName = switch (prefix) {
    CookiePrefix.none => name,
    CookiePrefix.secure => '__Secure-$name',
    CookiePrefix.host => '__Host-$name',
  };

  // Encode value for safety
  final encodedValue = Uri.encodeComponent(value);

  final parts = <String>['$cookieName=$encodedValue'];

  // __Host- prefix requires Path=/ and no Domain
  if (prefix == CookiePrefix.host) {
    parts.add('Path=/');
    // Domain must not be set for __Host-
  } else {
    if (domain != null) parts.add('Domain=$domain');
    if (path != null) parts.add('Path=$path');
  }

  if (maxAge != null) parts.add('Max-Age=${maxAge.inSeconds}');
  if (expires != null) parts.add('Expires=${HttpDate.format(expires.toUtc())}');

  // __Secure- and __Host- require Secure
  if (secure || prefix != CookiePrefix.none) parts.add('Secure');
  if (httpOnly) parts.add('HttpOnly');
  if (sameSite != null) parts.add('SameSite=${sameSite.value}');
  if (partitioned) parts.add('Partitioned');

  return parts.join('; ');
}

/// Parses a Cookie header into a map.
Map<String, String> parseCookieHeader(String? header) {
  if (header == null || header.isEmpty) return const {};

  final map = <String, String>{};
  for (final part in header.split(';')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final index = trimmed.indexOf('=');
    if (index <= 0) continue;
    final key = trimmed.substring(0, index).trim();
    final value = trimmed.substring(index + 1).trim();
    if (key.isEmpty) continue;
    // Decode URI-encoded value
    try {
      map[key] = Uri.decodeComponent(value);
    } catch (_) {
      map[key] = value; // Use raw value if decoding fails
    }
  }
  return map;
}

// -----------------------------------------------------------------------------
// JSON Cookie Helpers
// -----------------------------------------------------------------------------

/// Encodes an object as a JSON string for cookie storage.
String encodeCookieJson(Object? value) {
  return base64Url.encode(utf8.encode(jsonEncode(value)));
}

/// Decodes a JSON cookie value.
///
/// Returns null if decoding fails.
T? decodeCookieJson<T>(String encoded) {
  try {
    final json = utf8.decode(base64Url.decode(_addBase64Padding(encoded)));
    return jsonDecode(json) as T?;
  } catch (_) {
    return null;
  }
}

String _addBase64Padding(String str) {
  final mod = str.length % 4;
  if (mod == 0) return str;
  return str + '=' * (4 - mod);
}

// -----------------------------------------------------------------------------
// Duration Helpers
// -----------------------------------------------------------------------------

/// Common cookie duration presets.
abstract class CookieDuration {
  /// Session cookie (no expiry).
  static const Duration? session = null;

  /// 1 hour.
  static const hour = Duration(hours: 1);

  /// 1 day.
  static const day = Duration(days: 1);

  /// 1 week.
  static const week = Duration(days: 7);

  /// 30 days.
  static const month = Duration(days: 30);

  /// 1 year.
  static const year = Duration(days: 365);
}
