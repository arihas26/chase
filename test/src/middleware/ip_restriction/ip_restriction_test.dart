import 'dart:io';

import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('IpRestriction', () {
    group('allowList', () {
      test('allows IP in allowList', () async {
        final ctx = TestContext.get('/', remoteIp: '192.168.1.100');
        var nextCalled = false;
        final middleware = IpRestriction(allowList: ['192.168.1.100']);

        await middleware.handle(ctx, () async {
          nextCalled = true;
        });

        expect(nextCalled, isTrue);
      });

      test('denies IP not in allowList', () async {
        final ctx = TestContext.get('/', remoteIp: '192.168.1.200');
        var nextCalled = false;
        final middleware = IpRestriction(allowList: ['192.168.1.100']);

        await middleware.handle(ctx, () async {
          nextCalled = true;
        });

        expect(nextCalled, isFalse);
        expect(ctx.response.statusCode, HttpStatus.forbidden);
      });

      test('allows localhost when in allowList', () async {
        final ctx = TestContext.get('/', remoteIp: '127.0.0.1');
        var nextCalled = false;
        final middleware = IpRestriction(allowList: ['127.0.0.1']);

        await middleware.handle(ctx, () async {
          nextCalled = true;
        });

        expect(nextCalled, isTrue);
      });
    });

    group('denyList', () {
      test('denies IP in denyList', () async {
        final ctx = TestContext.get('/', remoteIp: '10.0.0.1');
        var nextCalled = false;
        final middleware = IpRestriction(denyList: ['10.0.0.1']);

        await middleware.handle(ctx, () async {
          nextCalled = true;
        });

        expect(nextCalled, isFalse);
        expect(ctx.response.statusCode, HttpStatus.forbidden);
      });

      test('allows IP not in denyList', () async {
        final ctx = TestContext.get('/', remoteIp: '192.168.1.1');
        var nextCalled = false;
        final middleware = IpRestriction(denyList: ['10.0.0.1']);

        await middleware.handle(ctx, () async {
          nextCalled = true;
        });

        expect(nextCalled, isTrue);
      });
    });

    group('CIDR notation', () {
      test('matches IPv4 CIDR /24', () async {
        final middleware = IpRestriction(allowList: ['192.168.1.0/24']);

        // Should allow
        for (final ip in ['192.168.1.0', '192.168.1.1', '192.168.1.255']) {
          final ctx = TestContext.get('/', remoteIp: ip);
          var nextCalled = false;
          await middleware.handle(ctx, () async {
            nextCalled = true;
          });
          expect(nextCalled, isTrue, reason: '$ip should be allowed');
        }

        // Should deny
        for (final ip in ['192.168.2.1', '10.0.0.1']) {
          final ctx = TestContext.get('/', remoteIp: ip);
          var nextCalled = false;
          await middleware.handle(ctx, () async {
            nextCalled = true;
          });
          expect(nextCalled, isFalse, reason: '$ip should be denied');
        }
      });

      test('matches IPv4 CIDR /16', () async {
        final middleware = IpRestriction(allowList: ['10.20.0.0/16']);

        // Should allow
        for (final ip in ['10.20.0.1', '10.20.255.255']) {
          final ctx = TestContext.get('/', remoteIp: ip);
          var nextCalled = false;
          await middleware.handle(ctx, () async {
            nextCalled = true;
          });
          expect(nextCalled, isTrue, reason: '$ip should be allowed');
        }

        // Should deny
        final ctx = TestContext.get('/', remoteIp: '10.21.0.1');
        var nextCalled = false;
        await middleware.handle(ctx, () async {
          nextCalled = true;
        });
        expect(nextCalled, isFalse);
      });

      test('matches IPv4 CIDR /8', () async {
        final middleware = IpRestriction(denyList: ['10.0.0.0/8']);

        // Should deny all 10.x.x.x
        final ctx = TestContext.get('/', remoteIp: '10.255.255.255');
        var nextCalled = false;
        await middleware.handle(ctx, () async {
          nextCalled = true;
        });
        expect(nextCalled, isFalse);

        // Should allow other ranges
        final ctx2 = TestContext.get('/', remoteIp: '192.168.1.1');
        var nextCalled2 = false;
        await middleware.handle(ctx2, () async {
          nextCalled2 = true;
        });
        expect(nextCalled2, isTrue);
      });
    });

    group('wildcard', () {
      test('* matches all IPs', () async {
        final middleware = IpRestriction(denyList: ['*']);

        for (final ip in ['127.0.0.1', '192.168.1.1', '10.0.0.1']) {
          final ctx = TestContext.get('/', remoteIp: ip);
          var nextCalled = false;
          await middleware.handle(ctx, () async {
            nextCalled = true;
          });
          expect(nextCalled, isFalse, reason: '$ip should be denied');
        }
      });

      test('allowList overrides denyList wildcard', () async {
        final middleware = IpRestriction(
          denyList: ['*'],
          allowList: ['127.0.0.1'],
        );

        // Allowed
        final ctx = TestContext.get('/', remoteIp: '127.0.0.1');
        var nextCalled = false;
        await middleware.handle(ctx, () async {
          nextCalled = true;
        });
        expect(nextCalled, isTrue);

        // Denied
        final ctx2 = TestContext.get('/', remoteIp: '192.168.1.1');
        var nextCalled2 = false;
        await middleware.handle(ctx2, () async {
          nextCalled2 = true;
        });
        expect(nextCalled2, isFalse);
      });
    });

    group('IPv6', () {
      test('matches static IPv6', () async {
        final middleware = IpRestriction(allowList: ['::1']);

        final ctx = TestContext.get('/', remoteIp: '::1');
        var nextCalled = false;
        await middleware.handle(ctx, () async {
          nextCalled = true;
        });
        expect(nextCalled, isTrue);
      });

      test('matches expanded IPv6', () async {
        final middleware = IpRestriction(allowList: ['2001:db8::1']);

        final ctx = TestContext.get('/', remoteIp: '2001:db8::1');
        var nextCalled = false;
        await middleware.handle(ctx, () async {
          nextCalled = true;
        });
        expect(nextCalled, isTrue);
      });

      test('matches IPv6 CIDR', () async {
        final middleware = IpRestriction(allowList: ['2001:db8::/32']);

        // Should allow
        final ctx = TestContext.get('/', remoteIp: '2001:db8::1');
        var nextCalled = false;
        await middleware.handle(ctx, () async {
          nextCalled = true;
        });
        expect(nextCalled, isTrue);

        // Should deny
        final ctx2 = TestContext.get('/', remoteIp: '2001:db9::1');
        var nextCalled2 = false;
        await middleware.handle(ctx2, () async {
          nextCalled2 = true;
        });
        expect(nextCalled2, isFalse);
      });
    });

    group('onDenied callback', () {
      test('uses custom response', () async {
        final ctx = TestContext.get('/', remoteIp: '10.0.0.1');
        final middleware = IpRestriction(
          denyList: ['10.0.0.1'],
          onDenied: (ctx, ip) => Response.forbidden({'blocked': ip}),
        );

        await middleware.handle(ctx, () async {});

        expect(ctx.response.statusCode, HttpStatus.forbidden);
      });

      test('receives correct IP', () async {
        final ctx = TestContext.get('/', remoteIp: '10.0.0.99');
        String? receivedIp;
        final middleware = IpRestriction(
          denyList: ['10.0.0.99'],
          onDenied: (ctx, ip) {
            receivedIp = ip;
            return null;
          },
        );

        await middleware.handle(ctx, () async {});

        expect(receivedIp, '10.0.0.99');
      });
    });

    group('combined rules', () {
      test('denyList + allowList interaction', () async {
        final middleware = IpRestriction(
          denyList: ['192.168.0.0/16'],
          allowList: ['192.168.1.0/24'],
        );

        // 192.168.1.x is in both denyList (via /16) and allowList (via /24)
        // allowList should win
        final ctx = TestContext.get('/', remoteIp: '192.168.1.100');
        var nextCalled = false;
        await middleware.handle(ctx, () async {
          nextCalled = true;
        });
        expect(nextCalled, isTrue);

        // 192.168.2.x is only in denyList, should be denied
        final ctx2 = TestContext.get('/', remoteIp: '192.168.2.100');
        var nextCalled2 = false;
        await middleware.handle(ctx2, () async {
          nextCalled2 = true;
        });
        expect(nextCalled2, isFalse);
      });
    });

    group('ipRestriction function', () {
      test('creates middleware via function', () async {
        final ctx = TestContext.get('/', remoteIp: '127.0.0.1');
        var nextCalled = false;
        final middleware = ipRestriction(allowList: ['127.0.0.1']);

        await middleware.handle(ctx, () async {
          nextCalled = true;
        });

        expect(nextCalled, isTrue);
      });
    });

    group('empty lists', () {
      test('allows all when both lists empty', () async {
        final ctx = TestContext.get('/', remoteIp: '1.2.3.4');
        var nextCalled = false;
        final middleware = IpRestriction();

        await middleware.handle(ctx, () async {
          nextCalled = true;
        });

        expect(nextCalled, isTrue);
      });
    });
  });
}
