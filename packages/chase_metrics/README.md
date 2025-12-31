# chase_metrics

Prometheus-style metrics plugin for [Chase](https://pub.dev/packages/chase) framework.

## Installation

```yaml
dependencies:
  chase: ^0.0.1
  chase_metrics: ^0.0.1
```

## Quick Start

```dart
import 'package:chase/chase.dart';
import 'package:chase_metrics/chase_metrics.dart';

void main() async {
  final app = Chase()
    ..plugin(MetricsPlugin());

  app.get('/').handle((ctx) => ctx.res.text('Hello!'));

  await app.start(port: 3000);
}
```

Metrics are available at `GET /metrics`.

## Collected Metrics

### `http_requests_total` (Counter)

Total number of HTTP requests.

Labels:
- `method` - HTTP method (GET, POST, etc.)
- `path` - Request path (normalized)
- `status` - Response status code

### `http_request_duration_seconds` (Histogram)

Request duration in seconds.

Labels: Same as `http_requests_total`

Buckets: 5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 2.5s, 5s, 10s

## Configuration

```dart
final app = Chase()
  ..plugin(MetricsPlugin(
    path: '/metrics',  // Default: /metrics
  ));
```

## Output Format

Prometheus text format (version 0.0.4):

```
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/",status="200"} 42

# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.005",method="GET",path="/",status="200"} 10
http_request_duration_seconds_bucket{le="0.01",method="GET",path="/",status="200"} 25
...
http_request_duration_seconds_bucket{le="+Inf",method="GET",path="/",status="200"} 42
http_request_duration_seconds_sum{method="GET",path="/",status="200"} 0.523
http_request_duration_seconds_count{method="GET",path="/",status="200"} 42
```

## Path Normalization

Dynamic path segments are normalized to prevent high cardinality:

| Request Path | Normalized Path |
|--------------|-----------------|
| `/users/123` | `/users/:id` |
| `/users/abc-def-123` | `/users/:id` |
| `/posts/550e8400-e29b-41d4-a716-446655440000` | `/posts/:id` |

## Using with Prometheus

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'chase-app'
    static_configs:
      - targets: ['localhost:3000']
    metrics_path: '/metrics'
```

## Custom Metrics

Access the `Metrics` instance for custom metrics:

```dart
final metrics = Metrics();
final plugin = MetricsPlugin(metrics: metrics);

app.plugin(plugin);

// In your handler
app.post('/orders').handle((ctx) async {
  // ... process order
  metrics.increment('orders_created_total', labels: {'type': 'standard'});
  ctx.res.json({'ok': true});
});
```

## API

### `MetricsPlugin`

```dart
MetricsPlugin({
  String path = '/metrics',  // Endpoint path
  Metrics? metrics,          // Custom Metrics instance
})
```

### `Metrics`

```dart
// Increment a counter
metrics.increment('name', labels: {'key': 'value'});

// Record histogram observation
metrics.observe('name', 0.5, labels: {'key': 'value'});

// Export all metrics
String output = metrics.export();

// Reset all metrics
metrics.reset();
```

## License

MIT
