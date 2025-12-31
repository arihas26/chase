/// Custom test matchers for Chase framework.
///
/// Provides convenient matchers for testing HTTP responses.
///
/// Example:
/// ```dart
/// import 'package:chase/testing/testing.dart';
/// import 'package:test/test.dart';
///
/// test('returns OK', () async {
///   final res = await client.get('/');
///   expect(res, isOkResponse);
///   expect(res, hasStatus(200));
///   expect(res, hasHeader('content-type', contains('json')));
/// });
/// ```
library;

import 'package:test/test.dart';

import 'testing.dart';

// -----------------------------------------------------------------------------
// Status Matchers
// -----------------------------------------------------------------------------

/// Matches a response with status code in the 2xx range.
const Matcher isOkResponse = _StatusRangeMatcher(200, 299, 'OK (2xx)');

/// Matches a response with status code in the 3xx range.
const Matcher isRedirectResponse =
    _StatusRangeMatcher(300, 399, 'redirect (3xx)');

/// Matches a response with status code in the 4xx range.
const Matcher isClientErrorResponse =
    _StatusRangeMatcher(400, 499, 'client error (4xx)');

/// Matches a response with status code in the 5xx range.
const Matcher isServerErrorResponse =
    _StatusRangeMatcher(500, 599, 'server error (5xx)');

/// Matches a response with the exact status code.
///
/// Example:
/// ```dart
/// expect(res, hasStatus(201));
/// expect(res, hasStatus(404));
/// ```
Matcher hasStatus(int statusCode) => _StatusMatcher(statusCode);

class _StatusRangeMatcher extends Matcher {
  final int _min;
  final int _max;
  final String _description;

  const _StatusRangeMatcher(this._min, this._max, this._description);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is TestResponse) {
      return item.status >= _min && item.status <= _max;
    }
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('response with $_description status');

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is TestResponse) {
      return mismatchDescription.add('has status ${item.status}');
    }
    return mismatchDescription.add('is not a TestResponse');
  }
}

class _StatusMatcher extends Matcher {
  final int _expectedStatus;

  const _StatusMatcher(this._expectedStatus);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is TestResponse) {
      return item.status == _expectedStatus;
    }
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('response with status $_expectedStatus');

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is TestResponse) {
      return mismatchDescription.add('has status ${item.status}');
    }
    return mismatchDescription.add('is not a TestResponse');
  }
}

// -----------------------------------------------------------------------------
// Header Matchers
// -----------------------------------------------------------------------------

/// Matches a response that has the specified header.
///
/// If [valueMatcher] is provided, also checks the header value.
///
/// Example:
/// ```dart
/// expect(res, hasHeader('content-type'));
/// expect(res, hasHeader('content-type', 'application/json'));
/// expect(res, hasHeader('content-type', contains('json')));
/// ```
Matcher hasHeader(String name, [Object? valueMatcher]) =>
    _HeaderMatcher(name, valueMatcher);

class _HeaderMatcher extends Matcher {
  final String _name;
  final Object? _valueMatcher;

  const _HeaderMatcher(this._name, this._valueMatcher);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is TestResponse) {
      final value = item.headers.value(_name);
      if (value == null) return false;
      if (_valueMatcher == null) return true;

      if (_valueMatcher case final Matcher m) {
        return m.matches(value, matchState);
      }
      return value == _valueMatcher.toString();
    }
    return false;
  }

  @override
  Description describe(Description description) {
    description.add('response with header "$_name"');
    if (_valueMatcher != null) {
      description.add(' matching ');
      if (_valueMatcher case final Matcher m) {
        m.describe(description);
      } else {
        description.add('"$_valueMatcher"');
      }
    }
    return description;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is TestResponse) {
      final value = item.headers.value(_name);
      if (value == null) {
        return mismatchDescription.add('does not have header "$_name"');
      }
      return mismatchDescription.add('has header "$_name" with value "$value"');
    }
    return mismatchDescription.add('is not a TestResponse');
  }
}

/// Matches a response with Content-Type containing the given type.
///
/// Example:
/// ```dart
/// expect(res, hasContentType('application/json'));
/// expect(res, hasContentType('text/html'));
/// ```
Matcher hasContentType(String type) =>
    hasHeader('content-type', contains(type));

