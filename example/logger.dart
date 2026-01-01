/// Example: Structured Logging
///
/// This example demonstrates the structured logging capabilities of Chase,
/// including Zone-based log context propagation (similar to Java's MDC).
///
/// Run with: dart run example/logger.dart
/// Test with: curl http://localhost:3000/users/123
library;

import 'dart:async';
import 'dart:io';

import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  // Configure the global logger
  // - color: true (default) for colored terminal output
  // - json: true for JSON output (no colors)
  app.logger = DefaultLogger(minLevel: LogLevel.debug, color: true);

  // Application-level logging (outside of request context)
  app.log.info('Application starting', {'version': '1.0.0'});

  // Add request ID middleware for request correlation
  app.use(RequestId());

  // Add LogContext middleware to propagate request_id to all Log calls
  // This enables service classes to use Log.info() with automatic context
  app.use(LogContext());

  // Request logging middleware
  app.use(_RequestLogger());

  // Example routes demonstrating context logging
  app.get('/').handle((ctx) {
    ctx.log.info('Home page accessed');
    ctx.res.text('Welcome to Chase!');
  });

  // Demonstrates Log propagation to service layer
  app.get('/users/:id').handle((ctx) async {
    final userId = ctx.req.params['id']!;

    // Service can use _log.info() and request_id is automatically included
    final user = await _userService.findUser(userId);

    ctx.res.json(user);
  });

  app.post('/users').handle((ctx) async {
    ctx.log.debug('Creating new user');

    try {
      final body = await ctx.req.json() as Map<String, dynamic>?;
      final name = body?['name'] as String?;

      if (name == null || name.isEmpty) {
        ctx.log.warn('Invalid user data', {'reason': 'name is required'});
        ctx.res.statusCode = 400;
        ctx.res.json({'error': 'Name is required'});
        return;
      }

      final user = await _userService.createUser(name);
      ctx.res.statusCode = 201;
      ctx.res.json(user);
    } catch (e, st) {
      ctx.log.error('Failed to create user', {'error': e.toString()}, e, st);
      ctx.res.statusCode = 500;
      ctx.res.json({'error': 'Internal server error'});
    }
  });

  app.get('/error').handle((ctx) {
    try {
      throw Exception('Something went wrong!');
    } catch (e, st) {
      ctx.log.error('Unhandled error occurred', {'path': '/error'}, e, st);
      ctx.res.statusCode = 500;
      ctx.res.json({'error': 'Internal server error'});
    }
  });

  // Start the server
  await app.start(port: 3000);
  app.log.info('Server started', {'port': 3000, 'pid': pid});

  print('''
Structured Logging Example
==========================

Features demonstrated:
  1. ctx.log - Request-scoped logging with automatic request_id
  2. Log.named('ClassName') - Named logger with class name (like Java)
  3. log - Top-level logger for quick logging without class name
  4. LogContext middleware - Propagates request_id to all Log calls via Zone

Endpoints:
  GET  /           - Home page (info log)
  GET  /users/:id  - Get user (service layer logging with _log.info)
  POST /users      - Create user (service layer logging)
  GET  /error      - Trigger error (error log with stack trace)

Try these commands:
  curl http://localhost:3000/
  curl http://localhost:3000/users/123
  curl -X POST http://localhost:3000/users -H "Content-Type: application/json" -d '{"name":"Alice"}'
  curl -X POST http://localhost:3000/users -H "Content-Type: application/json" -d '{}'
  curl http://localhost:3000/error

Log output appears in the console with request_id automatically included.
''');
}

// =============================================================================
// Service Layer - Uses Log.named('ClassName').info() instead of ctx.log
// =============================================================================

final _userService = _UserService();
final _userRepository = _UserRepository();

/// Example service class that uses Log.named for logging.
///
/// The logger name and request_id are automatically included because
/// LogContext middleware wraps the request in a Zone with context fields.
class _UserService {
  // Create a named logger for this class (like Java's LoggerFactory.getLogger)
  static final _log = Log.named('UserService');

  Future<Map<String, dynamic>> findUser(String id) async {
    _log.info('Finding user', {'userId': id});

    // Simulate service logic
    final user = await _userRepository.findById(id);

    _log.info('User found', {'userId': id, 'name': user['name']});
    return user;
  }

  Future<Map<String, dynamic>> createUser(String name) async {
    _log.info('Creating user', {'name': name});

    // Simulate user creation
    final user = await _userRepository.create(name);

    _log.info('User created', {'userId': user['id'], 'name': name});
    return user;
  }
}

/// Example repository class - also uses Log.named for logging.
class _UserRepository {
  static final _log = Log.named('UserRepository');

  Future<Map<String, dynamic>> findById(String id) async {
    _log.debug('Querying database', {'table': 'users', 'id': id});

    // Simulate database lookup
    await Future.delayed(Duration(milliseconds: 30));

    return {'id': id, 'name': 'John Doe', 'email': 'john@example.com'};
  }

  Future<Map<String, dynamic>> create(String name) async {
    _log.debug('Inserting into database', {'table': 'users'});

    // Simulate database insert
    await Future.delayed(Duration(milliseconds: 50));

    final id = DateTime.now().millisecondsSinceEpoch;
    return {'id': id, 'name': name};
  }
}

// =============================================================================
// Middleware
// =============================================================================

/// Simple request logging middleware
class _RequestLogger implements Middleware {
  static final _log = Log.named('RequestLogger');

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final stopwatch = Stopwatch()..start();
    final method = ctx.req.method;
    final path = ctx.req.path;

    _log.debug('Request started', {'method': method, 'path': path});

    await next();

    stopwatch.stop();
    _log.info('Request completed', {
      'method': method,
      'path': path,
      'status': ctx.res.statusCode,
      'duration_ms': stopwatch.elapsedMilliseconds,
    });
  }
}
