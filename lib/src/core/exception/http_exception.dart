/// Custom HTTP exception with status code support for Chase framework.
///
/// This exception allows you to throw HTTP errors with specific status codes
/// that will be properly handled by ExceptionHandler middleware.
///
/// Example:
/// ```dart
/// throw HttpException(404, 'User not found');
/// ```
class HttpException implements Exception {
  /// HTTP status code (e.g., 404, 500, 401)
  final int statusCode;

  /// Error message
  final String message;

  /// Creates an HTTP exception with the given status code and message
  const HttpException(this.statusCode, this.message);

  @override
  String toString() => 'HttpException($statusCode): $message';
}

/// 400 Bad Request - The request was invalid or cannot be served
class BadRequestException extends HttpException {
  const BadRequestException(String message) : super(400, message);
}

/// 401 Unauthorized - Authentication is required and has failed or not been provided
class UnauthorizedException extends HttpException {
  const UnauthorizedException(String message) : super(401, message);
}

/// 403 Forbidden - The request is valid but the server is refusing action
class ForbiddenException extends HttpException {
  const ForbiddenException(String message) : super(403, message);
}

/// 404 Not Found - The requested resource could not be found
class NotFoundException extends HttpException {
  const NotFoundException(String message) : super(404, message);
}

/// 409 Conflict - The request conflicts with the current state of the server
class ConflictException extends HttpException {
  const ConflictException(String message) : super(409, message);
}

/// 500 Internal Server Error - A generic error occurred on the server
class InternalServerErrorException extends HttpException {
  const InternalServerErrorException(String message) : super(500, message);
}

/// 503 Service Unavailable - The server is not ready to handle the request
class ServiceUnavailableException extends HttpException {
  const ServiceUnavailableException(String message) : super(503, message);
}
