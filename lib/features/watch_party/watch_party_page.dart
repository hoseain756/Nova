import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/watch_party/watch_party_controller.dart';
import '../../core/watch_party/watch_party_invite.dart';
import '../../core/watch_party/watch_party_models.dart';
import '../../l10n/nova_strings.dart';
import '../media/media_detail_page.dart';

Future<void> openWatchParty(BuildContext context,
        {WatchPartyMedia? media,
        int positionMs = 0,
        bool playing = false,
        double rate = 1}) =>
    Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => WatchPartyPage(
            media: media,
            positionMs: positionMs,
            playing: playing,
            rate: rate)));

/// A persistent destination, also reachable while the player keeps running.
class WatchPartyPage extends StatefulWidget {
  const WatchPartyPage(
      {super.key,
      this.initialCode,
      this.media,
      this.positionMs = 0,
      this.playing = false,
      this.rate = 1});
  final String? initialCode;
  final WatchPartyMedia? media;
  final int positionMs;
  final bool playing;
  final double rate;
  @override
  State<WatchPartyPage> createState() => _WatchPartyPageState();
}

class _WatchPartyPageState extends State<WatchPartyPage> {
  late final TextEditingController _code =
      TextEditingController(text: widget.initialCode);
  final _message = TextEditingController();
  bool _working = false;
  String? _error;
  String _t(String key) => NovaStrings.of(context).text(key);
  Future<void> _pasteInvite() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    final code = parseWatchPartyInvite(data!.text!) ??
        normalizeWatchPartyCode(data.text!);
    if (validWatchPartyCode(code)) {
      _code.text = code;
      setState(() => _error = null);
    } else {
      setState(() => _error = 'partyNotFound');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } on WatchPartyException catch (error) {
      if (mounted) _error = error.messageKey;
    } catch (_) {
      if (mounted) _error = 'partyUnavailable';
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WatchPartyController?>();
    final room = controller?.snapshot;
    final scheme = Theme.of(context).colorScheme;
    final error = _error ?? controller?.errorKey;
    return Scaffold(
      appBar: AppBar(title: Text(_t('partyTitle')), actions: [
        if (room != null)
          IconButton(
              tooltip: _t('partyRefresh'),
              onPressed:
                  _working ? null : () => unawaited(controller!.refresh()),
              icon: const Icon(LucideIcons.refreshCw))
      ]),
      body: SafeArea(
          child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(_t(error),
                                style: TextStyle(color: scheme.error)))),
                  if (controller == null || !controller.eligible) ...[
                    const Icon(LucideIcons.usersRound, size: 48),
                    const SizedBox(height: 24),
                    Text(_t('partyAccountRequired'),
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center),
                  ] else if (room == null)
                    ..._entry(controller)
                  else
                    ..._room(controller, room),
                ]),
              ))),
    );
  }

  List<Widget> _entry(WatchPartyController controller) => [
        Text(_t('partyStartTitle'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(_t('partyIntro')),
        if (widget.media != null)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(widget.media!.title,
                  style: Theme.of(context).textTheme.titleMedium)),
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: _working
                ? null
                : () => _run(() => controller.create(
                    media: widget.media,
                    positionMs: widget.positionMs,
                    playing: widget.playing,
                    rate: widget.rate)),
            icon: const Icon(LucideIcons.usersRound),
            label: Text(_t(_working ? 'partyWorking' : 'partyCreate'))),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 24), child: Divider()),
        Text(_t('partyJoin'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            textDirection: TextDirection.ltr,
            maxLength: 11,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z2-9\s-]'))
            ],
            decoration: InputDecoration(
                labelText: _t('partyCode'),
                hintText: 'ABCD EFGH',
                counterText: '',
                suffixIcon: IconButton(
                    tooltip: _t('partyPasteInvite'),
                    onPressed: _working ? null : _pasteInvite,
                    icon: const Icon(LucideIcons.clipboard))),
            onSubmitted: (_) =>
                _working ? null : _run(() => controller.join(_code.text))),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed:
                _working ? null : () => _run(() => controller.join(_code.text)),
            child: Text(_t('partyJoin'))),
      ];
  List<Widget> _room(WatchPartyController controller, WatchPartySnapshot room) {
    final media = room.media;
    return [
      Semantics(
          liveRegion: true,
          child: Text(
              _t(room.waiting
                  ? 'partyWaiting'
                  : !controller.online || !controller.realtimeConnected
                      ? 'partyReconnecting'
                      : 'partyConnected'),
              style: Theme.of(context).textTheme.labelLarge)),
      const SizedBox(height: 16),
      Text(_t('partyCode'), style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 4),
      SelectableText('${room.code.substring(0, 4)} ${room.code.substring(4)}',
          textDirection: TextDirection.ltr,
          style: Theme.of(context)
              .textTheme
              .headlineLarge
              ?.copyWith(letterSpacing: 3)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                  ClipboardData(text: watchPartyInvite(room.code)));
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(_t('partyCopied'))));
              }
            },
            icon: const Icon(LucideIcons.copy, size: 18),
            label: Text(_t('partyCopyInvite'))),
        OutlinedButton.icon(
            onPressed: () => SharePlus.instance.share(ShareParams(
                text: watchPartyInvite(room.code),
                sharePositionOrigin: Rect.fromLTWH(
                    0, 0, MediaQuery.sizeOf(context).width, 100))),
            icon: const Icon(LucideIcons.share2, size: 18),
            label: Text(_t('partyShare'))),
      ]),
      const SizedBox(height: 24),
      if (media != null) ...[
        Text(media.title, style: Theme.of(context).textTheme.titleLarge),
        if (media.season != null)
          Text(NovaStrings.of(context).text('partyEpisode',
              {'season': media.season, 'episode': media.episode})),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () {
              if (widget.media?.key == media.key) {
                Navigator.pop(context);
                return;
              }
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => MediaDetailPage(
                      item: media.item,
                      resumeVideoId: media.videoId,
                      resumeSeason: media.season,
                      resumeEpisode: media.episode,
                      resumePositionMs: room.targetMs(controller.clock.nowMs),
                      resumeAtPausePoint: false)));
            },
            icon: const Icon(LucideIcons.play),
            label: Text(_t('partyWatch'))),
        const SizedBox(height: 8),
        Text(_t('partyLocalSources'),
            style: Theme.of(context).textTheme.bodySmall),
      ] else ...[
        Text(_t('partyChooseTitle'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(_t('partyChooseBody')),
        if (room.isHost)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_t('partyBrowse')))),
      ],
      const SizedBox(height: 24),
      if (room.isHost)
        SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(_t('partyHostOnly')),
            subtitle: Text(_t('partyHostOnlyBody')),
            value: room.hostOnly,
            onChanged: _working
                ? null
                : (value) => _run(() => controller.configure(value))),
      Text('${_t('partyMembers')} (${room.members.length}/8)',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final member in room.members)
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
                child: Icon(member.id == room.hostId
                    ? LucideIcons.crown
                    : LucideIcons.userRound)),
            title: Text(member.name),
            subtitle: Text(_t(member.id == room.hostId
                ? 'partyHost'
                : switch (member.status) {
                    'ready' => 'partyReady',
                    'buffering' || 'loading' => 'partyLoading',
                    _ => 'partyBrowsing'
                  })),
            trailing: room.isHost && member.id != room.selfId
                ? PopupMenuButton<String>(
                    tooltip: _t('partyMemberActions'),
                    enabled: !_working,
                    onSelected: (action) => _run(() => action == 'transfer'
                        ? controller.transfer(member.id)
                        : controller.remove(member.id)),
                    itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'transfer',
                              child: Text(_t('partyTransfer'))),
                          PopupMenuItem(
                              value: 'remove', child: Text(_t('partyRemove')))
                        ])
                : null),
      const Padding(
          padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
      Text(_t('partyChat'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (controller.messages.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_t('partyChatEmpty'))),
      for (final message in controller.messages)
        Padding(
            key: ValueKey(
                'party-message-${message.memberId}-${message.clientId}'),
            padding: const EdgeInsets.only(bottom: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(message.name, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(message.body),
              if (message.pending)
                Text(_t('partySending'),
                    style: Theme.of(context).textTheme.bodySmall),
              if (message.failed)
                TextButton.icon(
                    onPressed: () => unawaited(controller
                        .sendMessage(message.body, clientId: message.clientId)),
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: Text(_t('partyRetryMessage'))),
            ])),
      TextField(
          key: const ValueKey('party-message-input'),
          controller: _message,
          minLines: 1,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
              labelText: _t('partyMessage'),
              counterText: '${_message.text.runes.length}/500',
              errorText: _message.text.trim().runes.length > 500
                  ? _t('partyMessageLimit')
                  : null),
          onChanged: (_) => setState(() {})),
      Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
              onPressed: _message.text.trim().isEmpty ||
                      _message.text.trim().runes.length > 500
                  ? null
                  : () {
                      final body = _message.text;
                      _message.clear();
                      setState(() {});
                      unawaited(controller.sendMessage(body));
                    },
              icon: const Icon(LucideIcons.send, size: 18),
              label: Text(_t('partySend')))),
      const SizedBox(height: 24),
      Wrap(spacing: 16, runSpacing: 8, children: [
        OutlinedButton(
            onPressed: _working ? null : () => _run(controller.leave),
            child: Text(_t('partyLeave'))),
        if (room.isHost)
          TextButton(
              onPressed: _working
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialog) => AlertDialog(
                                  title: Text(_t('partyEnd')),
                                  content: Text(_t('partyEndBody')),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialog, false),
                                        child: Text(_t('partyCancel'))),
                                    FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialog, true),
                                        child: Text(_t('partyEnd')))
                                  ]));
                      if (confirmed == true && mounted) {
                        await _run(controller.end);
                      }
                    },
              child: Text(_t('partyEnd'))),
      ]),
    ];
  }
}
