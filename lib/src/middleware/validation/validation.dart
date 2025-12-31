import 'dart:async';

import 'package:chase/src/core/context/context.dart';
import 'package:chase/src/core/middleware.dart';
import 'package:chase/src/core/exception/http_exception.dart';

// -----------------------------------------------------------------------------
// Validation Result
// -----------------------------------------------------------------------------

/// Represents a validation error.
class ValidationError {
  /// The field path that failed validation.
  final String field;

  /// The error message.
  final String message;

  /// The rule that failed.
  final String rule;

  const ValidationError({
    required this.field,
    required this.message,
    required this.rule,
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'message': message,
        'rule': rule,
      };

  @override
  String toString() => '$field: $message';
}

/// Represents the result of a validation.
class ValidationResult {
  /// Whether the validation passed.
  final bool isValid;

  /// The validated and transformed data.
  final Map<String, dynamic> data;

  /// List of validation errors.
  final List<ValidationError> errors;

  const ValidationResult._({
    required this.isValid,
    required this.data,
    required this.errors,
  });

  /// Creates a successful validation result.
  factory ValidationResult.success(Map<String, dynamic> data) {
    return ValidationResult._(isValid: true, data: data, errors: const []);
  }

  /// Creates a failed validation result.
  factory ValidationResult.failure(List<ValidationError> errors) {
    return ValidationResult._(isValid: false, data: const {}, errors: errors);
  }

  /// Gets error messages grouped by field.
  Map<String, List<String>> get errorsByField {
    final map = <String, List<String>>{};
    for (final error in errors) {
      map.putIfAbsent(error.field, () => []).add(error.message);
    }
    return map;
  }
}

// -----------------------------------------------------------------------------
// Validation Rules
// -----------------------------------------------------------------------------

/// A validation rule that can be applied to a value.
typedef ValidationRule = ValidationError? Function(
    String field, dynamic value);

/// Builder for creating validation rules.
class V {
  final List<ValidationRule> _rules = [];
  final List<V Function(dynamic)>? _itemValidator;
  bool _isRequired = false;
  dynamic _defaultValue;
  dynamic Function(dynamic)? _transform;

  V._([this._itemValidator]);

  /// Creates a string validator.
  static V isString() => V._().._addTypeCheck('string', (v) => v is String);

  /// Creates an integer validator.
  static V isInt() => V._().._addTypeCheck('int', (v) {
        if (v is int) return true;
        if (v is String) return int.tryParse(v) != null;
        return false;
      }).._transform = (v) => v is int ? v : int.parse(v.toString());

  /// Creates a double/number validator.
  static V isDouble() => V._().._addTypeCheck('double', (v) {
        if (v is num) return true;
        if (v is String) return double.tryParse(v) != null;
        return false;
      }).._transform = (v) => v is double ? v : double.parse(v.toString());

  /// Creates a boolean validator.
  static V isBool() => V._().._addTypeCheck('bool', (v) {
        if (v is bool) return true;
        if (v is String) {
          final lower = v.toLowerCase();
          return lower == 'true' || lower == 'false' || lower == '1' || lower == '0';
        }
        return false;
      }).._transform = (v) {
        if (v is bool) return v;
        final s = v.toString().toLowerCase();
        return s == 'true' || s == '1';
      };

  /// Creates a list validator with optional item validation.
  static V list([V Function(dynamic)? itemValidator]) =>
      V._([if (itemValidator != null) itemValidator])
        .._addTypeCheck('list', (v) => v is List);

  /// Creates a map/object validator.
  static V map() => V._().._addTypeCheck('map', (v) => v is Map);

  /// Creates a validator that accepts any type.
  static V any() => V._();

  void _addTypeCheck(String typeName, bool Function(dynamic) check) {
    _rules.add((field, value) {
      if (value == null) return null; // handled by required
      if (!check(value)) {
        return ValidationError(
          field: field,
          message: 'must be a $typeName',
          rule: 'type',
        );
      }
      return null;
    });
  }

  /// Marks the field as required.
  V required() {
    _isRequired = true;
    _rules.insert(0, (field, value) {
      if (value == null || (value is String && value.isEmpty)) {
        return ValidationError(
          field: field,
          message: 'is required',
          rule: 'required',
        );
      }
      return null;
    });
    return this;
  }

  /// Sets a default value if the field is missing.
  V defaultValue(dynamic value) {
    _defaultValue = value;
    return this;
  }

