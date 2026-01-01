import 'dart:async';
import 'dart:io';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:zlogger/zlogger.dart';

/// Callback function for validating JWT payload.
/// Returns true if the payload is valid, false otherwise.
///
/// The validator receives the decoded JWT payload as a Map.
/// This allows for custom validation logic such as:
/// - Checking custom claims
/// - Validating user roles or permissions
/// - Verifying token scope
/// - Additional business logic validation
typedef JwtPayloadValidator =
    FutureOr<bool> Function(Map<String, dynamic> payload);

/// JWT (JSON Web Token) Authentication middleware.
///
/// Implements JWT authentication for API endpoints. Validates JWT tokens
/// sent in the Authorization header as: `Authorization: Bearer <token>`
///
/// The middleware automatically:
/// - Verifies the token signature using the provided secret key
/// - Checks token expiration (exp claim)
/// - Validates the token structure
/// - Stores decoded payload in context params for use in handlers
///
/// Security notes:
/// - Always use a strong, randomly generated secret key
/// - Use HTTPS in production to prevent token interception
/// - Implement token expiration (exp claim)
/// - Consider implementing token refresh mechanisms
/// - Store secret keys securely (environment variables, secrets management)
/// - Use appropriate algorithms (HS256, RS256, etc.)
///
/// Example usage:
/// ```dart
/// // Basic JWT authentication
/// app.use(JwtAuth(secretKey: 'your-secret-key-min-32-chars'));
///
/// // With custom algorithm
/// app.use(JwtAuth(
///   secretKey: 'your-secret-key',
///   algorithm: JWTAlgorithm.HS512,
/// ));
///
/// // With payload validation (e.g., check user role)
/// app.use(JwtAuth(
///   secretKey: 'your-secret-key',
///   payloadValidator: (payload) {
///     final role = payload['role'] as String?;
///     return role == 'admin' || role == 'moderator';
///   },
/// ));
///
/// // With async validation (e.g., check if user is still active)
/// app.use(JwtAuth(
///   secretKey: 'your-secret-key',
///   payloadValidator: (payload) async {
///     final userId = payload['sub'] as String?;
///     if (userId == null) return false;
///     final user = await db.findUser(userId);
///     return user != null && user.isActive;
///   },
/// ));
///
/// // Accessing JWT payload in handler
/// app.get('/profile', (ctx) async {
///   final payload = ctx.get<Map<String, dynamic>>('_jwt_payload');
///   final userId = payload?['sub'];
///   // ... use userId to fetch user data
///   await ctx.res.json({'userId': userId});
/// });
/// ```
class JwtAuth implements Middleware {
  static final _log = Log.named('JwtAuth');

  /// The secret key used to verify JWT signatures.
  /// Should be a strong, randomly generated string.
  /// Minimum 32 characters recommended for HS256.
  final String secretKey;

  /// Optional custom validator for JWT payload.
  /// Receives the decoded payload and returns true if valid.
  final JwtPayloadValidator? payloadValidator;

  /// The realm to use in the `WWW-Authenticate` header.
  /// Displayed in error responses and authentication challenges.
  final String realm;

  /// The JWT algorithm to use for verification.
  /// Common algorithms: HS256, HS384, HS512, RS256, RS512.
  /// Default: HS256
  final JWTAlgorithm algorithm;

  /// Creates a JwtAuth middleware with the specified configuration.
  ///
  /// [secretKey] is required and used to verify token signatures.
  /// [payloadValidator] is optional for custom payload validation.
  /// [realm] is the authentication realm (default: "Protected Area").
  /// [algorithm] is the JWT algorithm to use (default: HS256).
  const JwtAuth({
    required this.secretKey,
    this.payloadValidator,
    this.realm = 'Protected Area',
    this.algorithm = JWTAlgorithm.HS256,
  });

  @override
  Future<void> handle(Context ctx, NextFunction next) async {
    final authHeader = ctx.req.header('authorization');

    // No Authorization header or not Bearer token
    if (authHeader == null || !authHeader.toLowerCase().startsWith('bearer ')) {
      await _unauthorized(ctx, 'Missing or invalid Authorization header');
      return;
    }

    try {
      // Extract token (skip "Bearer " prefix which is 7 characters)
      final token = authHeader.substring(7).trim();

      if (token.isEmpty) {
        await _unauthorized(ctx, 'Missing token');
        return;
      }

      // Verify JWT signature and expiration
      final jwt = JWT.verify(token, SecretKey(secretKey), checkExpiresIn: true);

      // Extract payload
      final payload = jwt.payload as Map<String, dynamic>;

      // Validate payload with custom validator if provided
      if (payloadValidator != null) {
        final isValid = await _validatePayload(payload);
        if (!isValid) {
          await _unauthorized(ctx, 'Invalid token payload');
          return;
        }
      }

      // Store JWT data in context for use in handlers
      ctx.set('_jwt_payload', payload);
      ctx.set('_jwt_token', token);

      // Authentication successful, proceed to next middleware/handler
      await next();
    } on JWTExpiredException {
      await _unauthorized(ctx, 'Token has expired');
      return;
    } on JWTException catch (e) {
      await _unauthorized(ctx, 'Invalid token: ${e.message}');
      return;
    } catch (e) {
      // Any other error during validation
      await _unauthorized(ctx, 'Authentication error');
      return;
    }
  }

  /// Validates the JWT payload using the custom validator.
  Future<bool> _validatePayload(Map<String, dynamic> payload) async {
    if (payloadValidator == null) {
      return true;
    }

    try {
      return await payloadValidator!(payload);
    } catch (e) {
      // If validator throws, treat as invalid token
      return false;
    }
  }

  /// Sends a 401 Unauthorized response with the appropriate WWW-Authenticate header.
  Future<void> _unauthorized(Context ctx, String message) async {
    _log.warn('JWT auth failed: $message', {
      'request_id': ctx.get<String>('_requestId'),
      'method': ctx.req.method,
      'path': ctx.req.path,
      'ip': _safeGetIp(ctx),
    });

    ctx.res.headers.set(
      HttpHeaders.wwwAuthenticateHeader,
      'Bearer realm="$realm"',
    );
    await ctx.res.json({
      'error': 'Unauthorized',
      'message': message,
    }, status: HttpStatus.unauthorized);
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
