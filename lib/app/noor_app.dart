import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/data/cache_reset_service.dart';
import '../core/auth/account_controller.dart';
import '../core/state/app_state.dart';
import '../core/storage/subtitle_font_store.dart';
import '../core/theme/nova_theme.dart';
import '../features/shell/main_shell.dart';
import '../features/settings/settings_data_page.dart';
import '../core/update/app_update_service.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/torrent/magnet_link_handler.dart';
import '../l10n/nova_strings.dart';
import '../shared/widgets/app_state_message.dart';
import 'account_gate.dart';
import '../features/watch_party/watch_party_scope.dart';

class NovaApp extends StatelessWidget {
  const NovaApp(
      {super.key,
      required this.state,
      this.updateService,
      this.account,
      this.requireAccount = false,
      this.onLaunchReady});
  final AppState state;
  final AppUpdateService? updateService;
  final AccountController? account;
  final bool requireAccount;

  /// Releases the native launch screen after a usable frame has been built.
  final VoidCallback? onLaunchReady;
  static final _darkArabic = NovaTheme.build(Brightness.dark, arabic: true);
  static final _darkOledArabic =
      NovaTheme.build(Brightness.dark, arabic: true, oled: true);
  static final _lightArabic = NovaTheme.build(Brightness.light, arabic: true);
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: state,
        child: Provider<AccountController?>.value(
            value: account,
            child: WatchPartyScope(
                account: account,
                app: state,
                child: Selector<AppState, (bool, String, bool, bool)>(
                  selector: (_, app) => (
                    app.english,
                    (app.webSettings['themeMode'] ?? 'dark').toString(),
                    app.webSettings['reduceMotion'] == true,
                    app.webSettings['oledMode'] == true
                  ),
                  builder: (context, value, _) => MaterialApp(
                    navigatorObservers: [shellChromeRouteObserver],
                    onGenerateTitle: (context) =>
                        NovaStrings.of(context).text('appName'),
                    debugShowCheckedModeBanner: false,
                    theme: value.$1 ? NovaTheme.light : _lightArabic,
                    darkTheme: value.$1
                        ? (value.$4 ? NovaTheme.darkOled : NovaTheme.dark)
                        : (value.$4 ? _darkOledArabic : _darkArabic),
                    themeMode: switch (value.$2) {
                      'light' => ThemeMode.light,
                      'system' => ThemeMode.system,
                      _ => ThemeMode.dark
                    },
                    themeAnimationDuration:
                        value.$3 ? Duration.zero : NovaMotion.state,
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
                              disableAnimations:
                                  media.disableAnimations || value.$3),
                          child: child!);
                    },
                    home: IncomingLinkListener(
                        child: _LaunchGate(
                            updateService: updateService,
                            account: account,
                            requireAccount: requireAccount,
                            onLaunchReady: onLaunchReady)),
                  ),
                ))),
      );
}

/// Existing embedder entry points remain source-compatible.
class NoorApp extends NovaApp {
  const NoorApp({super.key, required super.state});
}

class _LaunchGate extends StatefulWidget {
  const _LaunchGate(
      {this.updateService,
      this.account,
      this.requireAccount = false,
      this.onLaunchReady});
  final AppUpdateService? updateService;
  final AccountController? account;
  final bool requireAccount;
  final VoidCallback? onLaunchReady;
  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  static const _iosLastNotifiedBuildKey = 'nova.update.ios.lastNotifiedBuild';
  String? _startupError;
  bool _onboarding = false;
  bool _startupReady = false;
  bool _starting = true;
  bool _launchReleased = false;
  AppUpdateStatus? _forcedUpdate;
  late final AppUpdateService _updateService =
      widget.updateService ?? AppUpdateService();
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
      if (!mounted) return;
      CacheResetService.instance.start(app);
      setState(() {
        _startupReady = true;
        _startupError = null;
        _starting = false;
      });
      unawaited(_checkForForcedUpdate());
    } catch (error) {
      if (mounted) {
        setState(() {
          _startupError = error.toString();
          _starting = false;
        });
      }
    }
  }

  void _releaseLaunchScreen() {
    if (_launchReleased) return;
    _launchReleased = true;
    // Layout still runs while the first frame is deferred. Release only after
    // this ready/error frame has been built, so no empty frame reaches users.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLaunchReady?.call();
    });
  }

  Future<void> _checkForForcedUpdate() async {
    try {
      final status = await _updateService.checkForUpdates();
      if (mounted && status.forceRequired) {
        setState(() => _forcedUpdate = status);
      } else if (mounted &&
          status.platform == AppUpdatePlatform.ios &&
          status.hasUpdate) {
        final prefs = await SharedPreferences.getInstance();
        final build = status.manifest.iosLatestBuild;
        if (!mounted || prefs.getInt(_iosLastNotifiedBuildKey) == build) return;
        await prefs.setInt(_iosLastNotifiedBuildKey, build);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showIosUpdate(status));
        });
      }
    } catch (_) {
      // An unavailable update manifest must never prevent offline app use.
    }
  }

  Future<void> _showIosUpdate(AppUpdateStatus status) async {
    final strings = NovaStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.text('updateSection')),
        content: Text(strings.text('updateAvailable', {
          'version': status.availableVersion,
        })),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.text('updateDismiss')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_openIosUpdate(status));
            },
            child: Text(strings.text('updateOpenIosAction')),
          ),
        ],
      ),
    );
  }

  Future<void> _openIosUpdate(AppUpdateStatus status) async {
    try {
      await _updateService.openIosUpdate(status.manifest.iosUrl);
    } catch (error) {
      if (!mounted) return;
      final failure = error is AppUpdateException
          ? error.failure
          : AppUpdateFailure.iosOpenFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(NovaStrings.of(context).text(appUpdateMessageKey(failure))),
      ));
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
    if (_startupError != null) {
      _releaseLaunchScreen();
      return Scaffold(
        body: SafeArea(
          child: AppStateMessage(
            icon: LucideIcons.circleAlert,
            message:
                '${s.text('startError')}\n\n${s.text(_starting ? 'loading' : 'errorBody')}',
            actionLabel: s.text('retry'),
            filledButton: true,
            onAction: _starting
                ? null
                : () {
                    setState(() => _starting = true);
                    _initialize();
                  },
          ),
        ),
      );
    }
    if (ready && _startupReady) {
      _releaseLaunchScreen();
      if (_forcedUpdate != null) {
        return SettingsAboutPage(
          updateService: widget.updateService,
          initialStatus: _forcedUpdate,
        );
      }
      if (_onboarding) return OnboardingPage(onComplete: _complete);
      if (widget.requireAccount && widget.account == null) {
        return Scaffold(
            body: SafeArea(
                child: Center(
                    child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(s.text('accountConfigurationMissing'),
              textAlign: TextAlign.center),
        ))));
      }
      return widget.account == null
          ? const MainShell()
          : AccountGate(account: widget.account!);
    }
    // Not presented: main keeps the OS launch artwork until initialization
    // succeeds or the recoverable error screen above can take over.
    return const SizedBox.expand();
  }
}
