import 'dart:collection';

/// Three-way merge for the existing JSON bucket shapes. A change made on just
/// one side wins; simultaneous edits to the same field favor this device.
/// Collections merge by stable item identity instead of array position.
Map<String, dynamic> mergeBucketPayload({
  required String bucket,
  required Map<String, dynamic> base,
  required Map<String, dynamic> local,
  required Map<String, dynamic> remote,
}) =>
    _mergeValue(bucket, base, local, remote) as Map<String, dynamic>;

const _absent = _Absent();

class _Absent {
  const _Absent();
}

Object? _mergeValue(String field, Object? base, Object? local, Object? remote) {
  if (_same(local, base)) return remote;
  if (_same(remote, base) || _same(local, remote)) return local;
  if (local is Map && remote is Map) {
    final b = base is Map ? base : const {};
    final out = <String, dynamic>{};
    final keys = <String>{
      ...b.keys.map((key) => key.toString()),
      ...local.keys.map((key) => key.toString()),
      ...remote.keys.map((key) => key.toString()),
    };
    for (final key in keys) {
      final value = _mergeValue(
        key,
        b.containsKey(key) ? b[key] : _absent,
        local.containsKey(key) ? local[key] : _absent,
        remote.containsKey(key) ? remote[key] : _absent,
      );
      if (value is! _Absent) out[key] = value;
    }
    return out;
  }
  if (local is List && remote is List) {
    final localRows = _indexed(field, local);
    final remoteRows = _indexed(field, remote);
    final baseRows = _indexed(field, base is List ? base : const []);
    if (localRows != null && remoteRows != null && baseRows != null) {
      final out = <dynamic>[];
      final ids = LinkedHashSet<String>.from(localRows.keys)
        ..addAll(remoteRows.keys)
        ..addAll(baseRows.keys);
      for (final id in ids) {
        final value = _mergeValue(
          field,
          baseRows[id] ?? _absent,
          localRows[id] ?? _absent,
          remoteRows[id] ?? _absent,
        );
        if (value is! _Absent) out.add(value);
      }
      return out;
    }
  }
  return local;
}

Map<String, Object?>? _indexed(String field, List rows) {
  final out = <String, Object?>{};
  for (final row in rows) {
    if (row is! Map) return null;
    final id = field == 'history'
        ? '${row['id']}:${row['videoId'] ?? ''}:${row['season'] ?? ''}:${row['episode'] ?? ''}'
        : row['id']?.toString();
    if (id == null || id.isEmpty || out.containsKey(id)) return null;
    out[id] = row;
  }
  return out;
}

bool _same(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_same(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_same(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
