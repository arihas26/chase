import 'dart:async';
import 'dart:io';

import 'package:chase/chase.dart';

/// Middleware that restricts access based on client IP address.
///
/// This middleware can allow or deny requests based on IP addresses
/// using static IPs, CIDR notation, or wildcards.
///
/// ## Example
///
/// ```dart
/// // Allow only specific IPs
/// app.use(IpRestriction(
///   allowList: ['192.168.1.0/24', '10.0.0.1'],
/// ));
///
/// // Block specific IPs
/// app.use(IpRestriction(
///   denyList: ['192.168.1.100', '10.0.0.0/8'],
/// ));
///
/// // Custom rejection handler
/// app.use(IpRestriction(
///   denyList: ['*'],
///   allowList: ['127.0.0.1'],
///   onDenied: (ctx, ip) => Response.forbidden({'error': 'Access denied'}),
/// ));
/// ```
///
/// ## Rule Evaluation Order
///
/// 1. If `denyList` contains the IP → Deny (unless in allowList)
/// 2. If `allowList` is not empty and IP is not in it → Deny
/// 3. Otherwise → Allow
///
/// ## Supported Formats
///
/// - Static IPv4: `192.168.1.1`
/// - Static IPv6: `::1`, `2001:db8::1`
/// - CIDR notation: `192.168.1.0/24`, `2001:db8::/32`
/// - Wildcard: `*` (matches all)
class IpRestriction implements Middleware {
  /// List of IP addresses/ranges to deny.
  final List<String> denyList;

  /// List of IP addresses/ranges to allow.
  ///
  /// If empty, all IPs not in denyList are allowed.
  /// If not empty, only IPs in this list are allowed.
  final List<String> allowList;

  /// Custom handler when access is denied.
  ///
  /// Receives the context and the client's IP address.
  /// If null, returns 403 Forbidden.
  final FutureOr<dynamic> Function(Context ctx, String ip)? onDenied;

  final List<_IpRule> _denyRules;
  final List<_IpRule> _allowRules;

  /// Creates an IP restriction middleware.
  ///
  /// At least one of [denyList] or [allowList] should be provided.
  IpRestriction({
    this.denyList = const [],
    this.allowList = const [],
    this.onDenied,
  })  : _denyRules = denyList.map(_IpRule.parse).toList(),
        _allowRules = allowList.map(_IpRule.parse).toList();

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final ip = ctx.req.ip;

    if (!_isAllowed(ip)) {
      if (onDenied != null) {
        final result = await onDenied!(ctx, ip);
        if (result != null) {
          await _sendResponse(ctx, result);
        }
        return;
      }
      await ctx.res.json(
        {'error': 'Forbidden', 'message': 'Access denied'},
        status: HttpStatus.forbidden,
      );
      return;
    }

    await next();
  }

  bool _isAllowed(String ip) {
    // Check deny list first
    for (final rule in _denyRules) {
      if (rule.matches(ip)) {
        // Check if explicitly allowed
        for (final allowRule in _allowRules) {
          if (allowRule.matches(ip)) {
            return true;
          }
        }
        return false;
      }
    }

    // If allowList is specified, IP must be in it
    if (_allowRules.isNotEmpty) {
      for (final rule in _allowRules) {
        if (rule.matches(ip)) {
          return true;
        }
      }
      return false;
    }

    return true;
  }

  Future<void> _sendResponse(Context ctx, dynamic result) async {
    if (ctx.res.isSent) return;

    switch (result) {
      case Response response:
        response.headers.forEach((key, value) {
          ctx.res.headers.set(key, value);
        });
        if (response.body != null) {
          await ctx.res.json(response.body, status: response.statusCode);
        } else {
          ctx.res.statusCode = response.statusCode;
        }
      case String text:
        await ctx.res.text(text);
      case Map json:
        await ctx.res.json(json);
      case null:
        break;
      default:
        await ctx.res.json(result);
    }
  }
}

/// Represents an IP matching rule.
abstract class _IpRule {
  bool matches(String ip);

  factory _IpRule.parse(String pattern) {
    if (pattern == '*') {
      return _WildcardRule();
    }

    if (pattern.contains('/')) {
      // CIDR notation
      final parts = pattern.split('/');
      final prefix = int.tryParse(parts[1]);
      if (prefix == null) {
        throw ArgumentError('Invalid CIDR prefix: ${parts[1]}');
      }

      if (pattern.contains(':')) {
        // IPv6 CIDR
        return _Ipv6CidrRule(parts[0], prefix);
      } else {
        // IPv4 CIDR
        return _Ipv4CidrRule(parts[0], prefix);
      }
    }

    // Static IP
    if (pattern.contains(':')) {
      return _Ipv6StaticRule(pattern);
    } else {
      return _Ipv4StaticRule(pattern);
    }
  }
}

