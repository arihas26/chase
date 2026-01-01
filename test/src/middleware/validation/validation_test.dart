import 'package:chase/chase.dart';
import 'package:chase/testing/testing.dart';
import 'package:test/test.dart';

void main() {
  group('V (Validator Builder)', () {
    group('isString', () {
      test('validates strings', () {
        final v = V.isString();
        expect(v.validate('field', 'hello'), isEmpty);
        expect(v.validate('field', 123), hasLength(1));
        expect(
          v.validate('field', null),
          isEmpty,
        ); // null is ok without required
      });

      test('with required', () {
        final v = V.isString().required();
        expect(v.validate('field', 'hello'), isEmpty);
        expect(v.validate('field', null), hasLength(1));
        expect(v.validate('field', ''), hasLength(1));
      });

      test('with min length', () {
        final v = V.isString().min(3);
        expect(v.validate('field', 'hello'), isEmpty);
        expect(v.validate('field', 'hi'), hasLength(1));
      });

      test('with max length', () {
        final v = V.isString().max(5);
        expect(v.validate('field', 'hello'), isEmpty);
        expect(v.validate('field', 'hello world'), hasLength(1));
      });

      test('with exact length', () {
        final v = V.isString().length(5);
        expect(v.validate('field', 'hello'), isEmpty);
        expect(v.validate('field', 'hi'), hasLength(1));
        expect(v.validate('field', 'hello world'), hasLength(1));
      });
    });

    group('isInt', () {
      test('validates integers', () {
        final v = V.isInt();
        expect(v.validate('field', 42), isEmpty);
        expect(v.validate('field', '42'), isEmpty); // string parsing
        expect(v.validate('field', 'abc'), hasLength(1));
      });

      test('transforms string to int', () {
        final v = V.isInt();
        expect(v.transform('42'), equals(42));
        expect(v.transform(42), equals(42));
      });

      test('with min value', () {
        final v = V.isInt().min(10);
        expect(v.validate('field', 15), isEmpty);
        expect(v.validate('field', 5), hasLength(1));
      });

      test('with max value', () {
        final v = V.isInt().max(100);
        expect(v.validate('field', 50), isEmpty);
        expect(v.validate('field', 150), hasLength(1));
      });
    });

    group('isDouble', () {
      test('validates doubles', () {
        final v = V.isDouble();
        expect(v.validate('field', 3.14), isEmpty);
        expect(v.validate('field', '3.14'), isEmpty);
        expect(v.validate('field', 42), isEmpty); // int is also a num
        expect(v.validate('field', 'abc'), hasLength(1));
      });

      test('transforms string to double', () {
        final v = V.isDouble();
        expect(v.transform('3.14'), equals(3.14));
      });
    });

    group('isBool', () {
      test('validates booleans', () {
        final v = V.isBool();
        expect(v.validate('field', true), isEmpty);
        expect(v.validate('field', false), isEmpty);
        expect(v.validate('field', 'true'), isEmpty);
        expect(v.validate('field', 'false'), isEmpty);
        expect(v.validate('field', '1'), isEmpty);
        expect(v.validate('field', '0'), isEmpty);
        expect(v.validate('field', 'abc'), hasLength(1));
      });

      test('transforms string to bool', () {
        final v = V.isBool();
        expect(v.transform('true'), isTrue);
        expect(v.transform('false'), isFalse);
        expect(v.transform('1'), isTrue);
        expect(v.transform('0'), isFalse);
      });
    });

    group('list', () {
      test('validates lists', () {
        final v = V.list();
        expect(v.validate('field', [1, 2, 3]), isEmpty);
        expect(v.validate('field', 'not a list'), hasLength(1));
      });

      test('validates list items', () {
        final v = V.list((item) => V.isInt());
        expect(v.validate('field', [1, 2, 3]), isEmpty);
        // item validation is applied per-item
      });

      test('with min items', () {
        final v = V.list().min(2);
        expect(v.validate('field', [1, 2, 3]), isEmpty);
        expect(v.validate('field', [1]), hasLength(1));
      });

      test('with max items', () {
        final v = V.list().max(3);
        expect(v.validate('field', [1, 2]), isEmpty);
        expect(v.validate('field', [1, 2, 3, 4, 5]), hasLength(1));
      });
    });

    group('map', () {
      test('validates maps', () {
        final v = V.map();
        expect(v.validate('field', {'key': 'value'}), isEmpty);
        expect(v.validate('field', 'not a map'), hasLength(1));
      });
    });

    group('email', () {
      test('validates email format', () {
        final v = V.isString().email();
        expect(v.validate('email', 'test@example.com'), isEmpty);
        expect(v.validate('email', 'user.name@domain.org'), isEmpty);
        expect(v.validate('email', 'invalid'), hasLength(1));
        expect(v.validate('email', '@domain.com'), hasLength(1));
      });
    });

    group('url', () {
      test('validates URL format', () {
        final v = V.isString().url();
        expect(v.validate('url', 'https://example.com'), isEmpty);
        expect(v.validate('url', 'http://localhost:3000/path'), isEmpty);
        expect(v.validate('url', 'not-a-url'), hasLength(1));
      });
    });

    group('pattern', () {
      test('validates regex pattern', () {
        final v = V.isString().pattern(RegExp(r'^\d{3}-\d{4}$'));
        expect(v.validate('phone', '123-4567'), isEmpty);
        expect(v.validate('phone', '12-34567'), hasLength(1));
      });

      test('with custom message', () {
        final v = V.isString().pattern(
          RegExp(r'^\d+$'),
          message: 'must contain only digits',
        );
        final errors = v.validate('field', 'abc');
        expect(errors.first.message, 'must contain only digits');
      });
    });

    group('oneOf', () {
      test('validates allowed values', () {
        final v = V.isString().oneOf(['red', 'green', 'blue']);
        expect(v.validate('color', 'red'), isEmpty);
        expect(v.validate('color', 'yellow'), hasLength(1));
      });
    });

    group('custom', () {
      test('validates with custom function', () {
        final v = V.isString().custom(
          (value) => value.toString().startsWith('A'),
          message: 'must start with A',
        );
        expect(v.validate('field', 'Apple'), isEmpty);
        expect(v.validate('field', 'Banana'), hasLength(1));
      });
    });

    group('defaultValue', () {
      test('applies default when null', () {
        final v = V.isString().defaultValue('default');
        expect(v.transform(null), 'default');
        expect(v.transform('value'), 'value');
      });
    });
  });

  group('Schema', () {
    test('validates all fields', () {
      final schema = Schema({
        'name': V.isString().required().min(2),
        'age': V.isInt().required().min(0),
        'email': V.isString().email(),
      });

      final result = schema.validate({
        'name': 'John',
        'age': 25,
        'email': 'john@example.com',
      });

      expect(result.isValid, isTrue);
      expect(result.data['name'], 'John');
      expect(result.data['age'], 25);
    });

    test('returns errors for invalid fields', () {
      final schema = Schema({
        'name': V.isString().required().min(2),
        'age': V.isInt().required().min(18),
      });

      final result = schema.validate({'name': 'J', 'age': 15});

      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(2));
      expect(result.errorsByField['name'], isNotNull);
      expect(result.errorsByField['age'], isNotNull);
    });

    test('handles missing required fields', () {
      final schema = Schema({'name': V.isString().required()});

      final result = schema.validate({});

      expect(result.isValid, isFalse);
      expect(result.errors.first.rule, 'required');
    });

    test('handles null data', () {
      final schema = Schema({'name': V.isString().required()});

      final result = schema.validate(null);

      expect(result.isValid, isFalse);
    });

    test('transforms values', () {
      final schema = Schema({'age': V.isInt(), 'active': V.isBool()});

      final result = schema.validate({'age': '25', 'active': 'true'});

      expect(result.isValid, isTrue);
      expect(result.data['age'], 25);
      expect(result.data['active'], isTrue);
    });
  });

  group('ValidationError', () {
    test('toJson returns correct map', () {
      final error = ValidationError(
        field: 'email',
        message: 'must be a valid email',
        rule: 'email',
      );

      expect(error.toJson(), {
        'field': 'email',
        'message': 'must be a valid email',
        'rule': 'email',
      });
    });

    test('toString returns field: message format', () {
      final error = ValidationError(
        field: 'name',
        message: 'is required',
        rule: 'required',
      );

      expect(error.toString(), 'name: is required');
    });
  });

  group('ValidationResult', () {
    test('success factory creates valid result', () {
      final result = ValidationResult.success({'name': 'John'});
      expect(result.isValid, isTrue);
      expect(result.data['name'], 'John');
      expect(result.errors, isEmpty);
    });

    test('failure factory creates invalid result', () {
      final errors = [
        ValidationError(field: 'email', message: 'invalid', rule: 'email'),
      ];
      final result = ValidationResult.failure(errors);
      expect(result.isValid, isFalse);
      expect(result.data, isEmpty);
      expect(result.errors, hasLength(1));
    });
  });

  group('ValidationException', () {
    test('has status 422', () {
      final exception = ValidationException([]);
      expect(exception.statusCode, 422);
    });

    test('toJson returns errors', () {
      final exception = ValidationException([
        ValidationError(field: 'name', message: 'required', rule: 'required'),
      ]);

      final json = exception.toJson();
      expect(json['message'], 'Validation failed');
      expect(json['errors'], hasLength(1));
    });

    test('errorsByField groups errors', () {
      final exception = ValidationException([
        ValidationError(field: 'name', message: 'required', rule: 'required'),
        ValidationError(field: 'name', message: 'too short', rule: 'min'),
        ValidationError(field: 'email', message: 'invalid', rule: 'email'),
      ]);

      expect(exception.errorsByField['name'], hasLength(2));
      expect(exception.errorsByField['email'], hasLength(1));
    });
  });

  group('Validator Middleware', () {
    late Chase app;
    late TestClient client;

    setUp(() async {
      app = Chase(dev: true);
      client = await TestClient.start(app);
    });

    tearDown(() async {
      await client.close();
    });

    group('body validation', () {
      test('validates JSON body', () async {
        final schema = Schema({
          'name': V.isString().required().min(2),
          'email': V.isString().required().email(),
        });

        app.post('/users').use(Validator(body: schema)).handle((ctx) async {
          ctx.res.json({'validated': ctx.validatedBody});
        });

        final res = await client.postJson('/users', {
          'name': 'John',
          'email': 'john@example.com',
        });

        expect(res, isOkResponse);
        expect(await res.json, hasJsonPath('validated.name', 'John'));
      });

      test('returns 422 on validation failure', () async {
        final schema = Schema({'name': V.isString().required().min(2)});

        // Add ExceptionHandler to convert exceptions to proper responses
        app.use(ExceptionHandler());
        app.post('/users').use(Validator(body: schema)).handle((ctx) async {
          ctx.res.json({'ok': true});
        });

        final res = await client.postJson('/users', {'name': 'J'});

        expect(res, hasStatus(422));
      });

      test('with throwOnError: false stores errors in context', () async {
        final schema = Schema({'name': V.isString().required()});

        app
            .post('/users')
            .use(Validator(body: schema, throwOnError: false))
            .handle((ctx) async {
              if (!ctx.isValid) {
                ctx.res.json({
                  'errors': ctx.validationErrors['body']!
                      .map((e) => e.toJson())
                      .toList(),
                });
              } else {
                ctx.res.json({'ok': true});
              }
            });

        final res = await client.postJson('/users', {});

        expect(res, isOkResponse);
        expect(await res.json, hasJsonPath('errors', hasLength(1)));
      });
    });

    group('query validation', () {
      test('validates query parameters', () async {
        final schema = Schema({
          'page': V.isInt().defaultValue(1).min(1),
          'limit': V.isInt().defaultValue(10).max(100),
        });

        app.get('/items').use(Validator(query: schema)).handle((ctx) async {
          ctx.res.json({'query': ctx.validatedQuery});
        });

        final res = await client.get('/items?page=2&limit=20');

        expect(res, isOkResponse);
        final json = await res.json;
        expect(json, hasJsonPath('query.page', 2));
        expect(json, hasJsonPath('query.limit', 20));
      });

      test('applies default values', () async {
        final schema = Schema({
          'page': V.isInt().defaultValue(1),
          'limit': V.isInt().defaultValue(10),
        });

        app.get('/items').use(Validator(query: schema)).handle((ctx) async {
          ctx.res.json({'query': ctx.validatedQuery});
        });

        final res = await client.get('/items');

        expect(res, isOkResponse);
        final json = await res.json;
        expect(json, hasJsonPath('query.page', 1));
        expect(json, hasJsonPath('query.limit', 10));
      });
    });

    group('params validation', () {
      test('validates route parameters', () async {
        final schema = Schema({'id': V.isInt().required().min(1)});

        app.get('/users/:id').use(Validator(params: schema)).handle((
          ctx,
        ) async {
          ctx.res.json({'id': ctx.validatedParams!['id']});
        });

        final res = await client.get('/users/42');

        expect(res, isOkResponse);
        expect(await res.json, hasJsonPath('id', 42));
      });
    });

    group('combined validation', () {
      test('validates body, query, and params together', () async {
        final bodySchema = Schema({'title': V.isString().required()});
        final querySchema = Schema({'publish': V.isBool().defaultValue(false)});
        final paramsSchema = Schema({'userId': V.isInt().required()});

        app
            .post('/users/:userId/posts')
            .use(
              Validator(
                body: bodySchema,
                query: querySchema,
                params: paramsSchema,
              ),
            )
            .handle((ctx) async {
              ctx.res.json({
                'body': ctx.validatedBody,
                'query': ctx.validatedQuery,
                'params': ctx.validatedParams,
              });
            });

        final res = await client.postJson('/users/1/posts?publish=true', {
          'title': 'Hello World',
        });

        expect(res, isOkResponse);
        final json = await res.json;
        expect(json, hasJsonPath('body.title', 'Hello World'));
        expect(json, hasJsonPath('query.publish', isTrue));
        expect(json, hasJsonPath('params.userId', 1));
      });
    });
  });

  group('Context extension', () {
    late Chase app;
    late TestClient client;

    setUp(() async {
      app = Chase(dev: true);
      client = await TestClient.start(app);
    });

    tearDown(() async {
      await client.close();
    });

    test('validated returns empty map without validation', () async {
      app.get('/test').handle((ctx) async {
        ctx.res.json({'validated': ctx.validated});
      });

      final res = await client.get('/test');
      expect(await res.json, hasJsonPath('validated', isEmpty));
    });

    test('isValid returns true without validation', () async {
      app.get('/test').handle((ctx) async {
        ctx.res.json({'isValid': ctx.isValid});
      });

      final res = await client.get('/test');
      expect(await res.json, hasJsonPath('isValid', isTrue));
    });
  });
}
