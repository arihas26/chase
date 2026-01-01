/// Example: Structured Logging with RequestLogger
///
/// RequestLogger is an all-in-one middleware that handles:
/// - Request ID generation (UUID v4) with header propagation
/// - Log context propagation (via Zone) for automatic request_id in all logs
/// - Request/response logging with status, duration, etc.
///
/// Run with: dart run example/logger.dart
/// Test with: curl http://localhost:3000/users/123
library;

import 'dart:io';

import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  // Configure zlogger output (optional)
  LogConfig.global = DefaultLogger(
    minLevel: LogLevel.debug,
    color: true,
  );

  // Application-level logging (outside of request context)
  log.info('Application starting', {'version': '1.0.0'});

  // Single middleware handles all logging concerns:
  // - Generates request_id (UUID v4)
  // - Sets X-Request-ID header in response
  // - Propagates request_id to all log calls via Zone
  // - Logs each request with method, path, status, duration
  app.use(RequestLogger(
    minLevel: LogLevel.info,
    skip: (ctx) => ctx.req.path == '/health',
    slowThreshold: Duration(seconds: 1),
  ));

  // Health check (logging skipped, but request_id still generated)
  app.get('/health').handle((ctx) async {
    return Response.json({'status': 'ok'});
  });

  // Home page
  app.get('/').handle((ctx) {
    ctx.log.info('Home page accessed');
    return Response.text('Welcome to Chase!');
  });

  // Demonstrates log propagation to service layer
  app.get('/users/:id').handle((ctx) async {
    final userId = ctx.req.params['id']!;

    // Service uses Log.named() - request_id is automatically included
    final user = await _userService.findUser(userId);

    return Response.json(user);
  });

  app.post('/users').handle((ctx) async {
    ctx.log.debug('Creating new user');

    try {
      final body = await ctx.req.json() as Map<String, dynamic>?;
      final name = body?['name'] as String?;

      if (name == null || name.isEmpty) {
        ctx.log.warn('Invalid user data', {'reason': 'name is required'});
        return Response.badRequest().json({'error': 'Name is required'});
      }

      final user = await _userService.createUser(name);
      return Response.created().json(user);
    } catch (e, st) {
      ctx.log.error('Failed to create user', {'error': e.toString()}, e, st);
      return Response.internalServerError().json({'error': 'Internal server error'});
    }
  });

  app.get('/error').handle((ctx) {
    try {
      throw Exception('Something went wrong!');
    } catch (e, st) {
      ctx.log.error('Unhandled error occurred', {'path': '/error'}, e, st);
      return Response.internalServerError().json({'error': 'Internal server error'});
    }
  });

  // Start the server
  await app.start(port: 3000);
  log.info('Server started', {'port': 3000, 'pid': pid});

  print('''
Structured Logging Example
==========================

RequestLogger provides all-in-one logging:
  1. Request ID - auto-generated UUID v4, set in X-Request-ID header
  2. Log context - request_id propagated to all log calls via Zone
  3. Request logging - method, path, status, duration_ms

Features demonstrated:
  - ctx.log - Request-scoped logging with automatic request_id
  - Log.named('ClassName') - Named logger with class name
  - log - Top-level logger for quick logging

Endpoints:
  GET  /           - Home page (info log)
  GET  /health     - Health check (logging skipped)
  GET  /users/:id  - Get user (service layer logging)
  POST /users      - Create user (validation logging)
  GET  /error      - Trigger error (error log with stack trace)

Try these commands:
  curl http://localhost:3000/
  curl -v http://localhost:3000/health  # Check X-Request-ID header
  curl http://localhost:3000/users/123
  curl -X POST http://localhost:3000/users -H "Content-Type: application/json" -d '{"name":"Alice"}'
  curl http://localhost:3000/error

Log output includes request_id automatically in all log calls.
''');
}

// =============================================================================
// Service Layer - Uses Log.named('ClassName') for automatic class name tagging
// =============================================================================

final _userService = _UserService();
final _userRepository = _UserRepository();

/// Example service class using Log.named for logging.
///
/// The logger name and request_id are automatically included because
/// RequestLogger wraps the request in a Zone with context fields.
class _UserService {
  static final _log = Log.named('UserService');

  Future<Map<String, dynamic>> findUser(String id) async {
    _log.info('Finding user', {'userId': id});

    final user = await _userRepository.findById(id);

    _log.info('User found', {'userId': id, 'name': user['name']});
    return user;
  }

  Future<Map<String, dynamic>> createUser(String name) async {
    _log.info('Creating user', {'name': name});

    final user = await _userRepository.create(name);

    _log.info('User created', {'userId': user['id'], 'name': name});
    return user;
  }
}

/// Example repository class with its own named logger.
class _UserRepository {
  static final _log = Log.named('UserRepository');

  Future<Map<String, dynamic>> findById(String id) async {
    _log.debug('Querying database', {'table': 'users', 'id': id});

    await Future.delayed(Duration(milliseconds: 30));

    return {'id': id, 'name': 'John Doe', 'email': 'john@example.com'};
  }

  Future<Map<String, dynamic>> create(String name) async {
    _log.debug('Inserting into database', {'table': 'users'});

    await Future.delayed(Duration(milliseconds: 50));

    final id = DateTime.now().millisecondsSinceEpoch;
    return {'id': id, 'name': name};
  }
}
