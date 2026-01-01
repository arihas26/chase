import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:zlogger/zlogger.dart';

/// Callback function for validating bearer tokens.
/// Returns true if the token is valid, false otherwise.
///
/// The validator can be synchronous or asynchronous, allowing for:
/// - Simple token comparison
/// - JWT verification
/// - Database lookups
/// - API calls to authentication services
typedef BearerTokenValidator = FutureOr<bool> Function(String token);

/// Bearer Token Authentication middleware.
///
/// Implements HTTP Bearer token authentication as commonly used for API authentication.
/// Tokens are sent in the Authorization header as: `Authorization: Bearer <token>`
///
/// Security notes:
/// - Should only be used over HTTPS in production
/// - Tokens should be cryptographically secure (e.g., JWT, random strings)
/// - Consider implementing token expiration and refresh mechanisms
/// - Store tokens securely and never log them
///
/// Example usage:
/// ```dart
/// // Simple token validation
/// app.use(BearerAuth(token: 'secret-api-key-123'));
///
/// // Multiple tokens
/// app.use(BearerAuth.withValidator(
///   validator: (token) {
///     final validTokens = {
///       'api-key-1',
///       'api-key-2',
///       'api-key-3',
///     };
///     return validTokens.contains(token);
///   },
/// ));
///
/// // JWT verification (async)
/// app.use(BearerAuth.withValidator(
///   validator: (token) async {
///     try {
///       final jwt = JWT.verify(token, SecretKey('secret'));
///       return jwt.payload['exp'] > DateTime.now().millisecondsSinceEpoch;
///     } catch (e) {
///       return false;
///     }
///   },
/// ));
///
/// // Database lookup
/// app.use(BearerAuth.withValidator(
///   validator: (token) async {
///     final apiKey = await db.findApiKey(token);
///     return apiKey != null && apiKey.isActive;
///   },
/// ));
/// ```
class BearerAuth implements Middleware {
  static final _log = Log.named('BearerAuth');

  final String? _token;
  final BearerTokenValidator? _validator;

  /// The realm to use in the `WWW-Authenticate` header.
  /// Displayed in error responses and authentication challenges.
  final String realm;

  /// Creates a BearerAuth middleware with a single static token.
  ///
  /// [token] is the valid bearer token.
  /// [realm] is the realm name shown in authentication challenges.
  const BearerAuth({required String token, this.realm = 'Restricted Area'})
    : _token = token,
      _validator = null;

  /// Creates a BearerAuth middleware with a custom token validator.
  ///
  /// [validator] is a function that receives a token and returns true if valid.
  /// Can be async for database lookups or JWT verification.
  /// [realm] is the realm name shown in authentication challenges.
  const BearerAuth.withValidator({
    required BearerTokenValidator validator,
    this.realm = 'Restricted Area',
  }) : _token = null,
       _validator = validator;

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    final authHeader = ctx.req.header('authorization');

    // No Authorization header or not Bearer token
    if (authHeader == null || !authHeader.toLowerCase().startsWith('bearer ')) {
      await _unauthorized(ctx, authHeader == null ? 'Missing Authorization header' : 'Not a Bearer token');
      return;
    }

    try {
      // Extract token (skip "Bearer " prefix which is 7 characters)
      final token = authHeader.substring(7).trim();

      if (token.isEmpty) {
        await _unauthorized(ctx, 'Empty token');
      return;
      }

      // Validate token
      final isValid = await _validateToken(token);

      if (!isValid) {
        await _unauthorized(ctx, 'Invalid token');
      return;
      }

      // Authentication successful, proceed to next middleware/handler
      await next();
    } catch (e) {
      // Any error during validation (e.g., JWT parsing error) is treated as unauthorized
      await _unauthorized(ctx, 'Token validation error');
      return;
    }
  }

  /// Validates the provided token.
  Future<bool> _validateToken(String token) async {
    if (_validator != null) {
      try {
        return await _validator(token);
      } catch (e) {
        // If validator throws, treat as invalid token
        return false;
      }
    }

    // Simple token comparison
    // Note: This is constant-time comparison for security
    return _constantTimeEquals(token, _token!);
  }

  /// Constant-time string comparison to prevent timing attacks.
  ///
  /// Even for bearer tokens, timing attacks are theoretically possible,
  /// so we use constant-time comparison.
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
      'Bearer auth failed: $reason',
      {
        'method': ctx.req.method,
        'path': ctx.req.path,
        'ip': _safeGetIp(ctx),
      },
    );

    ctx.res.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer realm="$realm"');
    await ctx.res.json({
      'error': 'Unauthorized',
      'message': 'Invalid or missing token',
    }, status: HttpStatus.unauthorized);
  }

  /// Safely gets the remote IP address, returning null if unavailable.
  String? _safeGetIp(Context ctx) {
    try {
      return ctx.req.remoteAddress;
    } catch (_) {
      return null;
    }
  }
}