class _WildcardRule implements _IpRule {
  @override
  bool matches(String ip) => true;
}

class _Ipv4StaticRule implements _IpRule {
  final String ip;

  _Ipv4StaticRule(this.ip);

  @override
  bool matches(String ip) => this.ip == ip;
}

class _Ipv6StaticRule implements _IpRule {
  final List<int> _segments;

  _Ipv6StaticRule(String ip) : _segments = _parseIpv6(ip);

  @override
  bool matches(String ip) {
    if (!ip.contains(':')) return false;
    try {
      final segments = _parseIpv6(ip);
      for (var i = 0; i < 8; i++) {
        if (_segments[i] != segments[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _Ipv4CidrRule implements _IpRule {
  final int _network;
  final int _mask;

  _Ipv4CidrRule(String ip, int prefix)
      : _network = _parseIpv4(ip),
        _mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;

  @override
  bool matches(String ip) {
    if (ip.contains(':')) return false;
    try {
      final addr = _parseIpv4(ip);
      return (addr & _mask) == (_network & _mask);
    } catch (_) {
      return false;
    }
  }
}

class _Ipv6CidrRule implements _IpRule {
  final List<int> _network;
  final int _prefix;

  _Ipv6CidrRule(String ip, this._prefix) : _network = _parseIpv6(ip);

  @override
  bool matches(String ip) {
    if (!ip.contains(':')) return false;
    try {
      final segments = _parseIpv6(ip);
      var bitsRemaining = _prefix;

      for (var i = 0; i < 8; i++) {
        if (bitsRemaining <= 0) break;

        if (bitsRemaining >= 16) {
          if (_network[i] != segments[i]) return false;
          bitsRemaining -= 16;
        } else {
          final mask = (0xFFFF << (16 - bitsRemaining)) & 0xFFFF;
          if ((_network[i] & mask) != (segments[i] & mask)) return false;
          bitsRemaining = 0;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Parses an IPv4 address to a 32-bit integer.
int _parseIpv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) {
    throw ArgumentError('Invalid IPv4 address: $ip');
  }

  var result = 0;
  for (final part in parts) {
    final value = int.parse(part);
    if (value < 0 || value > 255) {
      throw ArgumentError('Invalid IPv4 octet: $part');
    }
    result = (result << 8) | value;
  }
  return result;
}

/// Parses an IPv6 address to 8 segments (16-bit each).
List<int> _parseIpv6(String ip) {
  // Handle IPv4-mapped IPv6 (::ffff:192.168.1.1)
  if (ip.contains('.')) {
    final lastColon = ip.lastIndexOf(':');
    final ipv4Part = ip.substring(lastColon + 1);
    final ipv6Part = ip.substring(0, lastColon);
    final ipv4 = _parseIpv4(ipv4Part);

    final segments = _parseIpv6('$ipv6Part:0:0');
    segments[6] = (ipv4 >> 16) & 0xFFFF;
    segments[7] = ipv4 & 0xFFFF;
    return segments;
  }

  final segments = List<int>.filled(8, 0);

  if (ip == '::') {
    return segments;
  }

  final parts = ip.split('::');
  if (parts.length > 2) {
    throw ArgumentError('Invalid IPv6 address: $ip');
  }

  if (parts.length == 2) {
    // Has ::
    final left = parts[0].isEmpty ? <String>[] : parts[0].split(':');
    final right = parts[1].isEmpty ? <String>[] : parts[1].split(':');

    for (var i = 0; i < left.length; i++) {
      segments[i] = int.parse(left[i], radix: 16);
    }
    for (var i = 0; i < right.length; i++) {
      segments[8 - right.length + i] = int.parse(right[i], radix: 16);
    }
  } else {
    // No ::
    final hexParts = ip.split(':');
    if (hexParts.length != 8) {
      throw ArgumentError('Invalid IPv6 address: $ip');
    }
    for (var i = 0; i < 8; i++) {
      segments[i] = int.parse(hexParts[i], radix: 16);
    }
  }

  return segments;
}

/// Creates an IP restriction middleware that allows only specified IPs.
///
/// ```dart
/// app.use(ipRestriction(allowList: ['127.0.0.1', '::1']));
/// ```
IpRestriction ipRestriction({
  List<String> denyList = const [],
  List<String> allowList = const [],
  FutureOr<dynamic> Function(Context ctx, String ip)? onDenied,
}) {
  return IpRestriction(
    denyList: denyList,
    allowList: allowList,
    onDenied: onDenied,
  );
}
