import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'l10n/nova_strings.dart';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'app/noor_app.dart';
import 'core/api/noor_api.dart';
import 'core/auth/account_controller.dart';
import 'core/auth/secure_auth_storage.dart';
import 'core/data/catalog_repository.dart';
import 'core/state/app_state.dart';
import 'core/theme/nova_theme.dart';
import 'core/theme/system_bars.dart';
import 'core/torrent/torrent_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // media_kit (libmpv) init — Task 127: without this the first Player()
  // construction throws ('MediaKit.ensureInitialized must be called…') inside
  // the player route's first frame, which in release paints the full-screen
  // grey/white error box instead of the player. Idempotent.
  MediaKit.ensureInitialized();
  // Task 128: release builds paint uncaught build/layout exceptions as the
  // near-white RenderErrorBox users reported as a "white screen". Replace it
  // app-wide with a dark, on-brand error panel (debug keeps the classic red
  // box so dev-time stack traces stay loud and readable).
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!kReleaseMode) {
      return ErrorWidget(details.exception);
    }
    return const _NovaErrorPanel();
  };
  // Edge-to-edge (user mandate, Tasks 115/117): the app draws behind a fully
  // transparent status bar (battery/signal/clock) and navigation bar — the
  // full-screen glass look. Boot default matches the dark Horse canvas; the
  // shell re-asserts the style via AnnotatedRegion, derived from the live
  // theme brightness, so it also survives the player's immersive toggling.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
      noorSystemBarOverlayStyle(Brightness.dark));
  const supabaseUrl = String.fromEnvironment('NOVA_SUPABASE_URL',
      defaultValue: 'https://hcyysnagdumpviromdzl.supabase.co');
  const publishableKey = String.fromEnvironment('NOVA_SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable__wLpouQl59aYu9pD4O1utg_Vtzb8OhX');
  AccountController? account;
  if (publishableKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: publishableKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: NovaSecureAuthStorage(),
          pkceAsyncStorage: NovaSecurePkceStorage(),
          authFlowType: AuthFlowType.pkce,
          detectSessionInUriPredicate: _isNovaAuthRedirect,
        ),
        debug: false,
      );
      account = AccountController(Supabase.instance.client);
      await account.initialize();
    } catch (_) {
      // The launch gate presents a localized configuration error.
    }
  }
  final api = NoorApi();
  final appState = AppState(api, CatalogRepository(api));
  PaintingBinding.instance.imageCache.maximumSizeBytes = 128 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 200;
  runApp(NovaApp(state: appState, account: account, requireAccount: true));
  // Task 128: pre-boot the torrent engine + DHT while the user browses, so
  // the first torrent stream never pays the 10–30s cold-start inside its own
  // metadata timeout. No-op (and fully swallowed) off Android.
  unawaited(TorrentService.instance.warmup());
}

bool _isNovaAuthRedirect(Uri uri) =>
    uri.scheme == 'app.noor.mobile' &&
    uri.host == 'callback' &&
    (uri.queryParameters['nova_auth'] == 'confirm' ||
        uri.queryParameters['nova_auth'] == 'recovery');

class _NovaErrorPanel extends StatelessWidget {
  const _NovaErrorPanel();

  @override
  Widget build(BuildContext context) {
    final palette = NovaTheme.of(context);
    final locale = Localizations.maybeLocaleOf(context) ??
        PlatformDispatcher.instance.locale;
    final strings = NovaStrings(locale);
    return ColoredBox(
      color: palette.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.circleAlert, color: palette.gold, size: 40),
                  const SizedBox(height: 16),
                  Text(strings.text('errorTitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(strings.text('errorBody'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
