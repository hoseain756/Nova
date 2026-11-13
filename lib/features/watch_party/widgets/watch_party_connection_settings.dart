import 'package:flutter/material.dart';
import 'package:nova_mobile/shared/widgets/nova_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/watch_party/watch_party_controller.dart';
import '../../../core/watch_party/watch_party_relay_settings.dart';
import '../../../l10n/nova_strings.dart';
import 'watch_party_cloudflare_setup.dart';

Future<void> showWatchPartyConnectionDialog(BuildContext context) async {
  final settings = context.read<WatchPartyRelaySettings?>();
  if (settings == null) return;
  final locked = context.read<WatchPartyController?>()?.snapshot != null;
  await showNovaDialog<void>(
      context: context,
      builder: (dialog) => NovaGlassDialog(
              scrollable: true,
              constraints: const BoxConstraints(maxWidth: 520),
              title: Text(NovaStrings.of(dialog).text('partyRelayTitle')),
              content: WatchPartyConnectionSettings(
                  settings: settings, locked: locked),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: Text(NovaStrings.of(dialog).text('close')))
              ]));
}

/// Device-local transport configuration, separate from room playback policy.
class WatchPartyConnectionSettings extends StatefulWidget {
  const WatchPartyConnectionSettings(
      {super.key, required this.settings, this.locked = false});
  final WatchPartyRelaySettings settings;
  final bool locked;
  @override
  State<WatchPartyConnectionSettings> createState() =>
      _WatchPartyConnectionSettingsState();
}

class _WatchPartyConnectionSettingsState
    extends State<WatchPartyConnectionSettings> {
  late final _endpoint = TextEditingController(text: widget.settings.endpoint);
  String? _lastEndpoint;
  bool _working = false;
  String? _error, _notice;
  Map<String, Object?> _noticeArgs = const {};
  String _t(String key) => NovaStrings.of(context).text(key);

  @override
  void initState() {
    super.initState();
    _lastEndpoint = widget.settings.endpoint;
    widget.settings.addListener(_settingsChanged);
  }

  void _settingsChanged() {
    final value = widget.settings.endpoint;
    if (value != _lastEndpoint) {
      _lastEndpoint = value;
      _endpoint.text = value ?? '';
    }
  }

  Future<void> _run(Future<void> Function() action,
      {String? success, String formatError = 'partyRelayInvalid'}) async {
    if (_working || widget.locked) return;
    setState(() {
      _working = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      if (mounted) setState(() => _notice = success ?? _notice);
    } on FormatException {
      if (mounted) setState(() => _error = formatError);
    } on StateError {
      if (mounted) setState(() => _error = 'partyRelayRoomLocked');
    } catch (_) {
      if (mounted) setState(() => _error = 'partyUnavailable');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _check() async {
    try {
      normalizeWatchPartyRelayEndpoint(_endpoint.text);
    } on FormatException {
      setState(() => _error = 'partyRelayInvalid');
      return;
    }
    await _run(() async {
      final health = await widget.settings.check(endpoint: _endpoint.text);
      _notice = 'partyRelayCompatible';
      _noticeArgs = {'latency': health.latencyMs};
    }, formatError: 'partyRelayCheckFailed');
  }

  @override
  void dispose() {
    widget.settings.removeListener(_settingsChanged);
    _endpoint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _t(widget.settings.enabled
                        ? 'partyRelayCustom'
                        : 'partyRelayDefault'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_t('partyRelayBody')),
                const SizedBox(height: 16),
                if (widget.locked) ...[
                  if (widget.settings.enabled)
                    SelectableText(widget.settings.endpoint!,
                        textDirection: TextDirection.ltr),
                  const SizedBox(height: 8),
                  Text(_t('partyRelayRoomLocked'))
                ] else ...[
                  OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => showWatchPartyCloudflareSetup(
                              context, widget.settings),
                      icon: const Icon(LucideIcons.cloud, size: 18),
                      label: Text(_t('partyRelaySetup'))),
                  const SizedBox(height: 24),
                  TextField(
                      key: const ValueKey('party-relay-endpoint'),
                      controller: _endpoint,
                      enabled: !_working,
                      autocorrect: false,
                      enableSuggestions: false,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                          labelText: _t('partyRelayEndpoint'),
                          hintText: 'https://your-relay.workers.dev')),
                  const SizedBox(height: 12),
                  Text(_t('partyRelaySameServer'),
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton(
                        onPressed: _working
                            ? null
                            : () => _run(
                                () => widget.settings.configure(_endpoint.text),
                                success: 'partyRelaySaved'),
                        child: Text(_t('partyRelaySave'))),
                    TextButton.icon(
                        onPressed: _working ? null : _check,
                        icon: const Icon(LucideIcons.radio, size: 18),
                        label: Text(_t('partyRelayCheck'))),
                    if (widget.settings.enabled)
                      OutlinedButton(
                          onPressed: _working
                              ? null
                              : () => _run(widget.settings.useSupabase),
                          child: Text(_t('partyRelayRestore'))),
                    if (widget.settings.configured)
                      TextButton(
                          onPressed: _working
                              ? null
                              : () => _run(() async {
                                    await widget.settings.reset();
                                    _endpoint.clear();
                                  }),
                          child: Text(_t('partyRelayReset')))
                  ])
                ],
                if (_working)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                          liveRegion: true, child: Text(_t('partyWorking')))),
                if (_error != null || _notice != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                          liveRegion: true,
                          child: Text(
                              _error != null
                                  ? _t(_error!)
                                  : NovaStrings.of(context)
                                      .text(_notice!, _noticeArgs),
                              style: TextStyle(
                                  color: _error != null
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant))))
              ]));
}
