/// Example: Server-Sent Events (SSE) - Hono-style API
///
/// This example demonstrates:
/// - Real-time server-to-client updates
/// - Custom event types
/// - Event IDs for reconnection
/// - Keep-alive comments
///
/// Run: dart run example/sse.dart
/// Test: curl http://localhost:3001/events
///       Open http://localhost:3001 in browser
library;

import 'dart:math';

import 'package:chase/chase.dart';

void main() async {
  final app = Chase();
  final random = Random();

  // Example 1: Basic SSE with periodic updates
  app.get('/events').handle((ctx) {
    return streamSSE(ctx, (sse) async {
      sse.onAbort(() {
        print('Client disconnected from /events');
      });

      print('Client connected to /events');

      // Send initial connection event
      await sse.writeSSE(
        data: 'Connected to event stream',
        event: 'connection',
        id: '0',
      );

      // Send periodic updates
      for (var i = 1; i <= 10; i++) {
        if (sse.isClosed) break;

        await sse.writeSSE(
          data: 'Update #$i at ${DateTime.now().toIso8601String()}',
          event: 'update',
          id: '$i',
        );

        await sse.sleep(Duration(seconds: 2));
      }

      await sse.writeSSE(
        data: 'Stream complete',
        event: 'done',
        id: '11',
      );
    });
  });

  // Example 2: Real-time stock prices
  app.get('/stocks').handle((ctx) {
    return streamSSE(ctx, (sse) async {
      print('Client connected to /stocks');

      final stocks = ['AAPL', 'GOOGL', 'MSFT', 'AMZN'];
      var messageId = 0;

      // Simulate stock price updates
      while (!sse.isClosed) {
        for (final symbol in stocks) {
          if (sse.isClosed) break;

          final price = 100 + random.nextDouble() * 50;
          final change = (random.nextDouble() - 0.5) * 5;

          final data =
              '{"symbol":"$symbol","price":"${price.toStringAsFixed(2)}","change":"${change.toStringAsFixed(2)}","timestamp":"${DateTime.now().toIso8601String()}"}';

          await sse.writeSSE(
            data: data,
            event: 'price-update',
            id: '${messageId++}',
          );
        }

        await sse.sleep(Duration(seconds: 3));

        // Send keep-alive comment every 10 messages
        if (messageId % 10 == 0) {
          await sse.writeComment('keep-alive');
        }
      }
    });
  });

  // Example 3: Progress tracking
  app.get('/progress/:taskId').handle((ctx) {
    final taskId = ctx.req.param('taskId') ?? 'unknown';

    return streamSSE(ctx, (sse) async {
      print('Starting task $taskId');

      await sse.writeSSE(
        data: 'Task started',
        event: 'status',
        id: '0',
      );

      // Simulate progress
      for (var progress = 0; progress <= 100; progress += 10) {
        if (sse.isClosed) break;

        final data =
            '{"taskId":"$taskId","progress":$progress,"message":"${progress == 100 ? 'Complete!' : 'Processing...'}"}';

        await sse.writeSSE(
          data: data,
          event: 'progress',
          id: '$progress',
        );

        await sse.sleep(Duration(milliseconds: 500));
      }

      await sse.writeSSE(
        data: 'Task completed',
        event: 'status',
        id: '100',
      );
    });
  });

  // Example 4: Real-time notifications
  app.get('/notifications').handle((ctx) {
    return streamSSE(ctx, (sse) async {
      print('Client connected to /notifications');

      final notifications = [
        '{"type":"info","message":"New feature available"}',
        '{"type":"warning","message":"Scheduled maintenance in 1 hour"}',
        '{"type":"success","message":"Profile updated successfully"}',
        '{"type":"error","message":"Failed to sync data"}',
      ];

      var id = 0;

      for (final notification in notifications) {
        if (sse.isClosed) break;

        await sse.writeSSE(
          data: notification,
          event: 'notification',
          id: '${id++}',
        );

        await sse.sleep(Duration(seconds: 3));
      }

      // Keep connection alive for continuous notifications
      while (!sse.isClosed) {
        await sse.sleep(Duration(seconds: 30));
        await sse.writeComment('keep-alive');
      }
    });
  });

  // Example 5: Live server metrics
  app.get('/metrics').handle((ctx) {
    return streamSSE(ctx, (sse) async {
      print('Client connected to /metrics');

      var messageId = 0;

      while (!sse.isClosed) {
        final metrics =
            '{"cpu":"${(random.nextDouble() * 100).toStringAsFixed(1)}","memory":"${(random.nextDouble() * 100).toStringAsFixed(1)}","requests":${random.nextInt(1000)},"timestamp":"${DateTime.now().toIso8601String()}"}';

        await sse.writeSSE(
          data: metrics,
          event: 'metrics',
          id: '${messageId++}',
        );

        await sse.sleep(Duration(seconds: 1));
      }
    });
  });

  // Serve HTML client for testing
  app.get('/').handle((ctx) {
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <title>SSE Example</title>
  <style>
    body { font-family: Arial; max-width: 800px; margin: 50px auto; }
    .event { padding: 10px; margin: 5px 0; background: #f0f0f0; border-radius: 4px; }
    .connection { background: #d4edda; }
    .update { background: #d1ecf1; }
    .error { background: #f8d7da; }
    button { padding: 10px 20px; margin: 10px 5px; cursor: pointer; }
  </style>
</head>
<body>
  <h1>Server-Sent Events Demo</h1>
  <div>
    <button onclick="connectEvents()">Connect to Events</button>
    <button onclick="connectStocks()">Stock Prices</button>
    <button onclick="connectNotifications()">Notifications</button>
    <button onclick="disconnect()">Disconnect</button>
  </div>
  <div id="output"></div>

  <script>
    let eventSource = null;

    function addEvent(type, data) {
      const div = document.createElement('div');
      div.className = 'event ' + type;
      div.textContent = new Date().toLocaleTimeString() + ' - ' + data;
      document.getElementById('output').prepend(div);
    }

    function disconnect() {
      if (eventSource) {
        eventSource.close();
        eventSource = null;
        addEvent('connection', 'Disconnected');
      }
    }

    function connectEvents() {
      disconnect();
      eventSource = new EventSource('/events');

      eventSource.addEventListener('connection', (e) => {
        addEvent('connection', e.data);
      });

      eventSource.addEventListener('update', (e) => {
        addEvent('update', e.data);
      });

      eventSource.onerror = () => {
        addEvent('error', 'Connection error');
      };
    }

    function connectStocks() {
      disconnect();
      eventSource = new EventSource('/stocks');

      eventSource.addEventListener('price-update', (e) => {
        const data = JSON.parse(e.data);
        addEvent('update', data.symbol + ': \$' + data.price + ' (' + data.change + ')');
      });
    }

    function connectNotifications() {
      disconnect();
      eventSource = new EventSource('/notifications');

      eventSource.addEventListener('notification', (e) => {
        const data = JSON.parse(e.data);
        addEvent(data.type, data.message);
      });
    }
  </script>
</body>
</html>
''';

    return Response.ok().html(htmlContent);
  });

  final port = 3001;
  print('SSE server running on http://localhost:$port');
  print('');
  print('Open http://localhost:$port in your browser');
  print('Or try these endpoints:');
  print('  curl http://localhost:$port/events');
  print('  curl http://localhost:$port/stocks');
  print('  curl http://localhost:$port/progress/task-123');
  print('  curl http://localhost:$port/notifications');
  print('  curl http://localhost:$port/metrics');

  await app.start(port: port);
}
