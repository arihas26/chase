# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-01-06

### Fixed
- **Timeout Middleware** - Fixed response handling pattern for proper middleware chain integration
- **RateLimit Middleware** - Fixed response handling pattern for proper middleware chain integration
- **BodyLimit Middleware** - Fixed response handling pattern for proper middleware chain integration
- **ExceptionHandler Middleware** - Fixed response handling pattern for proper middleware chain integration

### Added
- **Testing Utilities** - Added `runMiddleware` helper function for testing middleware that returns `Response` objects
- **Integration Tests** - Added tests for middleware behavior in `path()` route groups

## [0.1.1] - 2026-01-05

### Fixed
- **CORS Middleware** - Fixed response handling to use `Response` objects instead of directly calling `ctx.res.close()`
- **Documentation** - Fixed image URLs and formatting in README

### Changed
- **Package** - Added `docs/` to `.pubignore` to reduce package size

## [0.1.0] - 2025-12-30

### Added

#### Core
- **Chase** - Main application class with routing and middleware support
- **Context** - Request/response context with store for data sharing
- **Router** - Trie-based router for optimal performance, regex-based router for flexibility
- **Middleware** - Flexible middleware system (global, group, route-level)
- **Plugin** - Plugin system for extending functionality
- **Route Groups** - Nested route groups with `path()` and `routes()`

#### Request/Response
- JSON, text, HTML response helpers
- JSON, form data, multipart request parsing
- Cookie management (set, get, delete)
- Header manipulation
- Redirect support
- Query parameter parsing
- Route parameter extraction

#### Real-time
- **WebSocket** - Full WebSocket support with upgrade handling
- **SSE** - Server-Sent Events for real-time updates
- **Streaming** - Text and binary streaming responses

#### Middleware (18+)
- **Authentication**
  - `BasicAuth` - HTTP Basic authentication
  - `BearerAuth` - Bearer token authentication
  - `JwtAuth` - JWT authentication with claims validation
- **Security**
  - `Cors` - Cross-Origin Resource Sharing
  - `Csrf` - CSRF protection with token validation
  - `SecureHeaders` - Security headers (CSP, HSTS, X-Frame-Options, etc.)
  - `RateLimit` - Request rate limiting with configurable windows
  - `BodyLimit` - Request body size limiting
- **Performance**
  - `Compress` - Gzip/Deflate compression
  - `CacheControl` - Cache-Control header management
  - `ETag` - Entity tag support for caching
  - `Timeout` - Request timeout handling
- **Utilities**
  - `Logger` - Request/response logging with levels
  - `RequestId` - Unique request ID generation
  - `ExceptionHandler` - Centralized error handling
  - `Session` - Session management with pluggable stores
  - `I18n` - Internationalization support
  - `Validator` - Schema-based request validation
  - `Proxy` - HTTP proxy middleware
  - `StaticFileHandler` - Static file serving

#### Validation
- **Schema** - Define validation schemas for structured data
- **V (Validator Builder)** - Fluent API for building validators
  - Type validators: `isString()`, `isInt()`, `isDouble()`, `isBool()`, `list()`, `map()`, `any()`
  - String rules: `required()`, `min()`, `max()`, `length()`, `email()`, `url()`, `pattern()`, `oneOf()`
  - Number rules: `min()`, `max()`
  - List rules: `min()`, `max()` items
  - Custom validation: `custom()`
  - Default values: `defaultValue()`
- Validate body, query, and route parameters
- Automatic type transformation (string to int, bool, etc.)
- Detailed error messages with field paths

#### Internationalization (i18n)
- **I18nTranslations** - Load translations from maps or YAML files
- **I18n middleware** - Automatic locale detection
- Locale detection from query params and Accept-Language header
- Variable interpolation in translations
- Fallback to default locale

#### Testing
- **TestClient** - HTTP client for integration testing
- **TestContext** - Mock context for unit testing
- **TestResponse** - Response wrapper with helper methods
- **Custom Matchers**
  - Status: `isOkResponse`, `isRedirectResponse`, `isClientErrorResponse`, `isServerErrorResponse`, `hasStatus()`
  - Headers: `hasHeader()`, `hasContentType()`
  - JSON: `hasJsonPath()` with nested path support
  - Cookies: `hasCookie()`
- **Extensions**
  - `getWithAuth()` - GET with Bearer token
  - `postJson()` - POST with JSON body

#### Static Files
- `staticFiles()` - Convenience method for serving static files
- `StaticFileHandler` - Middleware for static file serving
- `StaticOptions` - Configuration for caching, ETags, index files

### Changed
- N/A (initial release)

### Deprecated
- N/A (initial release)

### Removed
- N/A (initial release)

### Fixed
- N/A (initial release)

### Security
- N/A (initial release)

## [Unreleased]

### Planned
- OpenAPI/Swagger documentation generation
- GraphQL adapter
- HTML templating support
- CLI tools for scaffolding
- Additional session stores (Redis, etc.)
