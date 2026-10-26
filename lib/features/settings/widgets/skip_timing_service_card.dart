import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/storage/skip_timing_credentials.dart';
import '../../../l10n/nova_strings.dart';
import '../../../shared/widgets/noor_toast.dart';
import 'settings_tiles.dart';

String skipTimingServiceName(String service) => switch (service) {
      'aniskip' => 'AniSkip',
      'introdb' => 'IntroDB',
      'theintrodb' => 'TheIntroDB',
      _ => service,
    };

String _descriptionKey(String service) => switch (service) {
      'aniskip' => 'skipTimingAniSkipDescription',
      'introdb' => 'skipTimingIntroDbDescription',
      _ => 'skipTimingTheIntroDbDescription',
    };

SkipTimingCredential? _credential(String service) => switch (service) {
      'introdb' => SkipTimingCredential.introDb,
      'theintrodb' => SkipTimingCredential.theIntroDb,
      _ => null,
    };

String _website(String service) => switch (service) {
      'aniskip' => 'https://aniskip.com/',
      'introdb' => 'https://introdb.app/',
      _ => 'https://theintrodb.org/',
    };

class SkipTimingServiceTile extends StatefulWidget {
  const SkipTimingServiceTile({
    super.key,
    required this.service,
    required this.onTap,
  });

  final String service;
  final VoidCallback onTap;

  @override
  State<SkipTimingServiceTile> createState() => _SkipTimingServiceTileState();
}

class _SkipTimingServiceTileState extends State<SkipTimingServiceTile> {
  final _credentials = SkipTimingCredentials.shared;
  Future<bool>? _hasKey;

  @override
  void initState() {
    super.initState();
    _credentials.addListener(_refresh);
    final provider = _credential(widget.service);
    if (provider != null) _hasKey = _credentials.hasKey(provider);
  }

  @override
  void didUpdateWidget(SkipTimingServiceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) _refresh();
  }

  void _refresh() {
    final provider = _credential(widget.service);
    if (provider == null) return;
    setState(() => _hasKey = _credentials.hasKey(provider));
  }

  @override
  void dispose() {
    _credentials.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _credential(widget.service);
    final strings = NovaStrings.of(context);
    if (provider == null) {
      return _tile(context, strings.text('skipTimingPublic'), false);
    }
    return FutureBuilder<bool>(
      future: _hasKey,
      builder: (context, snapshot) {
        final subtitle = snapshot.hasError
            ? strings.text('skipTimingKeyCheckFailed')
            : !snapshot.hasData
                ? strings.text('skipTimingCheckingKey')
                : snapshot.data == true
                    ? strings.text('skipTimingKeySaved')
                    : strings.text('skipTimingKeyNotSaved');
        return _tile(context, subtitle, snapshot.data == true);
      },
    );
  }

  Widget _tile(BuildContext context, String subtitle, bool hasKey) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsTile(
      icon: LucideIcons.skipForward,
      title: skipTimingServiceName(widget.service),
      subtitle: subtitle,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (hasKey) ...[
          Icon(LucideIcons.circleCheck, size: 18, color: scheme.secondary),
          const SizedBox(width: 8),
        ],
        Icon(
          Directionality.of(context) == TextDirection.rtl
              ? LucideIcons.chevronLeft
              : LucideIcons.chevronRight,
          size: 20,
          color: scheme.onSurfaceVariant,
        ),
      ]),
      onTap: widget.onTap,
    );
  }
}

class SkipTimingServiceCard extends StatefulWidget {
  const SkipTimingServiceCard({super.key, required this.service});

  final String service;

  @override
  State<SkipTimingServiceCard> createState() => _SkipTimingServiceCardState();
}

class _SkipTimingServiceCardState extends State<SkipTimingServiceCard> {
  final _key = TextEditingController();
  late Future<bool> _hasKey;
  bool _busy = false;

  SkipTimingCredential? get _provider => _credential(widget.service);

  @override
  void initState() {
    super.initState();
    final provider = _provider;
    _hasKey = provider == null
        ? Future<bool>.value(false)
        : SkipTimingCredentials.shared.hasKey(provider);
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _refresh() {
    final provider = _provider;
    if (provider != null) {
      setState(() => _hasKey = SkipTimingCredentials.shared.hasKey(provider));
    }
  }

  Future<void> _save() async {
    final provider = _provider;
    if (provider == null || _busy) return;
    final strings = NovaStrings.of(context);
    setState(() => _busy = true);
    try {
      await SkipTimingCredentials.shared.saveKey(provider, _key.text);
      _key.clear();
      if (!mounted) return;
      _refresh();
      NoorToast.show(context, strings.text('skipTimingKeySavedToast'));
    } on FormatException {
      if (mounted) {
        NoorToast.show(context, strings.text('skipTimingKeyInvalid'),
            error: true);
      }
    } catch (_) {
      if (mounted) {
        NoorToast.show(context, strings.text('skipTimingStorageError'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final provider = _provider;
    if (provider == null || _busy) return;
    final strings = NovaStrings.of(context);
    final confirmed = await confirmSettingsAction(
      context,
      title: strings.text('skipTimingRemoveKey'),
      message: strings.text('skipTimingRemoveConfirm'),
      confirm: strings.text('skipTimingRemoveKey'),
      cancel: strings.text('cancel'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await SkipTimingCredentials.shared.removeKey(provider);
      _key.clear();
      if (!mounted) return;
      _refresh();
      NoorToast.show(context, strings.text('skipTimingKeyRemovedToast'));
    } catch (_) {
      if (mounted) {
        NoorToast.show(context, strings.text('skipTimingStorageError'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = NovaStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final provider = _provider;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(skipTimingServiceName(widget.service),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(strings.text(_descriptionKey(widget.service)),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(
            strings.text(provider == null
                ? 'skipTimingAniSkipInfo'
                : widget.service == 'introdb'
                    ? 'skipTimingIntroDbKeyInfo'
                    : 'skipTimingTheIntroDbKeyInfo'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (provider != null) ...[
            const SizedBox(height: 12),
            Text(strings.text('skipTimingStorageNote'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FutureBuilder<bool>(
              future: _hasKey,
              builder: (context, snapshot) => Text(
                strings.text(snapshot.hasError
                    ? 'skipTimingKeyCheckFailed'
                    : !snapshot.hasData
                        ? 'skipTimingCheckingKey'
                        : snapshot.data == true
                            ? 'skipTimingKeySaved'
                            : 'skipTimingKeyNotSaved'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: snapshot.data == true
                          ? scheme.secondary
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _key,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: strings.text('skipTimingKeyLabel'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.shieldCheck),
                label: Text(strings.text('skipTimingSaveKey')),
              ),
              FutureBuilder<bool>(
                future: _hasKey,
                builder: (context, snapshot) => snapshot.data == true
                    ? TextButton.icon(
                        onPressed: _busy ? null : _remove,
                        icon: const Icon(LucideIcons.trash2),
                        label: Text(strings.text('skipTimingRemoveKey')),
                      )
                    : const SizedBox.shrink(),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(_website(widget.service)),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(LucideIcons.externalLink),
            label: Text(strings.text('skipTimingWebsite')),
          ),
        ],
      ),
    );
  }
}
