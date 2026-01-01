import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:zlogger/zlogger.dart';

/// Callback function for validating credentials.
/// Returns true if the credentials are valid, false otherwise.
typedef CredentialValidator = FutureOr<bool> Function(String username, String password);

/// Basic HTTP Authentication middleware.
///
/// Implements HTTP Basic Authentication as defined in RFC 7617.
/// Credentials are sent in the Authorization header as base64-encoded username:password.
///
/// Security notes:
/// - Should only be used over HTTPS in production
/// - Credentials are base64-encoded, not encrypted
/// - Consider using more secure authentication methods for sensitive data
///
/// Example usage:
/// ```dart
/// // Single user
/// app.use(BasicAuth(
///   username: 'admin',
///   password: 'secret123',
///   realm: 'Admin Area',
/// ));
///
/// // Multiple users with validator
/// app.use(BasicAuth.withValidator(
///   validator: (username, password) {
///     final validUsers = {
///       'admin': 'secret123',
///       'user': 'password456',
///     };
///     return validUsers[username] == password;
///   },
/// ));
///
/// // Async validator (e.g., database lookup)
/// app.use(BasicAuth.withValidator(
///   validator: (username, password) async {
///     final user = await db.findUser(username);
///     return user?.checkPassword(password) ?? false;
///   },
/// ));
/// ```
class BasicAuth implements Middleware {
  static final _log = Log.named('BasicAuth');

  final String? _username;
  final String? _password;
  final CredentialValidator? _validator;

  /// The realm to use in the `WWW-Authenticate` header.
  /// Displayed to users in the browser's authentication dialog.
  final String realm;

  /// Creates a BasicAuth middleware with a single username and password.
  ///
  /// [username] and [password] are the valid credentials.
  /// [realm] is the realm name shown in the authentication dialog.
  const BasicAuth({
    required String username,
    required String password,
    this.realm = 'Restricted Area',
  })  : _username = username,
        _password = password,
        _validator = null;

  /// Creates a BasicAuth middleware with a custom credential validator.
  ///
  /// [validator] is a function that receives username and password and returns
  /// true if they are valid. Can be async for database lookups.
  /// [realm] is the realm name shown in the authentication dialog.
  const BasicAuth.withValidator({
    required CredentialValidator validator,
    this.realm = 'Restricted Area',
  })  : _username = null,
        _password = null,
        _validator = validator;

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    final authHeader = ctx.req.header('authorization');

    // No Authorization header or not Basic auth
    if (authHeader == null || !authHeader.toLowerCase().startsWith('basic ')) {
      await _unauthorized(ctx, authHeader == null ? 'Missing Authorization header' : 'Not Basic auth');
      return;
    }

    try {
      // Extract and decode credentials
      final encodedCredentials = authHeader.substring(6).trim();

      if (encodedCredentials.isEmpty) {
        await _unauthorized(ctx, 'Empty credentials');
      return;
      }

      final decodedBytes = base64.decode(encodedCredentials);
      final decodedString = utf8.decode(decodedBytes);

      // Split into username and password (only split on first colon)
      final colonIndex = decodedString.indexOf(':');
      if (colonIndex == -1) {
        await _unauthorized(ctx, 'Invalid credential format');
      return;
      }

      final username = decodedString.substring(0, colonIndex);
      final password = decodedString.substring(colonIndex + 1);

      // Validate credentials
      final isValid = await _validateCredentials(username, password);

      if (!isValid) {
        await _unauthorized(ctx, 'Invalid credentials');
      return;
      }

      // Authentication successful, proceed to next middleware/handler
      await next();
    } catch (e) {
      // Invalid base64, UTF-8 decoding error, or other errors
      await _unauthorized(ctx, 'Credential decode error');
      return;
    }
  }

  /// Validates the provided credentials.
  Future<bool> _validateCredentials(String username, String password) async {
    if (_validator != null) {
      return await _validator(username, password);
    }

    // Simple username/password check
    // Note: This is a constant-time comparison to prevent timing attacks
    return _constantTimeEquals(username, _username!) &&
        _constantTimeEquals(password, _password!);
  }

  /// Constant-time string comparison to prevent timing attacks.
  ///
  /// Regular string comparison (==) can leak information about the password
  /// through timing differences, allowing attackers to determine correct
  /// characters one by one.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }

    return result == 0;
  }

  /// Sends a 401 Unauthorized response with the appropriate WWW-Authenticate header.
  Future<void> _unauthorized(Context ctx, String reason) async {
    _log.warn(
      'Basic auth failed: $reason',
      {
        'request_id': ctx.get<String>('_requestId'),
        'method': ctx.req.method,
        'path': ctx.req.path,
        'ip': _safeGetIp(ctx),
      },
    );

    ctx.res.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Basic realm="$realm"');
    await ctx.res.json(
      {'error': 'Unauthorized', 'message': 'Invalid credentials'},
      status: HttpStatus.unauthorized,
    );
  }

  /// Safely gets the remote IP address, returning null if not available.
  String? _safeGetIp(Context ctx) {
    try {
      return ctx.req.remoteAddress;
    } catch (_) {
      return null;
    }
  }
}
