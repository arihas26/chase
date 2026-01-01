/// Example: Request ID Middleware
///
/// RequestId middleware assigns a unique ID to each request.
/// This is useful for:
/// - Logging and debugging (correlate logs across services)
/// - Distributed tracing (track requests across microservices)
/// - Error reporting (identify specific requests in error reports)
///
/// Run with: dart run example/request_id.dart
/// Test with: curl -v http://localhost:3000/
library;

import 'dart:io';

import 'package:chase/chase.dart';

void main() async {
  final app = Chase();

  // Basic usage - generates UUID v4 request IDs
  app.use(RequestId());

  // Simple endpoint showing request ID
  app.get('/').handle((ctx) async {
    return Response.json({
      'message': 'Hello!',
      'requestId': ctx.requestId,
    });
  });

  // Endpoint that uses request ID for logging
  app.get('/users/:id').handle((ctx) async {
    final userId = ctx.req.params['id']!;
    print('[${ctx.requestId}] Fetching user: $userId');

    // Simulate some processing
    await Future.delayed(Duration(milliseconds: 50));

    print('[${ctx.requestId}] User fetched successfully');
    return Response.json({
      'id': userId,
      'name': 'John Doe',
      'requestId': ctx.requestId,
    });
  });

  // Start the server
  await app.start(port: 3000);
  print('''
Request ID Middleware Example
=============================

The RequestId middleware assigns a unique ID to each request.

Features:
  - UUID v4 generation by default
  - Sets X-Request-Id response header
  - Access via ctx.requestId
  - Can accept incoming request IDs for distributed tracing

Endpoints:
  GET /           - Returns request ID in response
  GET /users/:id  - Shows request ID in logs

Try these commands:
  # Basic request
  curl -v http://localhost:3000/

  # Check X-Request-Id header in response
  curl -i http://localhost:3000/

  # Pass your own request ID (for distributed tracing)
  curl -H "X-Request-Id: my-custom-id-123" http://localhost:3000/

Server running at http://localhost:3000 (pid: $pid)
''');
}

// =============================================================================
// Advanced Configuration Examples (commented out)
// =============================================================================

// Custom header name:
// app.use(RequestId(const RequestIdOptions(
//   headerName: 'X-Correlation-Id',
// )));

// Custom ID generator:
// var counter = 0;
// app.use(RequestId(RequestIdOptions(
//   generator: () => 'req-${++counter}',
// )));

// Disable response header:
// app.use(RequestId(const RequestIdOptions(
//   setResponseHeader: false,
// )));

// Disable using incoming IDs:
// app.use(RequestId(const RequestIdOptions(
//   useIncoming: false,
// )));

// Validate incoming IDs:
// app.use(RequestId(RequestIdOptions(
//   validator: (id) => id.startsWith('valid-'),
// )));

// Using convenience function:
// app.use(requestId(
//   headerName: 'X-Trace-Id',
//   generator: () => 'trace-${DateTime.now().millisecondsSinceEpoch}',
// ));
