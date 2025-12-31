import 'dart:convert';

import 'package:chase/src/core/http/streaming.dart';

/// Text streaming for sending text data to the client.
///
/// This class extends [Streaming] to provide convenient methods for streaming
/// text content. It automatically handles UTF-8 encoding.
///
/// Use cases:
/// - Server-Sent Events (SSE)
/// - Real-time logs streaming
/// - Progressive HTML rendering
/// - Chat applications
/// - Command output streaming
///
/// All text is encoded as UTF-8 before being sent to the client.
///
/// Example usage:
/// ```dart
/// // Stream text with newlines
/// app.get('/logs', (ctx) async {
///   ctx.res.headers.contentType = ContentType.text;
///
///   final streaming = ctx.res.textStream();
///
///   await streaming.writeln('Log started');
///   await streaming.writeln('Processing...');
///   await streaming.writeln('Complete!');
///
///   await streaming.close();
/// });
///
/// // Stream progressive content
/// app.get('/story', (ctx) async {
///   final streaming = ctx.res.textStream();
///
///   final words = 'Once upon a time in a land far away'.split(' ');
///   for (final word in words) {
///     await streaming.write('$word ');
///     await Future.delayed(Duration(milliseconds: 200));
///   }
///
///   await streaming.close();
/// });
///
/// // Stream JSON objects (NDJSON format)
/// app.get('/events', (ctx) async {
///   final streaming = ctx.res.textStream();
///
///   for (var i = 0; i < 10; i++) {
///     final json = jsonEncode({'event': i, 'timestamp': DateTime.now().toIso8601String()});
///     await streaming.writeln(json);
///     await Future.delayed(Duration(seconds: 1));
///   }
///
///   await streaming.close();
/// });
/// ```
class TextStreaming extends Streaming {
  /// Creates a new TextStreaming instance wrapping the given HTTP response.
  TextStreaming(super.response);

  /// Writes text to the stream.
  ///
  /// The text is encoded as UTF-8 and sent to the client immediately.
  ///
  /// Example:
  /// ```dart
  /// await streaming.write('Hello, ');
  /// await streaming.write('world!');
  /// ```
  Future<void> write(String text) async {
    await writeBytes(utf8.encode(text));
  }

  /// Writes text followed by a newline to the stream.
  ///
  /// This is equivalent to calling `write('$text\n')`.
  ///
  /// Example:
  /// ```dart
  /// await streaming.writeln('First line');
  /// await streaming.writeln('Second line');
  /// ```
  Future<void> writeln(String text) async {
    await write('$text\n');
  }
}
