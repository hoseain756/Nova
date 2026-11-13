import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/watch_party/watch_party_controller.dart';
import '../../core/watch_party/watch_party_invite.dart';
import '../../core/watch_party/watch_party_models.dart';
import '../../core/watch_party/watch_party_relay_settings.dart';
import '../../l10n/nova_strings.dart';
import 'widgets/watch_party_connection_settings.dart';

Future<bool> showWatchPartyJoinDialog(BuildContext context,
        {String? initialInvite}) async =>
    await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => WatchPartyJoinDialog(initialInvite: initialInvite)) ??
    false;

/// A link can propose a relay, but cannot contact or select it without consent.
Future<bool> joinWatchPartyInput(
    BuildContext context, WatchPartyController controller, String input) async {
  if (!controller.eligible) {
    throw const WatchPartyException('account_required');
  }
  final identity = controller.identityScope;
  WatchPartyController checkedController() {
    final active = context.read<WatchPartyController?>();
    if (active == null ||
        !active.eligible ||
        active.identityScope != identity) {
      throw const WatchPartyException('account_required');
    }
    if (active.snapshot != null) {
      throw const WatchPartyException('already_in_room');
    }
    return active;
  }

  if (controller.snapshot != null) {
    throw const WatchPartyException('already_in_room');
  }
  final invitation = parseWatchPartyInvitation(input);
  final code = invitation?.code ?? watchPartyCodeFromInput(input);
  if (code == null) throw const WatchPartyException('not_found');
  final settings = context.read<WatchPartyRelaySettings?>();
  final relay = invitation?.relay;
  final switching = invitation != null &&
      (relay == null
          ? settings?.enabled == true
          : settings?.enabled != true ||
              settings?.endpoint != relay.toString());
  if (switching) {
    if (settings == null) throw const WatchPartyException('relay_check_failed');
    final strings = NovaStrings.of(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                scrollable: true,
                title: Text(strings.text('partyRelayConfirmTitle')),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.text('partyRelayConfirmBody')),
                      const SizedBox(height: 16),
                      SelectableText(
                          relay?.toString() ??
                              strings.text('partyRelayDefault'),
                          textDirection: TextDirection.ltr)
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: Text(strings.text('partyCancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: Text(strings.text('partyRelayConnectAndJoin')))
                ]));
    if (confirmed != true || !context.mounted) return false;
    checkedController();
    if (relay == null) {
      await settings.useSupabase();
    } else {
      try {
        await settings.check(endpoint: relay.toString());
      } catch (_) {
        throw const WatchPartyException('relay_check_failed');
      }
      if (!context.mounted) return false;
      checkedController();
      await settings.configure(relay.toString());
    }
    // WatchPartyScope replaces its transport/controller on the next rebuild.
    await WidgetsBinding.instance.endOfFrame;
  }
  if (!context.mounted) return false;
  await checkedController().join(code);
  return true;
}

/// The Home shortcut joins before opening the room destination.
class WatchPartyJoinDialog extends StatefulWidget {
  const WatchPartyJoinDialog({super.key, this.initialInvite});
  final String? initialInvite;
  @override
  State<WatchPartyJoinDialog> createState() => _WatchPartyJoinDialogState();
}

class _WatchPartyJoinDialogState extends State<WatchPartyJoinDialog> {
  late final _input = TextEditingController(text: widget.initialInvite);
  bool _working = false;
  String? _error;
  String _t(String key) => NovaStrings.of(context).text(key);

  Future<void> _join(WatchPartyController controller) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final joined =
          await joinWatchPartyInput(context, controller, _input.text);
      if (mounted && joined) Navigator.pop(context, true);
    } on WatchPartyException catch (error) {
      if (mounted) setState(() => _error = error.messageKey);
    } catch (_) {
      if (mounted) setState(() => _error = 'partyUnavailable');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    _input.text = data!.text!.trim();
    setState(() => _error = null);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WatchPartyController?>();
    final eligible = controller?.eligible == true;
    final relay = context.watch<WatchPartyRelaySettings?>();
    return PopScope(
        canPop: !_working,
        child: AlertDialog(
            scrollable: true,
            constraints: const BoxConstraints(maxWidth: 520),
            title: Text(_t('partyJoin')),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t(
                      eligible ? 'partyJoinPrompt' : 'partyAccountRequired')),
                  if (eligible) ...[
                    const SizedBox(height: 24),
                    TextField(
                        key: const ValueKey('party-invite-input'),
                        controller: _input,
                        enabled: !_working,
                        autofocus: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.go,
                        maxLength: 2048,
                        decoration: InputDecoration(
                            labelText: _t('partyInviteOrCode'),
                            hintText: 'ABC DEF',
                            counterText: '',
                            suffixIcon: IconButton(
                                tooltip: _t('partyPasteInvite'),
                                onPressed: _working ? null : _paste,
                                icon: const Icon(LucideIcons.clipboard))),
                        onChanged: (_) => setState(() => _error = null),
                        onSubmitted: (_) => _join(controller!)),
                    if (parseWatchPartyInvitation(_input.text)?.relay
                        case final proposed?)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                              NovaStrings.of(context).text(
                                  'partyRelayInvitation',
                                  {'server': proposed.host}),
                              style: Theme.of(context).textTheme.bodySmall)),
                    if (relay != null) ...[
                      const SizedBox(height: 16),
                      Text(
                          _t(relay.enabled
                              ? 'partyRelayCustom'
                              : 'partyRelayDefault'),
                          style: Theme.of(context).textTheme.labelLarge),
                      if (relay.enabled) ...[
                        const SizedBox(height: 4),
                        Text(relay.endpoint!,
                            textDirection: TextDirection.ltr,
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(_t('partyRelaySameServer'),
                            style: Theme.of(context).textTheme.bodySmall)
                      ],
                      TextButton.icon(
                          onPressed: _working
                              ? null
                              : () => showWatchPartyConnectionDialog(context),
                          icon: const Icon(LucideIcons.settings2, size: 18),
                          label: Text(_t('partyRelayTitle')))
                    ]
                  ],
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(_t(_error!),
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))))
                ]),
            actions: [
              TextButton(
                  onPressed:
                      _working ? null : () => Navigator.pop(context, false),
                  child: Text(_t('partyCancel'))),
              if (eligible)
                FilledButton(
                    onPressed: _working ? null : () => _join(controller!),
                    child: Text(_t(_working ? 'partyWorking' : 'partyJoin')))
            ]));
  }
}
