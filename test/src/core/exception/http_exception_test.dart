import 'package:chase/src/core/exception/http_exception.dart';
import 'package:test/test.dart';

void main() {
  group('HttpException', () {
    test('creates exception with status code and message', () {
      final exception = HttpException(404, 'Not Found');

      expect(exception.statusCode, 404);
      expect(exception.message, 'Not Found');
    });

    test('toString includes status code and message', () {
      final exception = HttpException(500, 'Server Error');

      expect(exception.toString(), 'HttpException(500): Server Error');
    });

    test('implements Exception', () {
      final exception = HttpException(400, 'Bad Request');

      expect(exception, isA<Exception>());
    });
  });

  group('Specialized exceptions', () {
    test('BadRequestException has status 400', () {
      final exception = BadRequestException('Invalid input');

      expect(exception.statusCode, 400);
      expect(exception.message, 'Invalid input');
    });

    test('UnauthorizedException has status 401', () {
      final exception = UnauthorizedException('Login required');

      expect(exception.statusCode, 401);
      expect(exception.message, 'Login required');
    });

    test('ForbiddenException has status 403', () {
      final exception = ForbiddenException('Access denied');

      expect(exception.statusCode, 403);
      expect(exception.message, 'Access denied');
    });

    test('NotFoundException has status 404', () {
      final exception = NotFoundException('User not found');

      expect(exception.statusCode, 404);
      expect(exception.message, 'User not found');
    });

    test('ConflictException has status 409', () {
      final exception = ConflictException('Resource conflict');

      expect(exception.statusCode, 409);
      expect(exception.message, 'Resource conflict');
    });

    test('InternalServerErrorException has status 500', () {
      final exception = InternalServerErrorException('Database error');

      expect(exception.statusCode, 500);
      expect(exception.message, 'Database error');
    });

    test('ServiceUnavailableException has status 503', () {
      final exception = ServiceUnavailableException('Maintenance mode');

      expect(exception.statusCode, 503);
      expect(exception.message, 'Maintenance mode');
    });
  });
}
