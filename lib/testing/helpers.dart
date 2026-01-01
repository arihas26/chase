/// Testing helpers for Chase framework.
///
/// Provides convenient helpers for building test requests and assertions.
///
/// Example:
/// ```dart
/// import 'package:chase/testing/testing.dart';
///
/// test('authenticated request', () async {
///   final res = await client.get(
///     '/protected',
///     headers: AuthHelper.bearer('my-token'),
///   );
///   expect(res.status, 200);
/// });
/// ```
library;

import 'dart:convert';

import 'package:test/test.dart';

import 'testing.dart';

// -----------------------------------------------------------------------------
// Auth Helpers
// -----------------------------------------------------------------------------

/// Helpers for authentication in tests.
class AuthHelper {
  AuthHelper._();

  /// Creates a Bearer token authorization header.
  ///
  /// Example:
  /// ```dart
  /// final res = await client.get(
  ///   '/api/users',
  ///   headers: AuthHelper.bearer('jwt-token-here'),
  /// );
  /// ```
  static Map<String, String> bearer(String token) => {
    'authorization': 'Bearer $token',
  };

  /// Creates a Basic authentication header.
  ///
  /// Example:
  /// ```dart
  /// final res = await client.get(
  ///   '/admin',
  ///   headers: AuthHelper.basic('admin', 'password'),
  /// );
  /// ```
  static Map<String, String> basic(String username, String password) {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return {'authorization': 'Basic $credentials'};
  }

  /// Creates a custom authorization header.
  ///
  /// Example:
  /// ```dart
  /// final res = await client.get(
  ///   '/api',
  ///   headers: AuthHelper.custom('ApiKey', 'my-api-key'),
  /// );
  /// ```
  static Map<String, String> custom(String scheme, String credentials) => {
    'authorization': '$scheme $credentials',
  };
}

// -----------------------------------------------------------------------------
// Request Helpers
// -----------------------------------------------------------------------------

/// Helpers for building test requests.
class RequestHelper {
  RequestHelper._();

  /// Creates JSON content-type header.
  static const Map<String, String> jsonHeaders = {
    'content-type': 'application/json',
  };

  /// Creates form content-type header.
  static const Map<String, String> formHeaders = {
    'content-type': 'application/x-www-form-urlencoded',
  };

  /// Merges multiple header maps into one.
  ///
  /// Example:
  /// ```dart
  /// final res = await client.post(
  ///   '/api/users',
  ///   headers: RequestHelper.mergeHeaders(
  ///     RequestHelper.jsonHeaders,
  ///     AuthHelper.bearer(token),
  ///     {'x-custom': 'value'},
  ///   ),
  ///   body: jsonEncode({'name': 'John'}),
  /// );
  /// ```
  static Map<String, String> mergeHeaders(
    Map<String, String> first, [
    Map<String, String>? second,
    Map<String, String>? third,
    Map<String, String>? fourth,
  ]) {
    return {
      ...first,
      if (second != null) ...second,
      if (third != null) ...third,
      if (fourth != null) ...fourth,
    };
  }

  /// Encodes a map as URL-encoded form data.
  ///
  /// Example:
  /// ```dart
  /// final res = await client.post(
  ///   '/login',
  ///   headers: RequestHelper.formHeaders,
  ///   body: RequestHelper.encodeForm({
  ///     'username': 'john',
  ///     'password': 'secret',
  ///   }),
  /// );
  /// ```
  static String encodeForm(Map<String, String> data) {
    return data.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }
}

// -----------------------------------------------------------------------------
// Fluent Assertions Extension
// -----------------------------------------------------------------------------

/// Extension on TestResponse for fluent assertions.
///
/// Example:
/// ```dart
/// final res = await client.get('/users');
/// await res.expect
///   .status(200)
///   .header('content-type', contains('json'))
///   .jsonPath('users', hasLength(greaterThan(0)));
/// ```
extension FluentAssertions on TestResponse {
  /// Returns a fluent assertion builder for this response.
  ResponseExpect get expect => ResponseExpect(this);
}

/// Fluent assertion builder for TestResponse.
class ResponseExpect {
  final TestResponse _response;

  ResponseExpect(this._response);

  /// Asserts the response has the given status code.
  ResponseExpect status(int expected) {
    if (_response.status != expected) {
      throw ChaseTestFailure(
        'Expected status $expected but got ${_response.status}',
      );
    }
    return this;
  }

  /// Asserts the response status is in the 2xx range.
  ResponseExpect isOk() {
    if (!_response.isOk) {
      throw ChaseTestFailure(
        'Expected OK status (2xx) but got ${_response.status}',
      );
    }
    return this;
  }

  /// Asserts the response status is in the 4xx range.
  ResponseExpect isClientError() {
    if (!_response.isClientError) {
      throw ChaseTestFailure(
        'Expected client error (4xx) but got ${_response.status}',
      );
    }
    return this;
  }

  /// Asserts the response status is in the 5xx range.
  ResponseExpect isServerError() {
    if (!_response.isServerError) {
      throw ChaseTestFailure(
        'Expected server error (5xx) but got ${_response.status}',
      );
    }
    return this;
  }

  /// Asserts the response has a header with the given value.
  ResponseExpect header(String name, Object expected) {
    final value = _response.headers.value(name);
    if (value == null) {
      throw ChaseTestFailure('Expected header "$name" but it was not present');
    }

    if (expected is Matcher) {
      if (!expected.matches(value, {})) {
        throw ChaseTestFailure(
          'Header "$name" with value "$value" did not match expected',
        );
      }
    } else if (value != expected.toString()) {
      throw ChaseTestFailure(
        'Expected header "$name" to be "$expected" but got "$value"',
      );
    }
    return this;
  }

