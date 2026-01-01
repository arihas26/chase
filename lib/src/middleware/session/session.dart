import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/context/cookie.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:zlogger/zlogger.dart';

/// Session data container.
class SessionData {
  final String id;
  final Map<String, dynamic> _data;
  DateTime _lastAccess;
  bool _isNew;
  bool _isModified;

  SessionData._(this.id, Map<String, dynamic> data, this._lastAccess)
      : _data = data,
        _isNew = false,
        _isModified = false;

  /// Creates a new session with the given ID.
  factory SessionData.create(String id) {
    final session = SessionData._(id, {}, DateTime.now());
    session._isNew = true;
    return session;
  }

  /// Creates a session from stored data.
  factory SessionData.fromStore(String id, Map<String, dynamic> data, DateTime lastAccess) {
    return SessionData._(id, Map<String, dynamic>.from(data), lastAccess);
  }

  /// Whether this is a newly created session.
  bool get isNew => _isNew;

  /// Whether the session data has been modified.
  bool get isModified => _isModified;

  /// Last access time.
  DateTime get lastAccess => _lastAccess;

  /// Updates the last access time.
  void touch() {
    _lastAccess = DateTime.now();
  }

  /// Gets a value from the session.
  ///
  /// In debug mode, an assertion will fail if the key exists but
  /// the type doesn't match, helping to catch type mismatches early.
  T? get<T>(String key) {
    final value = _data[key];
    assert(
      value == null || value is T,
      'Session type mismatch: key "$key" has type ${value.runtimeType}, '
      'but expected $T',
    );
    return value is T ? value : null;
  }

  /// Sets a value in the session.
  void set<T>(String key, T value) {
    _data[key] = value;
    _isModified = true;
  }

  /// Removes a value from the session.
  void remove(String key) {
    if (_data.containsKey(key)) {
      _data.remove(key);
      _isModified = true;
    }
  }

  /// Checks if a key exists in the session.
  bool has(String key) => _data.containsKey(key);

  /// Clears all session data.
  void clear() {
    if (_data.isNotEmpty) {
      _data.clear();
      _isModified = true;
    }
  }

  /// Gets all session data as a map.
  Map<String, dynamic> get data => Map<String, dynamic>.unmodifiable(_data);

  /// Gets the raw data map for storage.
  Map<String, dynamic> get rawData => _data;
}

/// Interface for session storage backends.
abstract class SessionStore {
  /// Gets session data by ID.
  FutureOr<SessionData?> get(String id);

  /// Saves session data.
  FutureOr<void> set(String id, SessionData session);

  /// Deletes a session.
  FutureOr<void> delete(String id);

  /// Cleans up expired sessions.
  FutureOr<void> cleanup(Duration maxAge);

  /// Disposes of the store resources.
  FutureOr<void> dispose();
}

/// In-memory session store.
///
/// Suitable for development and single-instance deployments.
/// For production with multiple instances, use a distributed store.
class MemorySessionStore implements SessionStore {
  final Map<String, _StoredSession> _sessions = {};
  Timer? _cleanupTimer;

  /// Creates a memory store with optional auto-cleanup.
  MemorySessionStore({Duration? cleanupInterval}) {
    if (cleanupInterval != null) {
      _cleanupTimer = Timer.periodic(cleanupInterval, (_) {
        cleanup(const Duration(hours: 24));
      });
    }
  }

  @override
  SessionData? get(String id) {
    final stored = _sessions[id];
    if (stored == null) return null;

    return SessionData.fromStore(id, stored.data, stored.lastAccess);
  }

  @override
  void set(String id, SessionData session) {
    _sessions[id] = _StoredSession(
      data: Map<String, dynamic>.from(session.rawData),
      lastAccess: session.lastAccess,
    );
  }

  @override
  void delete(String id) {
    _sessions.remove(id);
  }

  @override
  void cleanup(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    _sessions.removeWhere((_, stored) => stored.lastAccess.isBefore(cutoff));
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _sessions.clear();
  }

  /// Gets the number of active sessions.
  int get length => _sessions.length;
}

class _StoredSession {
  final Map<String, dynamic> data;
  final DateTime lastAccess;

  _StoredSession({required this.data, required this.lastAccess});
}

/// Options for configuring session management.
class SessionOptions {
  /// Cookie name for the session ID.
  ///
  /// Default: 'session_id'
  final String cookieName;

  /// Session timeout duration.
  ///
  /// Sessions that haven't been accessed within this duration
  /// may be cleaned up by the store.
  ///
  /// Default: 24 hours
  final Duration maxAge;

  /// Cookie path.
  ///
  /// Default: '/'
  final String? cookiePath;

  /// Cookie domain.
  final String? cookieDomain;

  /// Whether the cookie is HTTP-only.
  ///
  /// Default: true
  final bool cookieHttpOnly;

  /// Whether the cookie requires HTTPS.
  ///
  /// Default: false
  final bool cookieSecure;

  /// SameSite attribute for the cookie.
  ///
  /// Default: SameSite.lax
  final SameSite? cookieSameSite;

  /// Whether to regenerate the session ID on each request.
  ///
  /// Enable for enhanced security, but may cause issues with
  /// concurrent requests from the same client.
  ///
  /// Default: false
  final bool rolling;

  /// Whether to save the session even if not modified.
  ///
  /// Default: false
  final bool saveUnmodified;

  /// Custom session ID generator.
  ///
  /// If null, uses a secure random generator.
  final String Function()? idGenerator;

  /// Creates session options with the specified configuration.
  const SessionOptions({
    this.cookieName = 'session_id',
    this.maxAge = const Duration(hours: 24),
    this.cookiePath = '/',
    this.cookieDomain,
    this.cookieHttpOnly = true,
    this.cookieSecure = false,
    this.cookieSameSite = SameSite.lax,
    this.rolling = false,
    this.saveUnmodified = false,
    this.idGenerator,
  });

