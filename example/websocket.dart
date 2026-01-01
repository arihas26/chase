import 'dart:async';

import 'package:chase/chase.dart';

/// Example: WebSocket communication
///
/// This example demonstrates:
/// - WebSocket upgrade
/// - Bidirectional messaging
/// - Echo server
/// - Chat room functionality
/// - Broadcasting to multiple clients
///
/// Run: dart run bin/example_websocket.dart
/// Test: Open http://localhost:6060 in browser
///       Or use: websocat ws://localhost:6060/echo
void main() async {
  final app = Chase();

  // Store connected chat clients
  final chatClients = <ChaseWebSocket>[];

  // Example 1: Simple echo server
  app.get('/echo').handle((ctx) async {
    final ws = await ctx.req.upgrade();

    print('🔌 Client connected to /echo');

    ws.onMessage((message) {
      print('📨 Received: $message');
      ws.send('Echo: $message');
    });

    ws.onClose((code, reason) {
      print('🔌 Client disconnected from /echo (code: $code, reason: $reason)');
    });

    ws.onError((error) {
      print('❌ WebSocket error: $error');
    });

  });

  // Example 2: Chat room
  app.get('/chat').handle((ctx) async {
    final ws = await ctx.req.upgrade();

    chatClients.add(ws);
    print('👥 Client joined chat (${chatClients.length} online)');

    // Notify others
    _broadcast(chatClients, 'System: New user joined (${chatClients.length} online)', exclude: ws);

    ws.onMessage((message) {
      print('💬 Chat message: $message');
      // Broadcast to all clients
      _broadcast(chatClients, message);
    });

    ws.onClose((code, reason) {
      chatClients.remove(ws);
      print('👥 Client left chat (${chatClients.length} online)');
      _broadcast(chatClients, 'System: User left (${chatClients.length} online)');
    });

    ws.onError((error) {
      print('❌ Chat error: $error');
      chatClients.remove(ws);
    });

  });

  // Example 3: Ping/Pong test
  app.get('/ping').handle((ctx) async {
    final ws = await ctx.req.upgrade();

    print('🏓 Ping/Pong client connected');

    var pingCount = 0;

    // Send ping every 2 seconds
    final timer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (ws.isClosed) {
        timer.cancel();
        return;
      }

      pingCount++;
      ws.ping();
      print('🏓 Ping #$pingCount sent');
    });

    ws.onPong(() {
      print('🏓 Pong received');
    });

    ws.onClose((code, reason) {
      timer.cancel();
      print('🏓 Ping/Pong client disconnected');
    });

  });

  // Example 4: Binary data transfer
  app.get('/binary').handle((ctx) async {
    final ws = await ctx.req.upgrade();

    print('📦 Binary client connected');

    ws.onBinary((data) {
      print('📦 Received ${data.length} bytes');
      // Echo back the binary data
      ws.sendBinary(data);
    });

    ws.onMessage((message) {
      // Send back as binary
      ws.sendBinary(message.codeUnits);
    });

    ws.onClose((code, reason) {
      print('📦 Binary client disconnected');
    });

  });

  // Example 5: Real-time counter
  app.get('/counter').handle((ctx) async {
    final ws = await ctx.req.upgrade();

    print('🔢 Counter client connected');

    var count = 0;
    final timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (ws.isClosed) {
        timer.cancel();
        return;
      }

      count++;
      ws.send('Count: $count');
    });

    ws.onMessage((message) {
      if (message == 'reset') {
        count = 0;
        ws.send('Counter reset');
      }
    });

    ws.onClose((code, reason) {
      timer.cancel();
      print('🔢 Counter client disconnected');
    });

  });

  // Serve HTML client for testing
  app.get('/').handle((ctx) async {
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <title>WebSocket Examples</title>
  <style>
    body { font-family: Arial; max-width: 800px; margin: 50px auto; }
    .section { margin: 20px 0; padding: 20px; background: #f5f5f5; border-radius: 8px; }
    button { padding: 10px 20px; margin: 5px; cursor: pointer; }
    #messages { height: 300px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; background: white; }
    .message { padding: 5px; margin: 5px 0; }
    input { padding: 8px; width: 300px; }
  </style>
</head>
<body>
  <h1>WebSocket Examples</h1>

  <!-- Echo Example -->
  <div class="section">
    <h2>Echo Server</h2>
    <button onclick="connectEcho()">Connect</button>
    <button onclick="disconnectEcho()">Disconnect</button>
    <input id="echoInput" placeholder="Type message..." />
    <button onclick="sendEcho()">Send</button>
    <div id="echoMessages"></div>
  </div>

  <!-- Chat Example -->
  <div class="section">
    <h2>Chat Room</h2>
    <button onclick="connectChat()">Join Chat</button>
    <button onclick="disconnectChat()">Leave Chat</button>
    <input id="chatInput" placeholder="Type message..." />
    <button onclick="sendChat()">Send</button>
    <div id="chatMessages"></div>
  </div>

  <!-- Counter Example -->
  <div class="section">
    <h2>Counter</h2>
    <button onclick="connectCounter()">Start Counter</button>
    <button onclick="resetCounter()">Reset</button>
    <button onclick="disconnectCounter()">Stop</button>
    <div id="counterDisplay" style="font-size: 24px; font-weight: bold;"></div>
  </div>

  <script>
    let echoWs = null;
    let chatWs = null;
    let counterWs = null;

    function addMessage(elementId, message, type = 'message') {
      const div = document.createElement('div');
      div.className = 'message';
      div.textContent = new Date().toLocaleTimeString() + ' - ' + message;
      div.style.color = type === 'error' ? 'red' : type === 'system' ? 'blue' : 'black';
      document.getElementById(elementId).prepend(div);
    }

    // Echo
    function connectEcho() {
      if (echoWs) return;
      echoWs = new WebSocket('ws://' + location.host + '/echo');
      echoWs.onopen = () => addMessage('echoMessages', 'Connected', 'system');
      echoWs.onmessage = (e) => addMessage('echoMessages', e.data);
      echoWs.onerror = () => addMessage('echoMessages', 'Error', 'error');
      echoWs.onclose = () => {
        addMessage('echoMessages', 'Disconnected', 'system');
        echoWs = null;
      };
    }

    function disconnectEcho() {
      if (echoWs) {
        echoWs.close();
        echoWs = null;
      }
    }

    function sendEcho() {
      const input = document.getElementById('echoInput');
      if (echoWs && input.value) {
        echoWs.send(input.value);
        input.value = '';
      }
    }

    // Chat
    function connectChat() {
      if (chatWs) return;
      chatWs = new WebSocket('ws://' + location.host + '/chat');
      chatWs.onopen = () => addMessage('chatMessages', 'Joined chat', 'system');
      chatWs.onmessage = (e) => addMessage('chatMessages', e.data);
      chatWs.onerror = () => addMessage('chatMessages', 'Error', 'error');
      chatWs.onclose = () => {
        addMessage('chatMessages', 'Left chat', 'system');
        chatWs = null;
      };
    }

    function disconnectChat() {
      if (chatWs) {
        chatWs.close();
        chatWs = null;
      }
    }

    function sendChat() {
      const input = document.getElementById('chatInput');
      if (chatWs && input.value) {
        chatWs.send(input.value);
        input.value = '';
      }
    }

    // Counter
    function connectCounter() {
      if (counterWs) return;
      counterWs = new WebSocket('ws://' + location.host + '/counter');
      counterWs.onopen = () => {
        document.getElementById('counterDisplay').textContent = 'Starting...';
      };
      counterWs.onmessage = (e) => {
        document.getElementById('counterDisplay').textContent = e.data;
      };
      counterWs.onclose = () => {
        document.getElementById('counterDisplay').textContent = 'Disconnected';
        counterWs = null;
      };
    }

    function resetCounter() {
      if (counterWs) {
        counterWs.send('reset');
      }
    }

    function disconnectCounter() {
      if (counterWs) {
        counterWs.close();
        counterWs = null;
      }
    }

    // Enter key support
    document.getElementById('echoInput').addEventListener('keypress', (e) => {
      if (e.key === 'Enter') sendEcho();
    });
    document.getElementById('chatInput').addEventListener('keypress', (e) => {
      if (e.key === 'Enter') sendChat();
    });
  </script>
</body>
</html>
''';

    await ctx.res.html(html);
  });

  final port = 3002;
  print('🚀 WebSocket server running on http://localhost:$port');
  print('');
  print('Open http://localhost:$port in your browser');
  print('Or try these endpoints:');
  print('  websocat ws://localhost:$port/echo');
  print('  websocat ws://localhost:$port/chat');
  print('  websocat ws://localhost:$port/ping');
  print('  websocat ws://localhost:$port/binary');
  print('  websocat ws://localhost:$port/counter');

  await app.start(port: port);
}

/// Broadcasts a message to all connected clients
void _broadcast(List<ChaseWebSocket> clients, String message, {ChaseWebSocket? exclude}) {
  for (final client in List.from(clients)) {
    if (client != exclude && !client.isClosed) {
      try {
        client.send(message);
      } catch (e) {
        print('❌ Failed to send to client: $e');
      }
    }
  }
}
