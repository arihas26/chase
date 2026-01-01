import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('ConnInfo', () {
    group('remote', () {
      test('provides remote address', () {
        final ctx = TestContext.get('/', remoteIp: '192.168.1.100');
        final info = ctx.req.connInfo;

        expect(info.remote.address, '192.168.1.100');
      });

      test('provides remote port', () {
        final ctx = TestContext.get('/');
        final info = ctx.req.connInfo;

        // MockHttpConnectionInfo sets remotePort to 12345
        expect(info.remote.port, 12345);
      });

      test('detects IPv4 address type', () {
        final ctx = TestContext.get('/', remoteIp: '10.0.0.1');
        final info = ctx.req.connInfo;

        expect(info.remote.addressType, AddressType.ipv4);
      });

      test('detects IPv6 address type', () {
        final ctx = TestContext.get('/', remoteIp: '::1');
        final info = ctx.req.connInfo;

        expect(info.remote.addressType, AddressType.ipv6);
      });

      test('detects full IPv6 address type', () {
        final ctx = TestContext.get('/', remoteIp: '2001:db8::1');
        final info = ctx.req.connInfo;

        expect(info.remote.addressType, AddressType.ipv6);
      });

      test('sets transport to tcp', () {
        final ctx = TestContext.get('/');
        final info = ctx.req.connInfo;

        expect(info.remote.transport, 'tcp');
      });
    });

    group('local', () {
      test('provides local port', () {
        final ctx = TestContext.get('/');
        final info = ctx.req.connInfo;

        // MockHttpConnectionInfo sets localPort to 8080
        expect(info.local.port, 8080);
      });

      test('sets transport to tcp', () {
        final ctx = TestContext.get('/');
        final info = ctx.req.connInfo;

        expect(info.local.transport, 'tcp');
      });
    });

    group('backward compatibility', () {
      test('ip getter still works', () {
        final ctx = TestContext.get('/', remoteIp: '192.168.1.1');

        expect(ctx.req.ip, '192.168.1.1');
      });

      test('remoteAddress getter still works', () {
        final ctx = TestContext.get('/', remoteIp: '192.168.1.1');

        expect(ctx.req.remoteAddress, '192.168.1.1');
      });

      test('remotePort getter still works', () {
        final ctx = TestContext.get('/');

        expect(ctx.req.remotePort, 12345);
      });

      test('localPort getter works', () {
        final ctx = TestContext.get('/');

        expect(ctx.req.localPort, 8080);
      });
    });

    group('X-Forwarded-For', () {
      test('ip uses X-Forwarded-For when present', () {
        final ctx = TestContext.get(
          '/',
          headers: {
            'x-forwarded-for': '203.0.113.195, 70.41.3.18, 150.172.238.178',
          },
          remoteIp: '127.0.0.1',
        );

        // ip should return first from X-Forwarded-For
        expect(ctx.req.ip, '203.0.113.195');

        // connInfo.remote.address should return direct connection
        expect(ctx.req.connInfo.remote.address, '127.0.0.1');
      });
    });

    group('toString', () {
      test('ConnInfo toString', () {
        final ctx = TestContext.get('/', remoteIp: '192.168.1.1');
        final info = ctx.req.connInfo;

        expect(info.toString(), contains('ConnInfo'));
        expect(info.toString(), contains('remote'));
        expect(info.toString(), contains('local'));
      });

      test('NetAddrInfo toString', () {
        final ctx = TestContext.get('/', remoteIp: '192.168.1.1');
        final info = ctx.req.connInfo;

        expect(info.remote.toString(), contains('192.168.1.1'));
        expect(info.remote.toString(), contains('ipv4'));
      });
    });
  });
}
