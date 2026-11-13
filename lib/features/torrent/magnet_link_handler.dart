import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

import '../../core/api/noor_api.dart';
import '../../core/auth/account_controller.dart';
import '../../core/oauth/oauth_redirect.dart';
import '../../core/shared_collections/invite_link.dart';
import '../../core/shared_collections/shared_collections_service.dart';
import '../../core/watch_party/watch_party_invite.dart';
import '../watch_party/watch_party_join_dialog.dart';
import '../watch_party/watch_party_page.dart';
import '../../core/state/app_state.dart';
import '../../shared/widgets/noor_toast.dart';
import '../../shared/widgets/nova_parental_gate.dart';
import '../shared_collections/shared_collection_detail_page.dart';
import 'magnet_opener.dart';

/// Listens for VIEW intents forwarded by the Android side over the
/// `noor/links` EventChannel (and the identical iOS forwarding added in
/// SceneDelegate) and routes them by scheme:
///
///  - `magnet:…`  → opens the torrent flow automatically.
///  - `noor://callback?code=…&state=…` → legacy Trakt PKCE return.
///  - `https://<registered redirect host>/?code=…&state=…` → primary Trakt
///    PKCE return (Android App Links) — see NoorApi.completeTraktLink.
///  - `app.noor.mobile://callback?code=…` → MyAnimeList code return.
///  - `app.nova.mobile://callback#access_token=…` → AniList token return.
///    Both are parsed by OAuthRedirect and stored in AppState so the
///    matching linking flow can consume it.
///  - `app.nova.mobile://collection-invite?token=…` → server-checked shared
///    collection membership after the current account becomes active.
///
/// All Trakt returns finish through the same handshake anywhere in the app;
/// relay-based completions (the app polling the web companion) are surfaced
/// here too via [AppState.traktLinkEvent].
///
/// Covers both cold starts (link captured before Flutter was ready and
/// delivered on first listen) and warm starts (onNewIntent while running).
class IncomingLinkListener extends StatefulWidget {
  const IncomingLinkListener({super.key, required this.child});

  final Widget child;

  @override
  State<IncomingLinkListener> createState() => _IncomingLinkListenerState();
}

