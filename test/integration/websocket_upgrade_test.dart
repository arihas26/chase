import 'dart:async';
import 'dart:io';

import 'package:chase/chase.dart';
import 'package:test/test.dart';

void main() {
  group('WebSocket Integration', () {
    late HttpServer server;
    late int port;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      port = server.port;
    });

    tearDown(() async {
      await server.close();
    });

    test('upgrade() successfully creates WebSocket connection', () async {
      // Setup server handler
      server.listen((request) async {
        final ctx = Context(request, request.response);

        try {
          final ws = await ctx.req.upgrade();

          ws.onMessage((message) {
            ws.send('Echo: $message');
          });

          ws.onClose((code, reason) {
            // Connection closed
          });
        } catch (e) {
          // Handle error
        }
      });

      // Connect as client
      final clientWs = await WebSocket.connect('ws://localhost:$port/');

      final completer = Completer<String>();

      clientWs.listen((message) {
        completer.complete(message as String);
      });

      // Send message
      clientWs.add('Hello, Server!');

      // Wait for response
      final response = await completer.future.timeout(Duration(seconds: 2));

      expect(response, equals('Echo: Hello, Server!'));

      await clientWs.close();
    });

    test('WebSocket bidirectional communication', () async {
      server.listen((request) async {
        final ctx = Context(request, request.response);
        final ws = await ctx.req.upgrade();

        var messageCount = 0;

        ws.onMessage((message) {
          messageCount++;
          ws.send('Message #$messageCount received: $message');
        });
      });

      final clientWs = await WebSocket.connect('ws://localhost:$port/');
      final messages = <String>[];

      clientWs.listen((message) {
        messages.add(message as String);
      });

      // Send multiple messages
      clientWs.add('First');
      clientWs.add('Second');
      clientWs.add('Third');

      // Wait for responses
      await Future.delayed(Duration(milliseconds: 100));

      expect(messages, hasLength(3));
      expect(messages[0], contains('Message #1 received: First'));
      expect(messages[1], contains('Message #2 received: Second'));
      expect(messages[2], contains('Message #3 received: Third'));

      await clientWs.close();
    });

    test('WebSocket handles client disconnect', () async {
      final disconnectCompleter = Completer<void>();

      server.listen((request) async {
        final ctx = Context(request, request.response);
        final ws = await ctx.req.upgrade();

        ws.onClose((code, reason) {
          disconnectCompleter.complete();
        });
      });

      final clientWs = await WebSocket.connect('ws://localhost:$port/');

      // Close from client side
      await clientWs.close(1000, 'Client closing');

      // Verify server detected disconnect
      await expectLater(
        disconnectCompleter.future,
        completes,
      );
    });
  });
}