// -----------------------------------------------------------------------------
// Body Matchers
// -----------------------------------------------------------------------------

/// Matches a response body against the given matcher.
///
/// Note: This is an async matcher that requires `await`.
///
/// Example:
/// ```dart
/// expect(await res.body, contains('Hello'));
/// expect(await res.body, equals('{"status":"ok"}'));
/// ```
// Body matchers work directly with `await res.body` or `await res.json`

/// Matches a response with JSON body matching the given value or matcher.
///
/// Example:
/// ```dart
/// final json = await res.json;
/// expect(json, hasJsonPath('user.name', 'John'));
/// expect(json, hasJsonPath('items', hasLength(3)));
/// ```
Matcher hasJsonPath(String path, Object? valueMatcher) =>
    _JsonPathMatcher(path, valueMatcher);

class _JsonPathMatcher extends Matcher {
  final String _path;
  final Object? _valueMatcher;

  const _JsonPathMatcher(this._path, this._valueMatcher);

  dynamic _getValue(dynamic json, String path) {
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

  @override
  bool matches(dynamic item, Map matchState) {
    final value = _getValue(item, _path);
    matchState['actualValue'] = value;

    if (_valueMatcher == null) {
      return value != null;
    }

    if (_valueMatcher case final Matcher m) {
      return m.matches(value, matchState);
    }
    // Use deep equality for collections
    return equals(_valueMatcher).matches(value, matchState);
  }

  @override
  Description describe(Description description) {
    description.add('JSON with path "$_path"');
    if (_valueMatcher != null) {
      description.add(' matching ');
      if (_valueMatcher case final Matcher m) {
        m.describe(description);
      } else {
        description.addDescriptionOf(_valueMatcher);
      }
    }
    return description;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final value = matchState['actualValue'];
    if (value == null) {
      return mismatchDescription.add('path "$_path" not found');
    }
    return mismatchDescription.add('has value $value at "$_path"');
  }
}

// -----------------------------------------------------------------------------
// Cookie Matchers
// -----------------------------------------------------------------------------

/// Matches a response that has a Set-Cookie header with the given name.
///
/// Example:
/// ```dart
/// expect(res, hasCookie('session'));
/// expect(res, hasCookie('token', 'abc123'));
/// ```
Matcher hasCookie(String name, [Object? valueMatcher]) =>
    _CookieMatcher(name, valueMatcher);

class _CookieMatcher extends Matcher {
  final String _name;
  final Object? _valueMatcher;

  const _CookieMatcher(this._name, this._valueMatcher);

  String? _getCookieValue(TestResponse response) {
    final cookies = response.headers['set-cookie'];
    if (cookies == null) return null;

    for (final cookie in cookies) {
      // Parse "name=value; ..." format
      final parts = cookie.split(';');
      if (parts.isEmpty) continue;

      final nameValue = parts[0].split('=');
      if (nameValue.length >= 2 && nameValue[0].trim() == _name) {
        return nameValue.sublist(1).join('='); // Handle values with '='
      }
    }
    return null;
  }

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is TestResponse) {
      final value = _getCookieValue(item);
      matchState['cookieValue'] = value;

      if (value == null) return false;
      if (_valueMatcher == null) return true;

      if (_valueMatcher case final Matcher m) {
        return m.matches(value, matchState);
      }
      return value == _valueMatcher.toString();
    }
    return false;
  }

  @override
  Description describe(Description description) {
    description.add('response with cookie "$_name"');
    if (_valueMatcher != null) {
      description.add(' matching ');
      if (_valueMatcher case final Matcher m) {
        m.describe(description);
      } else {
        description.add('"$_valueMatcher"');
      }
    }
    return description;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is TestResponse) {
      final value = matchState['cookieValue'];
      if (value == null) {
        return mismatchDescription.add('does not have cookie "$_name"');
      }
      return mismatchDescription
          .add('has cookie "$_name" with value "$value"');
    }
    return mismatchDescription.add('is not a TestResponse');
  }
}
