import 'dart:convert';
import 'dart:io';

/// Log level for filtering log output.
enum LogLevel {
  /// Detailed debugging information.
  debug,

  /// General information.
  info,

  /// Warning conditions.
  warn,

  /// Error conditions.
  error,
}

/// A structured log entry.
class LogRecord {
  /// Timestamp when the log was created.
  final DateTime timestamp;

  /// Log level.
  final LogLevel level;

  /// Log message.
  final String message;

  /// Additional fields.
  final Map<String, dynamic> fields;

  /// Error object if present.
  final Object? error;

  /// Stack trace if present.
  final StackTrace? stackTrace;

  const LogRecord({
    required this.timestamp,
    required this.level,
    required this.message,
    this.fields = const {},
    this.error,
    this.stackTrace,
  });

  /// Converts to JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'time': timestamp.toIso8601String(),
      'level': level.name,
      'msg': message,
      ...fields,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString(),
    };
  }
}

/// Handler for log records.
typedef LogHandler = void Function(LogRecord record);

/// Abstract logger interface.
abstract class ChaseLogger {
  /// Logs a debug message.
  void debug(String message, [Map<String, dynamic>? fields]);

  /// Logs an info message.
  void info(String message, [Map<String, dynamic>? fields]);

  /// Logs a warning message.
  void warn(String message, [Map<String, dynamic>? fields]);

  /// Logs an error message.
  void error(String message, [Map<String, dynamic>? fields, Object? err, StackTrace? stackTrace]);

  /// Creates a child logger with additional default fields.
  ChaseLogger withFields(Map<String, dynamic> fields);
}

/// Default logger implementation.
class DefaultLogger implements ChaseLogger {
  /// Minimum log level to output.
  final LogLevel minLevel;

  /// Output as JSON (true) or text (false).
  final bool json;

  /// Custom log handler. If null, outputs to stdout/stderr.
  final LogHandler? handler;

  /// Default fields to include in every log.
  final Map<String, dynamic> _defaultFields;

  /// Creates a default logger.
  const DefaultLogger({
    this.minLevel = LogLevel.debug,
    this.json = false,
    this.handler,
    Map<String, dynamic> defaultFields = const {},
  }) : _defaultFields = defaultFields;

  @override
  void debug(String message, [Map<String, dynamic>? fields]) {
    _log(LogLevel.debug, message, fields);
  }

  @override
  void info(String message, [Map<String, dynamic>? fields]) {
    _log(LogLevel.info, message, fields);
  }

  @override
  void warn(String message, [Map<String, dynamic>? fields]) {
    _log(LogLevel.warn, message, fields);
  }

  @override
  void error(String message, [Map<String, dynamic>? fields, Object? err, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, fields, err, stackTrace);
  }

  @override
  ChaseLogger withFields(Map<String, dynamic> fields) {
    return DefaultLogger(
      minLevel: minLevel,
      json: json,
      handler: handler,
      defaultFields: {..._defaultFields, ...fields},
    );
  }

  void _log(LogLevel level, String message, [Map<String, dynamic>? fields, Object? err, StackTrace? stackTrace]) {
    if (level.index < minLevel.index) return;

    final record = LogRecord(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      fields: {..._defaultFields, ...?fields},
      error: err,
      stackTrace: stackTrace,
    );

    if (handler != null) {
      handler!(record);
    } else {
      _defaultOutput(record);
    }
  }

  void _defaultOutput(LogRecord record) {
    final output = record.level.index >= LogLevel.warn.index ? stderr : stdout;
    final text = json ? jsonEncode(record.toJson()) : _formatText(record);
    output.writeln(text);
  }

  String _formatText(LogRecord record) {
    final buffer = StringBuffer();
    buffer.write('${record.timestamp.toIso8601String()} ');
    buffer.write('[${record.level.name.toUpperCase().padRight(5)}] ');
    buffer.write(record.message);

    if (record.fields.isNotEmpty) {
      final fieldsStr = record.fields.entries
          .map((e) => '${e.key}=${e.value}')
          .join(' ');
      buffer.write(' $fieldsStr');
    }

    if (record.error != null) {
      buffer.write(' error=${record.error}');
    }

    return buffer.toString();
  }
}

/// A silent logger that does nothing.
class NullLogger implements ChaseLogger {
  const NullLogger();

  @override
  void debug(String message, [Map<String, dynamic>? fields]) {}

  @override
  void info(String message, [Map<String, dynamic>? fields]) {}

  @override
  void warn(String message, [Map<String, dynamic>? fields]) {}

  @override
  void error(String message, [Map<String, dynamic>? fields, Object? err, StackTrace? stackTrace]) {}

  @override
  ChaseLogger withFields(Map<String, dynamic> fields) => this;
}

/// Global logger instance used by Chase.
///
/// This can be configured via [Chase.logger] or [ChaseLoggerConfig.global].
ChaseLogger _globalLogger = const DefaultLogger();

/// Configuration for the global logger.
class ChaseLoggerConfig {
  ChaseLoggerConfig._();

  /// Gets the global logger instance.
  static ChaseLogger get global => _globalLogger;

  /// Sets the global logger instance.
  static set global(ChaseLogger logger) => _globalLogger = logger;
}