  /// Asserts the response has the given content type.
  ResponseExpect contentType(String expected) {
    final ct = _response.contentType;
    if (ct == null || !ct.contains(expected)) {
      throw ChaseTestFailure(
        'Expected content-type containing "$expected" but got "$ct"',
      );
    }
    return this;
  }

  /// Asserts the response body matches the expected value.
  ///
  /// This method is async.
  Future<ResponseExpect> body(Object expected) async {
    final body = await _response.body;
    if (expected is Matcher) {
      if (!expected.matches(body, {})) {
        throw ChaseTestFailure('Body "$body" did not match expected');
      }
    } else if (body != expected.toString()) {
      throw ChaseTestFailure('Expected body "$expected" but got "$body"');
    }
    return this;
  }

  /// Asserts a JSON path has the expected value.
  ///
  /// This method is async.
  ///
  /// Example:
  /// ```dart
  /// await res.expect.jsonPath('user.name', 'John');
  /// await res.expect.jsonPath('items', hasLength(3));
  /// ```
  Future<ResponseExpect> jsonPath(String path, Object expected) async {
    final json = await _response.json;
    final value = _getJsonPath(json, path);

    if (expected is Matcher) {
      if (!expected.matches(value, {})) {
        throw ChaseTestFailure(
          'JSON path "$path" with value "$value" did not match expected',
        );
      }
    } else if (value != expected) {
      throw ChaseTestFailure(
        'Expected JSON path "$path" to be "$expected" but got "$value"',
      );
    }
    return this;
  }

  /// Asserts the JSON body matches the expected map.
  ///
  /// This method is async.
  Future<ResponseExpect> jsonEquals(Map<String, dynamic> expected) async {
    final json = await _response.json;
    if (json is! Map) {
      throw ChaseTestFailure(
        'Expected JSON object but got ${json.runtimeType}',
      );
    }

    for (final entry in expected.entries) {
      if (json[entry.key] != entry.value) {
        throw ChaseTestFailure(
          'JSON key "${entry.key}": expected "${entry.value}" but got "${json[entry.key]}"',
        );
      }
    }
    return this;
  }

  dynamic _getJsonPath(dynamic json, String path) {
    final parts = path.split('.');
    dynamic current = json;

    for (final part in parts) {
      if (current is Map) {
        current = current[part];
      } else if (current is List) {
        final index = int.tryParse(part);
        if (index != null && index >= 0 && index < current.length) {
          current = current[index];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }
    return current;
  }
}

/// Exception thrown when a test assertion fails.
class ChaseTestFailure implements Exception {
  final String message;

  ChaseTestFailure(this.message);

  @override
  String toString() => message;
}

// -----------------------------------------------------------------------------
// Cookie Testing Helpers
// -----------------------------------------------------------------------------

/// Extension on TestResponse for cookie testing.
extension CookieTestingExtension on TestResponse {
  /// Gets all Set-Cookie headers as a map of name to value.
  Map<String, String> get cookieValues {
    final result = <String, String>{};
    final cookies = headers['set-cookie'];
    if (cookies == null) return result;

    for (final cookie in cookies) {
      final parts = cookie.split(';');
      if (parts.isEmpty) continue;

      final nameValue = parts[0].split('=');
      if (nameValue.length >= 2) {
        result[nameValue[0].trim()] = nameValue.sublist(1).join('=');
      }
    }
    return result;
  }

  /// Gets a specific cookie value by name.
  String? getCookie(String name) => cookieValues[name];

  /// Checks if a cookie exists.
  bool hasCookieNamed(String name) => cookieValues.containsKey(name);
}

// -----------------------------------------------------------------------------
// TestClient Extensions
// -----------------------------------------------------------------------------

/// Extension on TestClient for common patterns.
extension TestClientExtensions on TestClient {
  /// Sends a GET request with Bearer authentication.
  Future<TestResponse> getWithAuth(
    String path,
    String token, {
    Map<String, String>? headers,
  }) => get(
    path,
    headers: RequestHelper.mergeHeaders(
      AuthHelper.bearer(token),
      headers ?? {},
    ),
  );

  /// Sends a POST request with JSON body and optional auth.
  Future<TestResponse> postJson(
    String path,
    Object body, {
    String? token,
    Map<String, String>? headers,
  }) => post(
    path,
    body: body,
    headers: RequestHelper.mergeHeaders(
      RequestHelper.jsonHeaders,
      token != null ? AuthHelper.bearer(token) : {},
      headers ?? {},
    ),
  );

  /// Sends a PUT request with JSON body and optional auth.
  Future<TestResponse> putJson(
    String path,
    Object body, {
    String? token,
    Map<String, String>? headers,
  }) => put(
    path,
    body: body,
    headers: RequestHelper.mergeHeaders(
      RequestHelper.jsonHeaders,
      token != null ? AuthHelper.bearer(token) : {},
      headers ?? {},
    ),
  );

  /// Sends a PATCH request with JSON body and optional auth.
  Future<TestResponse> patchJson(
    String path,
    Object body, {
    String? token,
    Map<String, String>? headers,
  }) => patch(
    path,
    body: body,
    headers: RequestHelper.mergeHeaders(
      RequestHelper.jsonHeaders,
      token != null ? AuthHelper.bearer(token) : {},
      headers ?? {},
    ),
  );
}
