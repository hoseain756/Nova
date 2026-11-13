import 'package:flutter/material.dart';
import 'package:nova_mobile/shared/widgets/nova_dialog.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/watch_party/cloudflare_relay_deployer.dart';
import '../../../core/watch_party/watch_party_controller.dart';
import '../../../core/watch_party/watch_party_relay_settings.dart';
import '../../../l10n/nova_strings.dart';

Future<void> showWatchPartyCloudflareSetup(
        BuildContext context, WatchPartyRelaySettings settings) =>
    showNovaDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => WatchPartyCloudflareSetup(settings: settings));

/// Management credentials live only in this dialog and are never persisted.
class WatchPartyCloudflareSetup extends StatefulWidget {
  const WatchPartyCloudflareSetup(
      {super.key, required this.settings, this.deployer});
  final WatchPartyRelaySettings settings;
  final CloudflareRelayDeployer? deployer;
  @override
  State<WatchPartyCloudflareSetup> createState() =>
      _WatchPartyCloudflareSetupState();
}

class _WatchPartyCloudflareSetupState extends State<WatchPartyCloudflareSetup> {
  late final _deployer = widget.deployer ?? CloudflareRelayDeployer();
  final _token = TextEditingController();
  final _worker = TextEditingController(text: 'nova-watch-party');
  final _subdomain = TextEditingController();
  List<CloudflareRelayAccount> _accounts = const [];
  String? _accountId, _existingSubdomain, _error, _notice;
  bool _working = false, _complete = false, _accountReady = false;
  bool? _exists;
  Uri? _endpoint;
  String _t(String key) => NovaStrings.of(context).text(key);

