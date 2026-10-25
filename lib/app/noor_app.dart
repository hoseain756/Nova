import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/data/cache_reset_service.dart';
import '../core/state/app_state.dart';
import '../core/storage/subtitle_font_store.dart';
import '../core/theme/nova_theme.dart';
import '../features/shell/main_shell.dart';
import '../features/settings/settings_data_page.dart';
import '../core/update/app_update_service.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/splash/nova_splash.dart';
import '../features/torrent/magnet_link_handler.dart';
import '../l10n/nova_strings.dart';
import '../shared/widgets/shimmer_box.dart';

class NovaApp extends StatelessWidget {
  const NovaApp({super.key, required this.state, this.updateService});
  final AppState state;
  final AppUpdateService? updateService;
  static final _darkArabic = NovaTheme.build(Brightness.dark, arabic: true);
  static final _lightArabic = NovaTheme.build(Brightness.light, arabic: true);
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: state,
        child: Selector<AppState, (bool, String, bool)>(
          selector: (_, app) => (
            app.english,
            (app.webSettings['themeMode'] ?? 'dark').toString(),
            app.webSettings['reduceMotion'] == true
          ),
          builder: (context, value, _) => MaterialApp(
            navigatorObservers: [shellChromeRouteObserver],
            onGenerateTitle: (context) =>
                NovaStrings.of(context).text('appName'),
            debugShowCheckedModeBanner: false,
            theme: value.$1 ? NovaTheme.light : _lightArabic,
            darkTheme: value.$1 ? NovaTheme.dark : _darkArabic,
            themeMode: switch (value.$2) {
              'light' => ThemeMode.light,
              'system' => ThemeMode.system,
              _ => ThemeMode.dark
            },
            themeAnimationDuration: value.$3 ? Duration.zero : NovaMotion.state,
            locale: Locale(value.$1 ? 'en' : 'ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              NovaStrings.delegate,
              ...GlobalMaterialLocalizations.delegates
            ],
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                  data: media.copyWith(
                      disableAnimations: media.disableAnimations || value.$3),
                  child: child!);
            },
            home: IncomingLinkListener(
                child: _LaunchGate(updateService: updateService)),
          ),
        ),
      );
}

/// Existing embedder entry points remain source-compatible.
class NoorApp extends NovaApp {
  const NoorApp({super.key, required super.state});
}

class _LaunchGate extends StatefulWidget {
  const _LaunchGate({this.updateService});
  final AppUpdateService? updateService;
  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  String? _startupError;
  bool _onboarding = false;
  bool _splashComplete = false;
  AppUpdateStatus? _forcedUpdate;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() =>
          _onboarding = prefs.getBool('nova.onboarding.complete') != true);
      final app = context.read<AppState>();
      await app.initialize();
      await SubtitleFontStore.instance.initialize();
      CacheResetService.instance.start(app);
      unawaited(_checkForForcedUpdate());
    } catch (error) {
      if (mounted) setState(() => _startupError = error.toString());
    }
  }

  Future<void> _checkForForcedUpdate() async {
    try {
      final status =
          await (widget.updateService ?? AppUpdateService()).checkForUpdates();
      if (mounted && status.forceRequired) {
        setState(() => _forcedUpdate = status);
      }
    } catch (_) {
      // An unavailable update manifest must never prevent offline app use.
    }
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nova.onboarding.complete', true);
    if (mounted) setState(() => _onboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    final ready = context.select<AppState, bool>((app) => app.initialized);
    final s = NovaStrings.of(context);
    if (ready && _splashComplete) {
      if (_forcedUpdate != null) {
        return SettingsAboutPage(
          updateService: widget.updateService,
          initialStatus: _forcedUpdate,
        );
      }
      return _onboarding
          ? OnboardingPage(onComplete: _complete)
          : const MainShell();
    }
    return NovaSplash(
      onFinished: () {
        if (mounted && !_splashComplete) {
          setState(() => _splashComplete = true);
        }
      },
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_startupError != null) ...[
            Text(
              s.text('startError'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(s.text('errorBody'), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                setState(() => _startupError = null);
                _initialize();
              },
              child: Text(s.text('retry')),
            ),
          ] else ...[
            Semantics(
              liveRegion: true,
              child: Text(
                s.text('loading'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 18),
            const ShimmerBox(width: 240, height: 6),
          ],
        ],
      ),
    );
  }
}