class _IncomingLinkListenerState extends State<IncomingLinkListener>
    with WidgetsBindingObserver {
  static const _inviteStorage = FlutterSecureStorage();
  static const _pendingInviteKey = 'nova.shared-collections.pending-invite';
  static const _pendingPartyKey = 'nova.watch-party.pending-invite';
  String? _pendingParty;
  bool _openingParty = false;
  int _partyGeneration = 0;
  Future<void> _partyWrite = Future<void>.value();
  AccountController? _partyAccount;
  StreamSubscription<Object?>? _sub;
  String? _pendingInvite;
  bool _joiningInvite = false;
  bool _retryInviteOnResume = false;
  int _inviteGeneration = 0;
  Future<void> _inviteWrite = Future<void>.value();

  int _seenTraktLinkEventAt = 0;
  int _seenOAuthLinkEventAt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _partyAccount = context.read<AccountController?>();
    _partyAccount?.addListener(_schedulePartyInvite);
    unawaited(_restorePendingInvite());
    unawaited(_restorePartyInvite());
    try {
      _sub = const EventChannel('noor/links')
          .receiveBroadcastStream()
          .listen(_onLink, onError: (Object _) {
        // The channel only exists on Android; silence any platform noise.
      });
    } catch (_) {
      // Platform channel unavailable (e.g. tests) — ignore.
    }
  }

  void _onLink(Object? data) {
    if (!mounted || data is! String) return;
    final partyUri = Uri.tryParse(data);
    if (partyUri?.scheme == 'app.nova.mobile' &&
        partyUri?.host == 'watch-party') {
      final invite = parseWatchPartyInvitation(data);
      if (invite == null) {
        NoorToast.show(context, NovaStrings.of(context).text('partyNotFound'),
            error: true);
      } else {
        unawaited(_queuePartyInvite(
            watchPartyInvite(invite.code, relay: invite.relay)));
      }
      return;
    }
    final invite = parseSharedCollectionInvite(data);
    if (invite != null) {
      unawaited(_queueInvite(invite));
      return;
    }
    final uri = Uri.tryParse(data);
    if (uri?.scheme.toLowerCase() == 'app.nova.mobile' &&
        uri?.host.toLowerCase() == 'collection-invite') {
      NoorToast.show(context,
          NovaStrings.of(context).text('sharedCollectionInviteInvalid'),
          error: true);
      return;
    }
    final lower = data.toLowerCase();
    if (lower.startsWith('magnet:')) {
      if (!mounted) return;
      unawaited(_openGuardedMagnet(data));
      return;
    }
    if (lower.startsWith('noor://')) {
      unawaited(_completeTrakt(data));
      return;
    }
    if (OAuthRedirect.isCallback(data)) {
      // Supabase Auth handles confirmation and recovery on this registered
      // scheme. Never pass its code to linked-service OAuth handlers.
      if (Uri.tryParse(data)?.queryParameters.containsKey('nova_auth') ==
          true) {
        return;
      }
      unawaited(_receiveOAuthCallback(data));
      return;
    }
    if (lower.startsWith('https://') && NoorApi.isTraktHttpsReturn(data)) {
      unawaited(_completeTrakt(data));
    }
  }

  Future<void> _restorePendingInvite() async {
    final generation = _inviteGeneration;
    try {
      final token = await _inviteStorage.read(key: _pendingInviteKey);
      if (!mounted || generation != _inviteGeneration || token == null) return;
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) {
        await _inviteStorage.delete(key: _pendingInviteKey);
        return;
      }
      setState(() => _pendingInvite = token);
    } catch (_) {
      // A storage failure does not prevent newly opened links from working.
    }
  }

  Future<void> _restorePartyInvite() async {
    final generation = _partyGeneration;
    try {
      final code = await _inviteStorage.read(key: _pendingPartyKey);
      if (!mounted || generation != _partyGeneration || code == null) return;
      if (validWatchPartyCode(code) ||
          parseWatchPartyInvitation(code) != null) {
        setState(() => _pendingParty = code);
      } else {
        await _inviteStorage.delete(key: _pendingPartyKey);
      }
    } catch (_) {/* Newly opened links still work without durable storage. */}
  }

  Future<void> _queuePartyInvite(String code) async {
    ++_partyGeneration;
    setState(() => _pendingParty = code);
    _partyWrite = _partyWrite.then((_) async {
      try {
        await _inviteStorage.write(key: _pendingPartyKey, value: code);
      } catch (_) {/* Keep in memory. */}
    });
    await _partyWrite;
    if (mounted) _schedulePartyInvite();
  }

  void _schedulePartyInvite() {
    if (!mounted || _openingParty || _pendingParty == null) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final account = context.read<AccountController?>();
    final app = context.read<AppState>();
    if (account?.isGuest != false ||
        account?.activeProfileId == null ||
        app.kidsSession ||
        app.sync.accountId != account?.user?.id ||
        app.activeProfileId != account?.activeProfileId) {
      return;
    }
    _openingParty = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final generation = _partyGeneration;
      final code = _pendingParty;
      try {
        await _partyWrite;
        if (!mounted ||
            generation != _partyGeneration ||
            code == null ||
            context.read<AppState>().kidsSession) {
          return;
        }
        final currentAccount = context.read<AccountController?>();
        final currentApp = context.read<AppState>();
        if (currentAccount?.isGuest != false ||
            currentAccount?.activeProfileId == null ||
            currentApp.sync.accountId != currentAccount?.user?.id ||
            currentApp.activeProfileId != currentAccount?.activeProfileId) {
          return;
        }
        setState(() => _pendingParty = null);
        _partyWrite = _partyWrite.then((_) async {
          try {
            await _inviteStorage.delete(key: _pendingPartyKey);
          } catch (_) {/* Consumed in memory. */}
        });
        await _partyWrite;
        if (mounted) {
          if (parseWatchPartyInvitation(code) != null) {
            final joined =
                await showWatchPartyJoinDialog(context, initialInvite: code);
            if (mounted && joined == true) await openWatchParty(context);
          } else {
            await Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => WatchPartyPage(initialCode: code)));
          }
        }
      } finally {
        _openingParty = false;
        if (mounted && _pendingParty != null) _schedulePartyInvite();
      }
    });
  }

  Future<void> _queueInvite(String token) async {
    final generation = ++_inviteGeneration;
    _retryInviteOnResume = false;
    setState(() => _pendingInvite = token);
    _inviteWrite = _inviteWrite.then((_) async {
      try {
        await _inviteStorage.write(key: _pendingInviteKey, value: token);
      } catch (_) {
        // Keep the invite in memory for this run if secure storage is down.
      }
    });
    await _inviteWrite;
    if (mounted && generation == _inviteGeneration) _scheduleJoinInvite();
  }

  void _scheduleJoinInvite() {
    if (_joiningInvite || _pendingInvite == null || _retryInviteOnResume) {
      return;
    }
    final account = context.read<AccountController?>();
    final app = context.read<AppState>();
    if (account?.user == null ||
        account!.activeProfileId == null ||
        app.sync.accountId != account.user!.id) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_joinPendingInvite());
    });
  }

  Future<void> _joinPendingInvite() async {
    if (_joiningInvite) return;
    final token = _pendingInvite;
    if (token == null) return;
    final account = context.read<AccountController?>();
    final app = context.read<AppState>();
    if (account?.user == null ||
        account!.activeProfileId == null ||
        app.sync.accountId != account.user!.id) {
      return;
    }
    _joiningInvite = true;
    try {
      await _inviteWrite;
      final id = await SharedCollectionsService(Supabase.instance.client)
          .joinInvite(token);
      if (!mounted || _pendingInvite != token) return;
      await _clearPendingInvite(token);
      if (!mounted) return;
      NoorToast.show(context,
          NovaStrings.of(context).text('sharedCollectionInviteJoined'));
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SharedCollectionDetailPage(collectionId: id),
      ));
    } on PostgrestException catch (error) {
      if (!mounted || _pendingInvite != token) return;
      if (error.code == '22023') {
        await _clearPendingInvite(token);
        if (!mounted) return;
        NoorToast.show(context,
            NovaStrings.of(context).text('sharedCollectionInviteInvalid'),
            error: true);
      } else {
        _retryInviteOnResume = true;
        NoorToast.show(context,
            NovaStrings.of(context).text('sharedCollectionInvitePending'),
            error: true);
      }
    } catch (_) {
      if (mounted && _pendingInvite == token) {
        _retryInviteOnResume = true;
        NoorToast.show(context,
            NovaStrings.of(context).text('sharedCollectionInvitePending'),
            error: true);
      }
    } finally {
      _joiningInvite = false;
      if (mounted && _pendingInvite != null && !_retryInviteOnResume) {
        _scheduleJoinInvite();
      }
    }
  }

  Future<void> _clearPendingInvite(String token) async {
    if (_pendingInvite != token) return;
    ++_inviteGeneration;
    setState(() => _pendingInvite = null);
    _inviteWrite = _inviteWrite.then((_) async {
      try {
        await _inviteStorage.delete(key: _pendingInviteKey);
      } catch (_) {
        // The in-memory invite has been consumed even if storage is down.
      }
    });
    await _inviteWrite;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedulePartyInvite();
    if (state == AppLifecycleState.resumed && _retryInviteOnResume) {
      _retryInviteOnResume = false;
      _scheduleJoinInvite();
    }
  }

  Future<void> _openGuardedMagnet(String link) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final app = context.read<AppState>();
    if (app.kidsSession || prefs.getBool('nova.kids.active') == true) {
      if (!await NovaParentalGate.verify(context) || !mounted) return;
    }
    if (mounted) await openMagnetFlow(context, initialMagnet: link);
  }

  /// Receives an AniList / MyAnimeList OAuth return
  /// (either registered callback scheme): AppState dispatches it
  /// to the pending tracker handshake; the completion surfaces through
  /// [AppState.oauthLinkEvent] (watched in build) as a toast.
  Future<void> _receiveOAuthCallback(String link) async {
    final callback = OAuthRedirect.parse(link);
    if (callback == null) return; // foreign app.noor.mobile:// link
    context.read<AppState>().announceOAuthCallback(callback);
  }

  String _oauthReasonText(bool english, String? reason, String? service) {
    final who = service == 'anilist'
        ? 'AniList'
        : service == 'mal'
            ? 'MyAnimeList'
            : (NovaStrings.lookup(english, 'message698'));
    switch (reason) {
      case 'invalid_client':
        return NovaStrings.lookup(english, 'message699', {'p0': who});
      case 'invalid_grant':
        return NovaStrings.lookup(english, 'message700', {'p0': who});
      case 'state_mismatch':
      case 'flow_expired':
      case 'no_pending_flow':
        return NovaStrings.lookup(english, 'message701');
      case 'access_denied':
        return NovaStrings.lookup(english, 'message702');
      default:
        return NovaStrings.lookup(english, 'message703', {'p0': who});
    }
  }

  /// Finishes the Trakt PKCE round-trip and announces it. Runs regardless of
  /// the current screen so the callback is never lost when the linking sheet
  /// is closed; the sheet itself rebuilds from [AppState.linkedServices].
  Future<void> _completeTrakt(String link) async {
    final app = context.read<AppState>();
    final result = await app.api.completeTraktLink(link);
    final status = result['status']?.toString();
    final reason = result['reason']?.toString();
    if (status != 'success' && reason == 'no_pending_flow') {
      // Duplicate callback after the flow already finished — stay silent
      // unless the link never actually completed.
      if (app.api.isLinked('trakt')) return;
    }
    if (!mounted) return;
    if (status == 'success') {
      await app.saveLinkedService('trakt', <String, dynamic>{
        'linked': true,
        'linkedAt': DateTime.now().millisecondsSinceEpoch,
        if (result['username'] != null) 'username': result['username'],
      });
      if (!mounted) return;
      NoorToast.show(
        context,
        NovaStrings.lookup(app.english, 'message704'),
      );
      return;
    }
    if (!mounted) return;
    NoorToast.show(
      context,
      _linkReason(reason, app.english),
      error: true,
    );
  }

  String _linkReason(String? reason, bool english) => NovaStrings.lookup(
      english,
      switch (reason) {
        'access_denied' => 'serviceAccessDenied',
        'state_mismatch' => 'serviceStateMismatch',
        'exchange_failed' => 'serviceExchangeFailed',
        'flow_expired' => 'serviceFlowExpired',
        'no_pending_flow' => 'serviceNoPendingFlow',
        'network_error' => 'serviceNetworkError',
        _ => 'serviceLinkFailed',
      });

  @override
  void dispose() {
    _partyAccount?.removeListener(_schedulePartyInvite);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Relay-based completions (the app polling the web companion while the
    // user is anywhere in the app) announce themselves through app state;
    // surface each new event exactly once as a toast.
    final app = context.watch<AppState>();
    final account = context.watch<AccountController?>();
    final event = app.traktLinkEvent;
    if (event != null) {
      final at = (event['at'] as num?)?.toInt() ?? 0;
      if (at > _seenTraktLinkEventAt && at > app.seenTraktLinkEventAt) {
        _seenTraktLinkEventAt = at;
        app.seenTraktLinkEventAt = at;
        final ok = event['ok'] == true;
        final reason = event['reason']?.toString();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (ok) {
            NoorToast.show(
              context,
              NovaStrings.lookup(app.english, 'message704'),
            );
          } else {
            NoorToast.show(
              context,
              _linkReason(reason, app.english),
              error: true,
            );
          }
        });
      }
    }
    // Tracker (AniList / MyAnimeList) link completions — the OAuth return
    // was dispatched by AppState; announce the outcome once.
    final oauthEvent = app.oauthLinkEvent;
    if (oauthEvent != null) {
      final at = (oauthEvent['at'] as num?)?.toInt() ?? 0;
      if (at > _seenOAuthLinkEventAt && at > app.seenOAuthLinkEventAt) {
        _seenOAuthLinkEventAt = at;
        app.seenOAuthLinkEventAt = at;
        final ok = oauthEvent['ok'] == true;
        final reason = oauthEvent['reason']?.toString();
        final service = oauthEvent['service']?.toString();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (ok) {
            final who = service == 'anilist'
                ? 'AniList'
                : service == 'mal'
                    ? 'MyAnimeList'
                    : '';
            NoorToast.show(
              context,
              NovaStrings.lookup(app.english, 'message705', {'p0': who}),
            );
          } else {
            NoorToast.show(
              context,
              _oauthReasonText(app.english, reason, service),
              error: true,
            );
          }
        });
      }
    }
    if (_pendingInvite != null && account?.activeProfileId != null) {
      _scheduleJoinInvite();
    }
    if (_pendingParty != null) _schedulePartyInvite();
    return widget.child;
  }
}