  void _ensureOutsideRoom() {
    final controller = context.read<WatchPartyController?>();
    if (controller == null || !controller.eligible) {
      throw const CloudflareRelayDeployException('partyAccountRequired');
    }
    if (controller.snapshot != null) {
      throw StateError('active_room');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
      _notice = null;
    });
    try {
      _ensureOutsideRoom();
      await action();
    } on CloudflareRelayDeployException catch (error) {
      if (mounted) {
        if (error.messageKey == 'partyRelayDeployPending') {
          _endpoint = _expectedEndpoint;
          _token.clear();
          _notice = error.messageKey;
        } else {
          _error = error.messageKey;
        }
      }
    } on StateError {
      if (mounted) _error = 'partyRelayRoomLocked';
    } catch (_) {
      if (mounted) _error = 'partyRelayDeployFailed';
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _loadAccounts() => _run(() async {
        final accounts = await _deployer.listAccounts(_token.text);
        if (accounts.isEmpty) {
          throw const CloudflareRelayDeployException('partyRelayDeployAccount');
        }
        if (!mounted) return;
        _accounts = accounts;
        await _selectAccount(accounts.first.id);
      });

  Future<void> _selectAccount(String id) async {
    _accountId = id;
    _accountReady = false;
    _existingSubdomain = null;
    _subdomain.clear();
    _exists = null;
    _endpoint = null;
    _existingSubdomain =
        await _deployer.workersSubdomain(token: _token.text, accountId: id);
    if (mounted) {
      _subdomain.text = _existingSubdomain ?? '';
      _accountReady = true;
    }
  }

  Uri? get _expectedEndpoint {
    final worker = _worker.text.trim();
    final subdomain = _subdomain.text.trim();
    if (!RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(worker) ||
        !RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(subdomain)) {
      return null;
    }
    return Uri.https('$worker.$subdomain.workers.dev');
  }

  Future<void> _deploy() => _run(() async {
        if (_accountId == null || !_accountReady) {
          throw const CloudflareRelayDeployException('partyRelayDeployAccount');
        }
        final endpoint = await _deployer.deploy(
            token: _token.text,
            accountId: _accountId!,
            workerName: _worker.text.trim(),
            subdomain: _subdomain.text.trim());
        if (!mounted) return;
        _ensureOutsideRoom();
        await widget.settings.configure(endpoint.origin);
        if (!mounted) return;
        _token.clear();
        _endpoint = endpoint;
        _complete = true;
        _notice = 'partyRelayDeploySuccess';
      });

  Future<void> _status() => _run(() async {
        if (_accountId == null) {
          throw const CloudflareRelayDeployException('partyRelayDeployAccount');
        }
        final exists = await _deployer.status(
            token: _token.text,
            accountId: _accountId!,
            workerName: _worker.text.trim());
        if (!mounted) return;
        _exists = exists;
        _notice = exists ? 'partyRelayDeployExists' : 'partyRelayDeployAbsent';
        if (exists) _endpoint = _expectedEndpoint;
      });

  Future<void> _retryEndpoint() => _run(() async {
        final endpoint = _endpoint;
        if (endpoint == null) return;
        await widget.settings.check(endpoint: endpoint.origin);
        if (!mounted) return;
        _ensureOutsideRoom();
        await widget.settings.configure(endpoint.origin);
        if (!mounted) return;
        _token.clear();
        _complete = true;
        _notice = 'partyRelayDeploySuccess';
      });

  Future<void> _remove() async {
    var accepted = false;
    final confirmed = await showNovaDialog<bool>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (dialog, change) => NovaGlassDialog(
                    scrollable: true,
                    title: Text(_t('partyRelayDeployRemove')),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(NovaStrings.of(context).text(
                          'partyRelayDeployRemoveBody',
                          {'name': _worker.text.trim()})),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: accepted,
                          onChanged: (value) =>
                              change(() => accepted = value == true),
                          title: Text(_t('partyRelayDeployRemoveConfirm')))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: Text(_t('partyCancel'))),
                      FilledButton(
                          onPressed: accepted
                              ? () => Navigator.pop(dialog, true)
                              : null,
                          child: Text(_t('partyRelayDeployRemove')))
                    ])));
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await _deployer.remove(
          token: _token.text,
          accountId: _accountId!,
          workerName: _worker.text.trim());
      if (!mounted) return;
      if (widget.settings.endpoint == _expectedEndpoint?.origin) {
        await widget.settings.reset();
      }
      if (!mounted) return;
      _token.clear();
      _accounts = const [];
      _accountId = null;
      _exists = false;
      _endpoint = null;
      _notice = 'partyRelayDeployRemoved';
    });
  }

  @override
  void dispose() {
    _token.dispose();
    _worker.dispose();
    _subdomain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_working,
      child: NovaGlassDialog(
          scrollable: true,
          constraints: const BoxConstraints(maxWidth: 560),
          title: Text(_t('partyRelaySetup')),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('partyRelaySetupBody')),
                if (!_complete) ...[
                  const SizedBox(height: 16),
                  Text(_t('partyRelayDeployPermissions'),
                      style: Theme.of(context).textTheme.bodySmall),
                  TextButton.icon(
                      onPressed: _working
                          ? null
                          : () => _run(() async {
                                if (!await launchUrl(
                                    Uri.parse(
                                        'https://dash.cloudflare.com/profile/api-tokens'),
                                    mode: LaunchMode.externalApplication)) {
                                  throw const CloudflareRelayDeployException(
                                      'partyRelayDeployFailed');
                                }
                              }),
                      icon: const Icon(LucideIcons.externalLink, size: 18),
                      label: Text(_t('partyRelayDeployCreateToken'))),
                  const SizedBox(height: 24),
                  TextField(
                      key: const ValueKey('party-cloudflare-token'),
                      controller: _token,
                      enabled: !_working,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      autofillHints: const [],
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                          labelText: _t('partyRelayDeployTokenLabel')),
                      onChanged: (_) {
                        if (_accounts.isNotEmpty) {
                          setState(() {
                            _accounts = const [];
                            _accountId = null;
                            _exists = null;
                            _endpoint = null;
                            _accountReady = false;
                          });
                        }
                      }),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _working ? null : _loadAccounts,
                      child: Text(_t('partyRelayDeployLoadAccounts'))),
                  if (_accounts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(_t('partyRelayDeployAccountLabel'),
                        style: Theme.of(context).textTheme.labelLarge),
                    for (final account in _accounts)
                      Semantics(
                          button: true,
                          selected: account.id == _accountId,
                          child: InkWell(
                              onTap: _working
                                  ? null
                                  : () =>
                                      _run(() => _selectAccount(account.id)),
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minHeight: 48),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(account.id == _accountId
                                                ? LucideIcons.circleCheck
                                                : LucideIcons.circle),
                                            const SizedBox(width: 12),
                                            Expanded(child: Text(account.name))
                                          ]))))),
                    const SizedBox(height: 16),
                    TextField(
                        key: const ValueKey('party-cloudflare-subdomain'),
                        controller: _subdomain,
                        enabled: !_working && _existingSubdomain == null,
                        autocorrect: false,
                        enableSuggestions: false,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                            labelText: _t('partyRelayDeploySubdomainLabel'))),
                    if (_existingSubdomain == null)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_t('partyRelayDeploySubdomainBody'),
                              style: Theme.of(context).textTheme.bodySmall)),
                    const SizedBox(height: 16),
                    TextField(
                        key: const ValueKey('party-cloudflare-worker'),
                        controller: _worker,
                        enabled: !_working,
                        autocorrect: false,
                        enableSuggestions: false,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                            labelText: _t('partyRelayDeployWorkerLabel')),
                        onChanged: (_) => setState(() {
                              _exists = null;
                              _endpoint = null;
                            })),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton(
                          onPressed:
                              _working || !_accountReady || _token.text.isEmpty
                                  ? null
                                  : _deploy,
                          child: Text(_t('partyRelayDeployAction'))),
                      TextButton(
                          onPressed:
                              _working || _token.text.isEmpty ? null : _status,
                          child: Text(_t('partyRelayDeployStatus'))),
                      if (_exists == true)
                        TextButton(
                            onPressed: _working || _token.text.isEmpty
                                ? null
                                : _remove,
                            child: Text(_t('partyRelayDeployRemove')))
                    ])
                  ]
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
                          child: Text(_t(_error ?? _notice!),
                              style: TextStyle(
                                  color: _error == null
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                      : Theme.of(context).colorScheme.error)))),
                if (_endpoint case final endpoint?) ...[
                  const SizedBox(height: 16),
                  SelectableText(endpoint.origin,
                      textDirection: TextDirection.ltr),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    TextButton.icon(
                        onPressed: () => Clipboard.setData(
                            ClipboardData(text: endpoint.origin)),
                        icon: const Icon(LucideIcons.copy, size: 18),
                        label: Text(_t('partyCopyRelay'))),
                    if (!_complete)
                      OutlinedButton(
                          onPressed: _working ? null : _retryEndpoint,
                          child: Text(_t('partyRelayDeployRetry')))
                  ])
                ]
              ]),
          actions: [
            TextButton(
                onPressed: _working
                    ? null
                    : () {
                        _token.clear();
                        Navigator.pop(context);
                      },
                child: Text(_t('close')))
          ]));
}
