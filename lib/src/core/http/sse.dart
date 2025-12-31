import 'dart:convert';

import 'package:chase/src/core/http/streaming.dart';

/// Server-Sent Events (SSE) streaming for real-time server-to-client communication.
///
/// SSE provides a standardized way to push updates from the server to the client
/// over HTTP. It's simpler than WebSockets and works well for one-way communication.
///
/// Features:
/// - Automatic reconnection by the browser
/// - Event IDs for message tracking
/// - Custom event types
/// - Retry configuration
/// - Keep-alive comments
///
/// Use cases:
/// - Real-time notifications
/// - Live updates (stock prices, sports scores)
/// - Progress indicators for long-running tasks
/// - Chat applications (server-to-client messages)
/// - Activity feeds
///
/// The SSE format follows the W3C specification:
/// - Each message ends with a blank line (two newlines)
/// - Lines starting with ':' are comments (ignored by client)
/// - Field format: `field: value`
/// - Multi-line data is split into multiple `data:` fields
///
/// Example usage:
/// ```dart
/// // Basic SSE endpoint
/// app.get('/events', (ctx) async {
///   ctx.res.headers.contentType = ContentType('text', 'event-stream');
///   ctx.res.headers.set('cache-control', 'no-cache');
///   ctx.res.headers.set('connection', 'keep-alive');
///
///   final sse = ctx.res.sse();
///
///   // Send events
///   await sse.send('Hello, SSE!');
///   await sse.send({'user': 'Alice', 'message': 'Hi!'});
///   await sse.send('Custom event', event: 'notification');
///
///   await sse.close();
/// });
///
/// // Real-time updates
/// app.get('/stock-prices', (ctx) async {
///   ctx.res.headers.contentType = ContentType('text', 'event-stream');
///
///   final sse = ctx.res.sse();
///
///   var messageId = 0;
///   while (!sse.isClosed) {
///     final price = await fetchStockPrice('AAPL');
///     await sse.send(
///       {'symbol': 'AAPL', 'price': price},
///       event: 'price-update',
///       id: '${messageId++}',
///     );
///     await Future.delayed(Duration(seconds: 5));
///   }
/// });
///
/// // Progress tracking
/// app.get('/process/:id', (ctx) async {
///   ctx.res.headers.contentType = ContentType('text', 'event-stream');
///
///   final sse = ctx.res.sse();
///   final processId = ctx.req.params['id'];
///
///   await sse.send('Started', event: 'status', id: '0');
///
///   for (var i = 0; i <= 100; i += 10) {
///     await sse.send(
///       {'progress': i, 'message': 'Processing...'},
///       event: 'progress',
///       id: '$i',
///     );
///     await Future.delayed(Duration(seconds: 1));
///   }
///
///   await sse.send('Complete', event: 'status', id: '100');
///   await sse.close();
/// });
/// ```
///
/// Client-side JavaScript:
/// ```javascript
/// const eventSource = new EventSource('/events');
///
/// eventSource.onmessage = (event) => {
///   console.log('Message:', event.data);
/// };
///
/// eventSource.addEventListener('notification', (event) => {
///   console.log('Notification:', event.data);
/// });
///
/// eventSource.onerror = (error) => {
///   console.error('SSE error:', error);
/// };
/// ```
class Sse extends Streaming {
  /// Creates a new SSE instance wrapping the given HTTP response.
  ///
  /// Important: Set the correct headers before creating the SSE instance:
  /// ```dart
  /// ctx.res.headers.contentType = ContentType('text', 'event-stream');
  /// ctx.res.headers.set('cache-control', 'no-cache');
  /// ctx.res.headers.set('connection', 'keep-alive');
  /// ```
  Sse(super.response);

  /// Sends an SSE event to the client.
  ///
  /// The [data] can be any type and will be converted to string. If the data
  /// is a Map or List, it will be JSON encoded.
  ///
  /// Optional parameters:
  /// - [event]: Custom event type (default events have no type)
  /// - [id]: Message ID for tracking (enables auto-reconnection from last ID)
  /// - [retry]: Reconnection time in milliseconds
  ///
  /// SSE format:
  /// ```
  /// event: custom-event
  /// id: 123
  /// retry: 5000
  /// data: message content
  /// data: can span multiple lines
  ///
  /// ```
  ///
  /// Example:
  /// ```dart
  /// // Simple message
  /// await sse.send('Hello');
  ///
  /// // JSON data
  /// await sse.send({'user': 'Alice', 'status': 'online'});
  ///
  /// // Custom event with ID
  /// await sse.send('Alert!', event: 'notification', id: '42');
  ///
  /// // Multi-line data
  /// await sse.send('Line 1\nLine 2\nLine 3');
  ///
  /// // Set retry interval
  /// await sse.send('Connection info', retry: 3000);
  /// ```
  Future<void> send(
    dynamic data, {
    String? event,
    String? id,
    int? retry,
  }) async {
    final buffer = StringBuffer();

    // Add optional fields
    if (event != null) {
      buffer.write('event: $event\n');
    }
    if (id != null) {
      buffer.write('id: $id\n');
    }
    if (retry != null) {
      buffer.write('retry: $retry\n');
    }

    // Convert data to string
    String dataString;
    if (data is Map || data is List) {
      dataString = jsonEncode(data);
    } else {
      dataString = data.toString();
    }

    // Split multi-line data into separate data fields
    final dataLines = dataString.split('\n');
    for (final line in dataLines) {
      buffer.write('data: $line\n');
    }

    // End with blank line
    buffer.write('\n');

    await writeBytes(utf8.encode(buffer.toString()));
  }

  /// Sends a comment to keep the connection alive.
  ///
  /// Comments start with ':' and are ignored by the client. They're useful
  /// for keeping the connection alive and preventing timeouts.
  ///
  /// Recommended: Send a comment every 15-30 seconds if no data is being sent.
  ///
  /// Example:
  /// ```dart
  /// // Keep-alive loop
  /// while (!sse.isClosed) {
  ///   if (hasNewData) {
  ///     await sse.send(data);
  ///   } else {
  ///     await sse.comment('keep-alive');
  ///   }
  ///   await Future.delayed(Duration(seconds: 30));
  /// }
  /// ```
  Future<void> comment(String text) async {
    await writeBytes(utf8.encode(': $text\n\n'));
  }
}
