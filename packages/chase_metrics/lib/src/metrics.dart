/// Metrics collector for Chase applications.
///
/// Collects HTTP request metrics in Prometheus format.
class Metrics {
  final Map<String, _Counter> _counters = {};
  final Map<String, _Histogram> _histograms = {};

  /// Increments a counter metric.
  void increment(String name, {Map<String, String>? labels}) {
    final key = _key(name, labels);
    _counters.putIfAbsent(key, () => _Counter(name, labels ?? {}));
    _counters[key]!.increment();
  }

  /// Records a value in a histogram metric.
  void observe(String name, double value, {Map<String, String>? labels}) {
    final key = _key(name, labels);
    _histograms.putIfAbsent(
      key,
      () => _Histogram(name, labels ?? {}, _defaultBuckets),
    );
    _histograms[key]!.observe(value);
  }

  /// Exports all metrics in Prometheus text format.
  String export() {
    final buffer = StringBuffer();

    // Export counters
    for (final counter in _counters.values) {
      buffer.writeln('# TYPE ${counter.name} counter');
      buffer.writeln(
        '${counter.name}${_formatLabels(counter.labels)} ${counter.value}',
      );
    }

    // Export histograms
    for (final histogram in _histograms.values) {
      buffer.writeln('# TYPE ${histogram.name} histogram');

      var cumulative = 0;
      for (final bucket in histogram.buckets.keys.toList()..sort()) {
        cumulative += histogram.buckets[bucket]!;
        final le = bucket == double.infinity ? '+Inf' : bucket.toString();
        buffer.writeln(
          '${histogram.name}_bucket${_formatLabels({...histogram.labels, 'le': le})} $cumulative',
        );
      }
      buffer.writeln(
        '${histogram.name}_sum${_formatLabels(histogram.labels)} ${histogram.sum}',
      );
      buffer.writeln(
        '${histogram.name}_count${_formatLabels(histogram.labels)} ${histogram.count}',
      );
    }

    return buffer.toString();
  }

  /// Resets all metrics.
  void reset() {
    _counters.clear();
    _histograms.clear();
  }

  String _key(String name, Map<String, String>? labels) {
    if (labels == null || labels.isEmpty) return name;
    final sortedLabels = labels.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '$name{${sortedLabels.map((e) => '${e.key}="${e.value}"').join(',')}}';
  }

  String _formatLabels(Map<String, String> labels) {
    if (labels.isEmpty) return '';
    final entries = labels.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '{${entries.map((e) => '${e.key}="${e.value}"').join(',')}}';
  }

  static const _defaultBuckets = [
    0.005,
    0.01,
    0.025,
    0.05,
    0.1,
    0.25,
    0.5,
    1.0,
    2.5,
    5.0,
    10.0,
  ];
}

class _Counter {
  final String name;
  final Map<String, String> labels;
  int value = 0;

  _Counter(this.name, this.labels);

  void increment() => value++;
}

class _Histogram {
  final String name;
  final Map<String, String> labels;
  final Map<double, int> buckets;
  double sum = 0;
  int count = 0;

  _Histogram(this.name, this.labels, List<double> bucketBoundaries)
    : buckets = {for (final b in bucketBoundaries) b: 0, double.infinity: 0};

  void observe(double value) {
    sum += value;
    count++;
    for (final boundary in buckets.keys) {
      if (value <= boundary) {
        buckets[boundary] = buckets[boundary]! + 1;
        break;
      }
    }
  }
}
