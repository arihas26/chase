import 'dart:async';
import 'package:chase/chase.dart';

/// Chase benchmark server
///
/// Endpoints:
/// - GET /              : Plain text response
/// - GET /json          : JSON response
/// - GET /user/:id      : Route parameter
/// - POST /echo         : Echo JSON body
/// - GET /query         : Query parameters
/// - GET /large         : Large JSON response
/// - GET /middleware    : Multiple middleware chain
void main() async {
  final app = Chase();

  // Plain text
  app.get('/').handle((ctx) => 'Hello, World!');

  // JSON response
  app.get('/json').handle((ctx) {
    return {'message': 'Hello, World!', 'framework': 'chase'};
  });

  // Route parameter
  app.get('/user/:id').handle((ctx) {
    final id = ctx.req.params['id'];
    return {'id': id, 'name': 'User $id'};
  });

  // Echo JSON body
  app.post('/echo').handle((ctx) async {
    final body = await ctx.req.json();
    return body;
  });

  // Query parameters
  app.get('/query').handle((ctx) {
    final name = ctx.req.query('name') ?? 'anonymous';
    final age = ctx.req.query('age') ?? '0';
    return {'name': name, 'age': age};
  });

  // Large JSON response
  app.get('/large').handle((ctx) {
    return {
      'items': List.generate(
        100,
        (i) => {
          'id': i,
          'name': 'Item $i',
          'description': 'This is a description for item $i',
          'price': i * 10.5,
          'inStock': i % 2 == 0,
        },
      ),
    };
  });

  // Middleware chain
  app
      .get('/middleware')
      .use(_TimingMiddleware())
      .use(_CounterMiddleware())
      .use(_HeaderMiddleware())
      .handle((ctx) => {'processed': true});

  await app.start(port: 3000);
  print('Chase server running on http://localhost:3000');
}

class _TimingMiddleware implements Middleware {
  @override
  FutureOr<dynamic> handle(Context ctx, NextFunction next) async {
    ctx.set('start', DateTime.now().microsecondsSinceEpoch);
    return await next();
  }
}

class _CounterMiddleware implements Middleware {
  int _count = 0;

  @override
  FutureOr<dynamic> handle(Context ctx, NextFunction next) async {
    _count++;
    ctx.set('count', _count);
    return await next();
  }
}

class _HeaderMiddleware implements Middleware {
  @override
  FutureOr<dynamic> handle(Context ctx, NextFunction next) async {
    ctx.res.headers.set('X-Benchmark', 'chase');
    return await next();
  }
}
