/// Authenticated, account and profile scoped Supabase synchronization.
/// The installation UUID remains local and is never an authentication secret.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class NoorSyncService {
  NoorSyncService._();

  static final NoorSyncService instance = NoorSyncService._();
  factory NoorSyncService() => instance;

  static const String bucketSettings = 'settings';
  static const String bucketLibrary = 'library';
  static const String bucketLists = 'lists';
  static const String bucketWatchlist = 'watchlist';
  static const String bucketHistory = 'history';
  static const String bucketAddons = 'addons';

  static const List<String> buckets = <String>[
    bucketSettings,
    bucketLibrary,
    bucketLists,
    bucketWatchlist,
    bucketHistory,
    bucketAddons,
  ];

  static const Set<String> _accountBuckets = {bucketSettings, bucketAddons};
  static const String _deviceIdKey = 'noor.device.id';

  String? _accountId;
  String? _profileId;
  String? _deviceId;
  final Map<String, int> _lastKnownRev = {};
  final Set<String> _conflictedBuckets = {};

  String? get accountId => _accountId;
  String? get profileId => _profileId;
  bool get hasScope => _accountId != null && _profileId != null;

  /// Called only after Auth and profile selection have succeeded.
  void bindScope({required String accountId, required String profileId}) {
    if (_accountId == accountId && _profileId == profileId) return;
    _accountId = accountId;
    _profileId = profileId;
    _lastKnownRev.clear();
    _conflictedBuckets.clear();
  }

  void clearScope() {
    _accountId = null;
    _profileId = null;
    _lastKnownRev.clear();
    _conflictedBuckets.clear();
  }

  /// A legacy installation marker for an explicit local-data import only.
  /// Never pass this value to Supabase as proof of account ownership.
  Future<String?> deviceId() async {
    final cached = _deviceId;
    if (cached != null) return cached;
    try {
      const storage = FlutterSecureStorage();
      var id = await storage.read(key: _deviceIdKey);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await storage.write(key: _deviceIdKey, value: id);
      }
      return _deviceId = id;
    } catch (_) {
      return null;
    }
  }

  int? lastKnownRev(String bucket) => _lastKnownRev[bucket];

  bool takeConflict(String bucket) => _conflictedBuckets.remove(bucket);

  bool _authorized() =>
      hasScope && Supabase.instance.client.auth.currentUser?.id == _accountId;

  String _table(String bucket) =>
      _accountBuckets.contains(bucket) ? 'account_buckets' : 'profile_buckets';

  String _ownerColumn(String bucket) =>
      _accountBuckets.contains(bucket) ? 'account_id' : 'profile_id';

  String _ownerId(String bucket) =>
      _accountBuckets.contains(bucket) ? _accountId! : _profileId!;

  Future<Map<String, dynamic>?> pullBucket(String bucket) async {
    return (await readBucket(bucket)).row;
  }

  /// Separates a missing cloud row from a failed request. Automatic refresh
  /// must never seed old local data merely because the device is offline.
  Future<({bool reachedServer, Map<String, dynamic>? row})> readBucket(
      String bucket) async {
    if (!_authorized() || !buckets.contains(bucket)) {
      return (reachedServer: false, row: null);
    }
    try {
      final row = await Supabase.instance.client
          .from(_table(bucket))
          .select('data,rev,updated_at')
          .eq(_ownerColumn(bucket), _ownerId(bucket))
          .eq('bucket', bucket)
          .maybeSingle();
      if (row == null) return (reachedServer: true, row: null);
      final rev = (row['rev'] as num?)?.toInt() ?? 0;
      _lastKnownRev[bucket] = rev;
      return (
        reachedServer: true,
        row: {'data': row['data'], 'rev': rev, 'updated_at': row['updated_at']},
      );
    } catch (_) {
      return (reachedServer: false, row: null);
    }
  }

  Future<bool> pushBucket(String bucket, Map<String, dynamic> data) async {
    if (!_authorized() || !buckets.contains(bucket)) return false;
    try {
      final expectedRev = _lastKnownRev[bucket] ?? 0;
      final result = await Supabase.instance.client.rpc(
        _accountBuckets.contains(bucket)
            ? 'save_account_bucket'
            : 'save_profile_bucket',
        params: {
          if (!_accountBuckets.contains(bucket)) 'p_profile_id': _profileId,
          'p_bucket': bucket,
          'p_data': data,
          'p_expected_rev': expectedRev,
        },
      );
      final row = result is List ? result.firstOrNull : result;
      if (row is! Map) return false;
      final rev = (row['rev'] as num?)?.toInt();
      if (rev == null) return false;
      _lastKnownRev[bucket] = rev;
      _conflictedBuckets.remove(bucket);
      return true;
    } catch (error) {
      if (error is PostgrestException && error.code == '40001') {
        _conflictedBuckets.add(bucket);
      }
      // Do not log payloads, account identifiers, or backend error details.
      return false;
    }
  }

  Future<int?> bucketRev(String bucket) async =>
      (await pullBucket(bucket))?['rev'] as int?;

  Future<DateTime?> lastSyncAt(String bucket) async {
    if (!_authorized() || !buckets.contains(bucket)) return null;
    try {
      final row = await Supabase.instance.client
          .from(_table(bucket))
          .select('updated_at')
          .eq(_ownerColumn(bucket), _ownerId(bucket))
          .eq('bucket', bucket)
          .maybeSingle();
      final raw = row?['updated_at'];
      return raw is String ? DateTime.tryParse(raw) : null;
    } catch (_) {
      return null;
    }
  }

  /// Session presence replaces the old device heartbeat table.
  Future<void> heartbeat() async {}

  Future<bool> deleteBucket(String bucket) async {
    if (!_authorized() || !buckets.contains(bucket)) return false;
    try {
      await Supabase.instance.client
          .from(_table(bucket))
          .delete()
          .eq(_ownerColumn(bucket), _ownerId(bucket))
          .eq('bucket', bucket);
      _lastKnownRev.remove(bucket);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> close() async => clearScope();
}