  /// Minimum length for strings or minimum value for numbers.
  V min(num min) {
    _rules.add((field, value) {
      if (value == null) return null;
      if (value is String && value.length < min) {
        return ValidationError(
          field: field,
          message: 'must be at least $min characters',
          rule: 'min',
        );
      }
      if (value is num && value < min) {
        return ValidationError(
          field: field,
          message: 'must be at least $min',
          rule: 'min',
        );
      }
      if (value is List && value.length < min) {
        return ValidationError(
          field: field,
          message: 'must have at least $min items',
          rule: 'min',
        );
      }
      return null;
    });
    return this;
  }

  /// Maximum length for strings or maximum value for numbers.
  V max(num max) {
    _rules.add((field, value) {
      if (value == null) return null;
      if (value is String && value.length > max) {
        return ValidationError(
          field: field,
          message: 'must be at most $max characters',
          rule: 'max',
        );
      }
      if (value is num && value > max) {
        return ValidationError(
          field: field,
          message: 'must be at most $max',
          rule: 'max',
        );
      }
      if (value is List && value.length > max) {
        return ValidationError(
          field: field,
          message: 'must have at most $max items',
          rule: 'max',
        );
      }
      return null;
    });
    return this;
  }

  /// Exact length for strings or lists.
  V length(int length) {
    _rules.add((field, value) {
      if (value == null) return null;
      if (value is String && value.length != length) {
        return ValidationError(
          field: field,
          message: 'must be exactly $length characters',
          rule: 'length',
        );
      }
      if (value is List && value.length != length) {
        return ValidationError(
          field: field,
          message: 'must have exactly $length items',
          rule: 'length',
        );
      }
      return null;
    });
    return this;
  }

  /// Validates that the value matches a regex pattern.
  V pattern(RegExp regex, {String? message}) {
    _rules.add((field, value) {
      if (value == null) return null;
      if (value is! String || !regex.hasMatch(value)) {
        return ValidationError(
          field: field,
          message: message ?? 'has invalid format',
          rule: 'pattern',
        );
      }
      return null;
    });
    return this;
  }

  /// Validates email format.
  V email() {
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return pattern(emailRegex, message: 'must be a valid email');
  }

  /// Validates URL format.
  V url() {
    _rules.add((field, value) {
      if (value == null) return null;
      if (value is! String) {
        return ValidationError(
          field: field,
          message: 'must be a valid URL',
          rule: 'url',
        );
      }
      final uri = Uri.tryParse(value);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        return ValidationError(
          field: field,
          message: 'must be a valid URL',
          rule: 'url',
        );
      }
      return null;
    });
    return this;
  }

  /// Validates that the value is one of the allowed values.
  V oneOf(List<dynamic> allowed) {
    _rules.add((field, value) {
      if (value == null) return null;
      if (!allowed.contains(value)) {
        return ValidationError(
          field: field,
          message: 'must be one of: ${allowed.join(", ")}',
          rule: 'oneOf',
        );
      }
      return null;
    });
    return this;
  }

  /// Validates using a custom function.
  V custom(bool Function(dynamic value) validator, {required String message}) {
    _rules.add((field, value) {
      if (value == null) return null;
      if (!validator(value)) {
        return ValidationError(
          field: field,
          message: message,
          rule: 'custom',
        );
      }
      return null;
    });
    return this;
  }

  /// Validates the value and returns errors.
  List<ValidationError> validate(String field, dynamic value) {
    final errors = <ValidationError>[];

    // Apply default value
    if (value == null && _defaultValue != null) {
      value = _defaultValue;
    }

    // Run all rules
    for (final rule in _rules) {
      final error = rule(field, value);
      if (error != null) {
        errors.add(error);
        if (error.rule == 'required' || error.rule == 'type') {
          break; // Stop on critical errors
        }
      }
    }

    // Validate list items
    if (errors.isEmpty &&
        value is List &&
        _itemValidator != null &&
        _itemValidator.isNotEmpty) {
      for (var i = 0; i < value.length; i++) {
        final itemV = _itemValidator.first(value[i]);
        final itemErrors = itemV.validate('$field[$i]', value[i]);
        errors.addAll(itemErrors);
      }
    }

    return errors;
  }

  /// Transforms the value after validation.
  dynamic transform(dynamic value) {
    if (value == null) return _defaultValue;
    if (_transform != null) {
      return _transform!(value);
    }
    return value;
  }

  /// Whether the field is required.
  bool get isRequired => _isRequired;
}

// -----------------------------------------------------------------------------
// Schema
// -----------------------------------------------------------------------------

/// Defines a validation schema for structured data.
class Schema {
  final Map<String, V> _fields;

  /// Creates a schema with the given field validators.
  const Schema(this._fields);