  /// Creates options for secure sessions (HTTPS only).
  const SessionOptions.secure({
    this.cookieName = 'session_id',
    this.maxAge = const Duration(hours: 24),
    this.cookiePath = '/',
    this.cookieDomain,
    this.rolling = false,
    this.saveUnmodified = false,
    this.idGenerator,
  })  : cookieHttpOnly = true,
        cookieSecure = true,
        cookieSameSite = SameSite.strict;

  /// Creates options for short-lived sessions.
  const SessionOptions.shortLived({
    this.cookieName = 'session_id',
    this.cookiePath = '/',
    this.cookieDomain,
    this.rolling = true,
    this.saveUnmodified = false,
    this.idGenerator,
  })  : maxAge = const Duration(minutes: 30),
        cookieHttpOnly = true,
        cookieSecure = false,
        cookieSameSite = SameSite.lax;
}

/// Middleware that provides session management.
///
/// This middleware manages user sessions using cookies and a storage backend.
/// Sessions can store arbitrary data that persists across requests.
///
/// Features:
/// - Cookie-based session identification
/// - Pluggable storage backends (memory, Redis, etc.)
/// - Automatic session creation
/// - Session expiration
/// - Secure cookie options
///
/// Example usage:
/// ```dart
/// // Basic usage with in-memory store
/// final store = MemorySessionStore();
/// app.use(Session(store));
///
/// // Access session in handlers
/// app.get('/profile').handle((ctx) async {
///   final userId = ctx.session.get<int>('userId');
///   if (userId == null) {
///     await ctx.res.redirect('/login');
///   }
///   await ctx.res.json({'userId': userId});
/// });
///
/// // Set session data
/// app.post('/login').handle((ctx) async {
///   final body = await ctx.req.json();
///   // ... validate credentials ...
///   ctx.session.set('userId', user.id);
///   ctx.session.set('username', user.name);
///   await ctx.res.json({'success': true});
/// });
///
/// // Clear session (logout)
/// app.post('/logout').handle((ctx) async {
///   ctx.session.clear();
///   await ctx.res.json({'success': true});
/// });
///
/// // Secure session for production
/// app.use(Session(
///   store,
///   const SessionOptions.secure(),
/// ));
///
/// // Short-lived session with rolling expiration
/// app.use(Session(
///   store,
///   const SessionOptions.shortLived(),
/// ));
/// ```
///
/// The session is accessible via `ctx.session` after this middleware runs.
class Session implements Middleware {
  static final _log = Log.named('Session');

  final SessionStore store;
  final SessionOptions options;
  final String Function() _generateId;

  /// Creates a Session middleware with the given [store] and [options].
  Session(
    this.store, [
    this.options = const SessionOptions(),
  ]) : _generateId = options.idGenerator ?? _defaultIdGenerator;

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    // Get or create session
    final sessionId = _getSessionId(ctx);
    SessionData session;

    if (sessionId != null) {
      final stored = await store.get(sessionId);
      if (stored != null) {
        session = stored;
        session.touch();
      } else {
        // Session ID exists but not in store (expired or invalid)
        _log.debug(
          'Session not found in store, creating new',
          {
            'method': ctx.req.method,
            'path': ctx.req.path,
          },
        );
        session = SessionData.create(_generateId());
      }
    } else {
      // No session ID, create new
      session = SessionData.create(_generateId());
    }

    // Store session in context
    ctx.set('_session', session);

    // Process request
    final result = await next();

    // Save session if needed
    final currentSession = ctx.get<SessionData>('_session');
    if (currentSession != null) {
      final shouldSave = currentSession.isModified ||
          options.saveUnmodified ||
          currentSession.isNew ||
          options.rolling;

      if (shouldSave) {
        await store.set(currentSession.id, currentSession);
      }

      // Set cookie if new session or rolling
      if (currentSession.isNew || options.rolling) {
        _setSessionCookie(ctx, currentSession.id);
      }
    }

    return result;
  }

  /// Gets the session ID from the request cookie.
  String? _getSessionId(Context ctx) {
    return ctx.req.cookie(options.cookieName);
  }

  /// Sets the session cookie.
  void _setSessionCookie(Context ctx, String sessionId) {
    ctx.res.cookie(
      options.cookieName,
      sessionId,
      maxAge: options.maxAge,
      path: options.cookiePath,
      domain: options.cookieDomain,
      httpOnly: options.cookieHttpOnly,
      secure: options.cookieSecure,
      sameSite: options.cookieSameSite,
    );
  }

  /// Default session ID generator using secure random.
  static String _defaultIdGenerator() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

/// Extension on Context for session access.
extension SessionContextExtension on Context {
  /// Gets the current session.
  ///
  /// Throws if session middleware is not configured.
  SessionData get session {
    final s = get<SessionData>('_session');
    if (s == null) {
      throw StateError('Session not available. Did you add the Session middleware?');
    }
    return s;
  }

  /// Gets the current session or null if not available.
  SessionData? get sessionOrNull => get<SessionData>('_session');

  /// Destroys the current session.
  ///
  /// Creates a new empty session with a new ID.
  void destroySession() {
    final newSession = SessionData.create(Session._defaultIdGenerator());
    set('_session', newSession);
  }

  /// Regenerates the session ID while preserving data.
  ///
  /// Use this after login to prevent session fixation attacks.
  void regenerateSession() {
    final current = sessionOrNull;
    if (current == null) return;

    final newSession = SessionData.create(Session._defaultIdGenerator());
    for (final entry in current.data.entries) {
      newSession.set(entry.key, entry.value);
    }
    set('_session', newSession);
  }
}
