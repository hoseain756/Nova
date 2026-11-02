import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NovaProfile {
  const NovaProfile({
    required this.id,
    required this.name,
    required this.avatarKind,
    required this.avatarValue,
    required this.hasPin,
  });

  final String id;
  final String name;
  final String avatarKind;
  final String avatarValue;
  final bool hasPin;

  factory NovaProfile.fromJson(Map<String, dynamic> json) => NovaProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarKind: json['avatar_kind'] as String? ?? 'pack',
        avatarValue: json['avatar_value'] as String? ?? 'nova_avatar_01_smile',
        hasPin: json['has_pin'] as bool? ?? false,
      );
}

/// Auth and profile state shared by the launch gate and Settings.
/// Database authorization remains entirely server side.
class AccountController extends ChangeNotifier {
  AccountController(this._client) {
    _authSubscription = _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        passwordRecoveryPending = true;
        notifyListeners();
      }
      unawaited(refresh());
      unawaited(_saveCurrentSession());
    });
  }

  final SupabaseClient _client;
  static const _secure = FlutterSecureStorage();
  static const _guestIdKey = 'nova.auth.saved-guest-id';
  static const _pendingUsernameKey = 'nova.auth.pending-username';
  static const _pendingUpgradeUsernameKey = 'nova.auth.upgrade-username';
  static const _avatarNames = [
    'smile',
    'surprised',
    'sleepy',
    'laughing',
    'cool',
    'love',
    'tongue',
    'excited',
    'wink',
  ];
  StreamSubscription<AuthState>? _authSubscription;
  bool busy = false;
  String? error;
  String? username;
  String? defaultProfileId;
  String? activeProfileId;
  String? _loadedUserId;
  String? _pendingUpgradeUserId;
  bool profilesReady = false;
  List<NovaProfile> profiles = const [];
  bool awaitingEmailConfirmation = false;
  bool awaitingGuestUpgradeVerification = false;
  bool guestEmailVerified = false;
  bool passwordRecoveryPending = false;

  User? get user => _client.auth.currentUser;
  bool get isGuest => user?.isAnonymous ?? false;
  bool get signedIn => user != null;
  bool get hasSavedGuest => _savedGuestId != null;
  bool get guestUpgradePending =>
      _pendingUpgradeUserId != null && _pendingUpgradeUserId == user?.id;
  String? _savedGuestId;

  Future<void> initialize() async {
    _savedGuestId = await _secure.read(key: _guestIdKey);
    final upgrade = await _secure.read(key: _pendingUpgradeUsernameKey);
    if (upgrade != null) {
      try {
        _pendingUpgradeUserId =
            (jsonDecode(upgrade) as Map<String, dynamic>)['id'] as String?;
      } catch (_) {
        await _secure.delete(key: _pendingUpgradeUsernameKey);
      }
    }
    await refresh();
  }

  Future<void> refresh() async {
    final current = user;
    if (_loadedUserId != current?.id) {
      _loadedUserId = current?.id;
      username = null;
      defaultProfileId = null;
      activeProfileId = null;
      profiles = const [];
      profilesReady = false;
      notifyListeners();
    }
    if (current == null) {
      username = null;
      defaultProfileId = null;
      activeProfileId = null;
      profiles = const [];
      profilesReady = false;
      notifyListeners();
      return;
    }
    try {
      final account = await _client
          .from('accounts')
          .select('username,default_profile_id')
          .eq('id', current.id)
          .maybeSingle();
      final rows = await _client
          .from('profiles')
          .select('id,name,avatar_kind,avatar_value,has_pin')
          .eq('account_id', current.id)
          .order('created_at');
      if (user?.id != current.id) return;
      username = account?['username'] as String?;
      defaultProfileId = account?['default_profile_id'] as String?;
      profiles = (rows as List)
          .map((row) => NovaProfile.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      if (!profiles.any((p) => p.id == activeProfileId)) {
        activeProfileId = null;
      }
      if (!current.isAnonymous && username == null) {
        await _applyPendingUsername();
      }
      profilesReady = true;
      error = null;
      notifyListeners();
    } catch (_) {
      error = 'accountUnavailable';
      profilesReady = false;
      notifyListeners();
    }
  }

  Future<void> _saveCurrentSession() async {
    final session = _client.auth.currentSession;
    if (session == null) return;
    await _secure.write(
      key: 'nova.auth.session.${session.user.id}',
      value: session.refreshToken,
    );
    if (session.user.isAnonymous) {
      _savedGuestId = session.user.id;
      await _secure.write(key: _guestIdKey, value: session.user.id);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await operation();
    } on AuthException {
      error = 'authFailed';
    } on PostgrestException {
      error = 'accountUnavailable';
    } catch (_) {
      error = 'networkUnavailable';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String identifier, String password) => _run(() async {
        final normalized = identifier.trim();
        if (normalized.contains('@')) {
          await _client.auth
              .signInWithPassword(email: normalized, password: password);
        } else {
          final response = await _client.functions.invoke('auth-login', body: {
            'identifier': normalized,
            'password': password,
          });
          if (response.status != 200 || response.data is! Map) {
            throw const AuthException('Invalid credentials');
          }
          final body = Map<String, dynamic>.from(response.data as Map);
          await _client.auth.setSession(body['refresh_token'] as String);
        }
        activeProfileId = null;
        await _saveCurrentSession();
        await refresh();
      });

  Future<void> signUp(String name, String email, String password) =>
      _run(() async {
        final result = await _client.auth.signUp(
          email: email.trim(),
          password: password,
          emailRedirectTo: 'app.noor.mobile://callback?nova_auth=confirm',
        );
        if (result.user != null) {
          await _secure.write(
            key: _pendingUsernameKey,
            value: jsonEncode({
              'id': result.user!.id,
              'email': email.trim().toLowerCase(),
              'username': name.trim().toLowerCase(),
            }),
          );
        }
        awaitingEmailConfirmation = result.session == null;
        if (result.session != null) {
          await _applyPendingUsername();
          await refresh();
        }
      });

  Future<void> _applyPendingUsername() async {
    final raw = await _secure.read(key: _pendingUsernameKey);
    final current = user;
    if (raw == null || current == null || current.isAnonymous) return;
    Map<String, dynamic> pending;
    try {
      pending = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      await _secure.delete(key: _pendingUsernameKey);
      return;
    }
    if (pending['id'] != current.id ||
        pending['email'] != current.email?.toLowerCase()) {
      return;
    }
    try {
      await _client
          .rpc('set_username', params: {'p_username': pending['username']});
      await _secure.delete(key: _pendingUsernameKey);
      username = pending['username'] as String?;
    } on PostgrestException {
      error = 'usernameUnavailable';
    }
  }

  Future<void> continueAsGuest() => _run(() async {
        if (_savedGuestId != null) {
          final token =
              await _secure.read(key: 'nova.auth.session.$_savedGuestId');
          if (token == null) throw StateError('Guest session unavailable');
          await _client.auth.setSession(token);
        } else {
          await _client.auth.signInAnonymously();
        }
        await _saveCurrentSession();
        await refresh();
      });

  Future<void> sendPasswordReset(String email) => _run(() async {
        await _client.auth.resetPasswordForEmail(
          email.trim(),
          redirectTo: 'app.noor.mobile://callback?nova_auth=recovery',
        );
      });

  Future<void> setRecoveredPassword(String password) => _run(() async {
        await _client.auth.updateUser(UserAttributes(password: password));
        passwordRecoveryPending = false;
      });

  Future<void> setUsername(String value) => _run(() async {
        await _client.rpc('set_username',
            params: {'p_username': value.trim().toLowerCase()});
        await refresh();
      });

  Future<void> checkEmailVerification() => _run(() async {
        final current = _client.auth.currentUser;
        if (current == null) return;
        final verified = await _client.auth.getUser();
        if (verified.user?.emailConfirmedAt != null) {
          awaitingEmailConfirmation = false;
          guestEmailVerified = true;
        }
        await refresh();
      });

  void cancelEmailWait() {
    awaitingEmailConfirmation = false;
    notifyListeners();
  }

  Future<void> beginGuestUpgrade(String name, String email) => _run(() async {
        if (!isGuest) return;
        final guestId = user!.id;
        await _client.auth.updateUser(
          UserAttributes(email: email.trim()),
          emailRedirectTo: 'app.noor.mobile://callback?nova_auth=confirm',
        );
        await _secure.write(
          key: _pendingUpgradeUsernameKey,
          value: jsonEncode({
            'id': guestId,
            'email': email.trim().toLowerCase(),
            'username': name.trim().toLowerCase(),
          }),
        );
        _pendingUpgradeUserId = guestId;
        awaitingGuestUpgradeVerification = true;
        guestEmailVerified = false;
      });

  Future<void> finishGuestUpgrade(String password) => _run(() async {
        final verified = await _client.auth.getUser();
        if (verified.user?.emailConfirmedAt == null) {
          error = 'verifyEmailFirst';
          return;
        }
        await _client.auth.updateUser(UserAttributes(password: password));
        final raw = await _secure.read(key: _pendingUpgradeUsernameKey);
        String? pendingUsername;
        if (raw != null) {
          final pending = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          if (pending['id'] != verified.user?.id ||
              pending['email'] != verified.user?.email?.toLowerCase()) {
            throw StateError('Upgrade identity changed');
          }
          pendingUsername = pending['username'] as String?;
        }
        awaitingGuestUpgradeVerification = false;
        guestEmailVerified = false;
        await _secure.delete(key: _guestIdKey);
        _savedGuestId = null;
        await _secure.delete(key: _pendingUpgradeUsernameKey);
        _pendingUpgradeUserId = null;
        if (pendingUsername != null) {
          try {
            await _client
                .rpc('set_username', params: {'p_username': pendingUsername});
          } on PostgrestException {
            // The account is already permanent. The launch gate will ask for
            // another username if the selected one was taken in the interim.
          }
        }
        await refresh();
      });

  Future<void> switchToSavedGuest() => _run(() async {
        final guestId = await _secure.read(key: _guestIdKey);
        if (guestId == null) return;
        final refreshToken =
            await _secure.read(key: 'nova.auth.session.$guestId');
        if (refreshToken == null) return;
        await _client.auth.setSession(refreshToken);
        activeProfileId = null;
        await refresh();
      });

  Future<void> signOut() => _run(() async {
        final id = user?.id;
        await _client.auth.signOut(scope: SignOutScope.local);
        if (id != null) {
          await _secure.delete(key: 'nova.auth.session.$id');
        }
        activeProfileId = null;
        await refresh();
      });

  Future<NovaProfile?> createProfile({
    required String name,
    String? avatarPackKey,
    String? avatarUrl,
    String? pin,
    bool setAsDefault = false,
  }) async {
    error = null;
    try {
      final kind = avatarUrl == null ? 'pack' : 'url';
      final avatarIndex = Random.secure().nextInt(_avatarNames.length);
      final value = avatarUrl ??
          avatarPackKey ??
          'nova_avatar_${(avatarIndex + 1).toString().padLeft(2, '0')}_${_avatarNames[avatarIndex]}';
      final created = await _client.rpc('create_profile', params: {
        'p_name': name.trim(),
        'p_avatar_kind': kind,
        'p_avatar_value': value,
        'p_pin': pin?.isEmpty == true ? null : pin,
        'p_set_default': setAsDefault,
      });
      final id = created is Map ? created['id'] as String? : created as String?;
      if (id == null) throw StateError('Invalid profile response');
      await refresh();
      return profiles.where((p) => p.id == id).firstOrNull;
    } catch (_) {
      error = 'profileSaveFailed';
      notifyListeners();
      return null;
    }
  }

  Future<void> updateProfile(String id,
          {required String name, String? avatarPackKey, String? avatarUrl}) =>
      _run(() async {
        await _client.rpc('update_profile', params: {
          'p_profile_id': id,
          'p_name': name.trim(),
          'p_avatar_kind': avatarUrl == null ? 'pack' : 'url',
          'p_avatar_value': avatarUrl ?? avatarPackKey,
        });
        await refresh();
      });

  Future<void> deleteProfile(String id) => _run(() async {
        await _client.rpc('delete_profile', params: {'p_profile_id': id});
        await refresh();
      });

  Future<void> setDefaultProfile(String? id) => _run(() async {
        await _client.rpc('set_default_profile', params: {'p_profile_id': id});
        await refresh();
      });

  Future<void> setProfilePin(String id, String? oldPin, String? newPin) =>
      _run(() async {
        final result = await _client.rpc('set_profile_pin', params: {
          'p_profile_id': id,
          'p_old_pin': oldPin,
          'p_new_pin': newPin,
        });
        if (result != true) {
          error = 'profileUnlockFailed';
          return;
        }
        await refresh();
      });

  /// Verifies a locked profile without changing the selected viewer.
  /// Attempt limits and PIN hashing are enforced by the database RPC.
  Future<bool> verifyProfilePin(String id, String pin) async {
    final profile = profiles.where((p) => p.id == id).firstOrNull;
    if (profile == null || !profile.hasPin) return false;
    try {
      return await _client.rpc('verify_profile_pin', params: {
            'p_profile_id': id,
            'p_pin': pin,
          }) ==
          true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> selectProfile(String id, {String? pin}) async {
    final profile = profiles.where((p) => p.id == id).firstOrNull;
    if (profile == null) return false;
    if (profile.hasPin) {
      if (pin == null) return false;
      if (!await verifyProfilePin(id, pin)) return false;
    }
    activeProfileId = id;
    notifyListeners();
    return true;
  }

  void leaveProfile() {
    activeProfileId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