  /// Validates data against this schema.
  ValidationResult validate(Map<String, dynamic>? data) {
    data ??= {};
    final errors = <ValidationError>[];
    final validated = <String, dynamic>{};

    for (final entry in _fields.entries) {
      final field = entry.key;
      final validator = entry.value;
      final value = data[field];

      final fieldErrors = validator.validate(field, value);
      errors.addAll(fieldErrors);

      if (fieldErrors.isEmpty) {
        final transformed = validator.transform(value);
        if (transformed != null || validator.isRequired) {
          validated[field] = transformed;
        }
      }
    }

    if (errors.isNotEmpty) {
      return ValidationResult.failure(errors);
    }

    return ValidationResult.success(validated);
  }

  /// Gets the field names in this schema.
  Iterable<String> get fields => _fields.keys;
}

// -----------------------------------------------------------------------------
// Validation Exception
// -----------------------------------------------------------------------------

/// Exception thrown when validation fails.
class ValidationException extends HttpException {
  /// The validation errors.
  final List<ValidationError> errors;

  ValidationException(this.errors) : super(422, 'Validation failed');

  /// Gets error messages grouped by field.
  Map<String, List<String>> get errorsByField {
    final map = <String, List<String>>{};
    for (final error in errors) {
      map.putIfAbsent(error.field, () => []).add(error.message);
    }
    return map;
  }

  /// Returns the errors as JSON.
  Map<String, dynamic> toJson() => {
        'message': message,
        'errors': errors.map((e) => e.toJson()).toList(),
      };
}

// -----------------------------------------------------------------------------
// Validator Middleware
// -----------------------------------------------------------------------------

/// Creates a validation middleware.
///
/// ## Example
///
/// ```dart
/// final userSchema = Schema({
///   'name': V.string().required().min(2),
///   'email': V.string().required().email(),
///   'age': V.int().min(18),
/// });
///
/// app.post('/users')
///   .use(Validator(body: userSchema))
///   .handle((ctx) async {
///     final data = ctx.validated['body']!;
///     // data is validated!
///   });
/// ```
class Validator implements Middleware {
  /// Schema for validating request body.
  final Schema? body;

  /// Schema for validating query parameters.
  final Schema? query;

  /// Schema for validating route parameters.
  final Schema? params;

  /// Whether to throw an exception on validation failure.
  /// If false, errors are stored in context and handler continues.
  final bool throwOnError;

  /// Creates a Validator middleware.
  const Validator({
    this.body,
    this.query,
    this.params,
    this.throwOnError = true,
  });

  @override
  FutureOr<void> handle(Context ctx, NextFunction next) async {
    final allErrors = <String, List<ValidationError>>{};
    final validated = <String, Map<String, dynamic>>{};

    // Validate body
    if (body != null) {
      Map<String, dynamic>? bodyData;
      try {
        bodyData = await ctx.req.json() as Map<String, dynamic>?;
      } catch (_) {
        bodyData = null;
      }

      final result = body!.validate(bodyData);
      if (!result.isValid) {
        allErrors['body'] = result.errors;
      } else {
        validated['body'] = result.data;
      }
    }

    // Validate query
    if (query != null) {
      final queryData = ctx.req.queries;
      final result = query!.validate(queryData);
      if (!result.isValid) {
        allErrors['query'] = result.errors;
      } else {
        validated['query'] = result.data;
      }
    }

    // Validate params
    if (params != null) {
      final paramsData = ctx.req.params;
      final result = params!.validate(paramsData);
      if (!result.isValid) {
        allErrors['params'] = result.errors;
      } else {
        validated['params'] = result.data;
      }
    }

    // Store validated data in context
    ctx.set('_validated', validated);
    ctx.set('_validation_errors', allErrors);

    // Handle errors
    if (allErrors.isNotEmpty && throwOnError) {
      final errors = allErrors.values.expand((e) => e).toList();
      throw ValidationException(errors);
    }

    return next();
  }
}

// -----------------------------------------------------------------------------
// Context Extension
// -----------------------------------------------------------------------------

/// Extension on Context for validation access.
extension ValidationContextExtension on Context {
  /// Gets validated data by source (body, query, params).
  Map<String, Map<String, dynamic>> get validated =>
      get<Map<String, Map<String, dynamic>>>('_validated') ?? {};

  /// Gets validation errors by source.
  Map<String, List<ValidationError>> get validationErrors =>
      get<Map<String, List<ValidationError>>>('_validation_errors') ?? {};

  /// Whether the request passed validation.
  bool get isValid => validationErrors.isEmpty;

  /// Gets validated body data.
  Map<String, dynamic>? get validatedBody => validated['body'];

  /// Gets validated query data.
  Map<String, dynamic>? get validatedQuery => validated['query'];

  /// Gets validated params data.
  Map<String, dynamic>? get validatedParams => validated['params'];
}
