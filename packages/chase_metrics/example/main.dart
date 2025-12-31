import 'package:chase/chase.dart';
import 'package:chase_metrics/chase_metrics.dart';

void main() async {
  final app = Chase()
    ..withDefaults()
    ..plugin(MetricsPlugin());

  app.get('/').handle((ctx) => ctx.res.text('Hello, Chase!'));

  app.get('/users/:id').handle((ctx) {
    final id = ctx.req.param<String>('id');
    ctx.res.json({'id': id, 'name': 'User $id'});
  });

  app.post('/users').handle((ctx) async {
    final body = await ctx.req.json();
    ctx.res.json({'created': true, 'data': body});
  });

  // Simulate slow endpoint
  app.get('/slow').handle((ctx) async {
    await Future.delayed(Duration(milliseconds: 500));
    ctx.res.text('Done!');
  });

  await app.start(port: 3000);

  print('''
Test commands:
  curl http://localhost:3000/
  curl http://localhost:3000/users/123
  curl http://localhost:3000/slow
  curl http://localhost:3000/metrics
''');
}
