import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/watch_party/watch_party_controller.dart';
import '../../core/watch_party/watch_party_invite.dart';
import '../../core/watch_party/watch_party_models.dart';
import '../../core/watch_party/watch_party_relay_settings.dart';
import '../../l10n/nova_strings.dart';
import '../../shared/widgets/nova_network_image.dart';
import '../../shared/widgets/nova_ios_controls.dart';
import 'watch_party_playback.dart';
import 'watch_party_join_dialog.dart';
import 'widgets/watch_party_chat.dart';
import 'widgets/watch_party_connection_settings.dart';

typedef WatchPartyPlaybackLauncher = Future<void> Function(
    BuildContext context, WatchPartySnapshot room);

Future<void> openWatchParty(BuildContext context,
        {WatchPartyMedia? media,
        WatchPartySource? source,
        int positionMs = 0,
        bool playing = false,
        double rate = 1,
        bool followPlayback = false,
        WatchPartyPlaybackLauncher? onJoinPlayback}) =>
    Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => WatchPartyPage(
            media: media,
            source: source,
            positionMs: positionMs,
            playing: playing,
            rate: rate,
            followPlayback: followPlayback,
            onJoinPlayback: onJoinPlayback)));

/// The room stays available while its underlying player keeps running.
class WatchPartyPage extends StatefulWidget {
  const WatchPartyPage(
      {super.key,
      this.initialCode,
      this.media,
      this.source,
      this.positionMs = 0,
      this.playing = false,
      this.rate = 1,
      this.followPlayback = false,
      this.onJoinPlayback});
  final String? initialCode;
  final WatchPartyMedia? media;
  final WatchPartySource? source;
  final int positionMs;
  final bool playing;
  final double rate;
  final bool followPlayback;
  final WatchPartyPlaybackLauncher? onJoinPlayback;
  @override
  State<WatchPartyPage> createState() => _WatchPartyPageState();
}

class _WatchPartyPageState extends State<WatchPartyPage>
    with SingleTickerProviderStateMixin {
  late final _code = TextEditingController(text: widget.initialCode);
  late final _tabs = TabController(length: 2, vsync: this);
  final _message = TextEditingController();
  bool _working = false;
  bool _detailsOpen = false;
  bool _newHostOnly = false;
  bool _newSourceLocked = false;
  String? _error;
  String _t(String key) => NovaStrings.of(context).text(key);
  @override
  void initState() {
    super.initState();
    if (widget.followPlayback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        final controller = context.read<WatchPartyController?>();
        final room = controller?.snapshot;
        if (controller?.eligible == true && room?.media != null) {
          unawaited(_run(() => _joinPlayback(room!)));
        }
      });
    }
  }

  bool _canReturnToPlayer(WatchPartySnapshot room) =>
      widget.media?.key == room.media?.key &&
      (!room.sourceLocked ||
          (widget.source != null && widget.source!.key == room.source?.key));

  Future<void> _pasteInvite() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    final code = watchPartyCodeFromInput(data!.text!);
    if (code != null) {
      _code.text = parseWatchPartyInvitation(data.text!) != null
          ? data.text!.trim()
          : code;
      setState(() => _error = null);
    } else {
      setState(() => _error = 'partyNotFound');
    }
  }

  Future<void> _joinCode(WatchPartyController controller) async {
    await joinWatchPartyInput(context, controller, _code.text);
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

  Future<void> _copyInvite(WatchPartySnapshot room) async {
    await Clipboard.setData(
        ClipboardData(text: watchPartyInvite(room.code, relay: _activeRelay)));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_t('partyCopied'))));
    }
  }

  Uri? get _activeRelay {
    final settings = context.read<WatchPartyRelaySettings?>();
    return settings?.enabled == true ? Uri.tryParse(settings!.endpoint!) : null;
  }

  Future<void> _copyRelay(Uri relay) async {
    await Clipboard.setData(ClipboardData(text: relay.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_t('partyRelayCopied'))));
    }
  }

  Future<void> _confirmLeave(WatchPartyController controller,
      {required bool end}) async {
    final confirmed = await NovaIosControls.confirm(
      context,
      title: _t(end ? 'partyEnd' : 'partyLeave'),
      message: _t(end ? 'partyEndBody' : 'partyLeaveBody'),
      confirmLabel: _t(end ? 'partyEnd' : 'partyLeave'),
      cancelLabel: _t('partyCancel'),
      destructive: end,
    );
    if (confirmed == true && mounted) {
      await _run(end ? controller.end : controller.leave);
    }
  }

  Future<void> _joinPlayback(WatchPartySnapshot room) async {
    if (widget.onJoinPlayback != null) {
      await widget.onJoinPlayback!(context, room);
    } else {
      await launchWatchPartyPlayback(context,
          room: room, returnToPlayer: _canReturnToPlayer(room));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _code.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WatchPartyController?>();
    final room = controller?.snapshot;
    final error = _error ?? controller?.errorKey;
    final eligible = controller?.eligible == true;
    final tabHeight = (MediaQuery.textScalerOf(context).scale(14) * 1.3 + 24)
        .clamp(48.0, 120.0);
    return Scaffold(
        appBar: AppBar(
            title: Text(_t('partyTitle'),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (room != null) ...[
                IconButton(
                    tooltip: _t('partyRefresh'),
                    onPressed: _working
                        ? null
                        : () => unawaited(_run(() => controller!.refresh())),
                    icon: const Icon(LucideIcons.refreshCw)),
                NovaPopupMenuButton<String>(
                    key: const ValueKey('party-room-menu'),
                    icon: const Icon(LucideIcons.ellipsisVertical),
                    tooltip: _t('partyRoomOptions'),
                    enabled: !_working,
                    onSelected: (action) => unawaited(
                        _confirmLeave(controller!, end: action == 'end')),
                    itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'leave', child: Text(_t('partyLeave'))),
                          if (room.isHost)
                            PopupMenuItem(
                                value: 'end', child: Text(_t('partyEnd')))
                        ])
              ]
            ],
            bottom: room != null && eligible
                ? PreferredSize(
                    preferredSize: Size.fromHeight(tabHeight),
                    child: TabBar(
                        controller: _tabs,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          Tab(
                              key: const ValueKey('party-room-tab'),
                              height: tabHeight,
                              text: _t('partyRoom')),
                          Tab(
                              key: const ValueKey('party-chat-tab'),
                              height: tabHeight,
                              text: _t('partyChat'))
                        ]))
                : null),
        body: SafeArea(
            child: LayoutBuilder(
                builder: (context, constraints) => Column(children: [
                      if (error != null)
                        ConstrainedBox(
                            constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight * .3),
                            child: SingleChildScrollView(
                                child: _errorBanner(error))),
                      Expanded(
                          child: !eligible
                              ? _accountRequired()
                              : room == null
                                  ? _entry(controller!)
                                  : TabBarView(controller: _tabs, children: [
                                      _room(controller!, room),
                                      WatchPartyChat(
                                          controller: controller,
                                          room: room,
                                          messageController: _message)
                                    ]))
                    ]))));
  }

  Widget _errorBanner(String error) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
        liveRegion: true,
        child: Container(
            width: double.infinity,
            color: scheme.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(LucideIcons.circleAlert,
                  color: scheme.onErrorContainer, size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(_t(error),
                      style: TextStyle(color: scheme.onErrorContainer)))
            ])));
  }

  Widget _accountRequired() => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.usersRound, size: 48),
                const SizedBox(height: 24),
                Text(_t('partyAccountRequired'),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center)
              ]))));

  Widget _entry(WatchPartyController controller) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
              key: const PageStorageKey('party-entry'),
              padding: EdgeInsets.all(
                  NovaSpace.gutter(MediaQuery.sizeOf(context).width)),
              children: [
                const SizedBox(height: 16),
                Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Icon(LucideIcons.usersRound,
                        size: 40,
                        color: Theme.of(context).colorScheme.secondary)),
                const SizedBox(height: 24),
                Text(_t('partyStartTitle'),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(_t('partyIntro'),
                    style: Theme.of(context).textTheme.bodyLarge),
                if (widget.media != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _mediaIdentity(widget.media!, compact: true)),
                const SizedBox(height: 24),
                ExpansionTile(
                    key: const PageStorageKey('party-create-settings'),
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(_t('partyCreateSettings')),
                    children: [
                      NovaSwitchListTile(
                          key: const ValueKey('party-create-host-only'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(_t('partyHostOnly')),
                          subtitle: Text(_t('partyHostOnlyBody')),
                          value: _newHostOnly,
                          onChanged: _working
                              ? null
                              : (value) =>
                                  setState(() => _newHostOnly = value)),
                      NovaSwitchListTile(
                          key: const ValueKey('party-create-source-locked'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(_t('partySourceLocked')),
                          subtitle: Text(_t(widget.source == null
                              ? 'partySourceUnavailable'
                              : 'partySourceLockedBody')),
                          value: _newSourceLocked,
                          onChanged: _working || widget.source == null
                              ? null
                              : (value) =>
                                  setState(() => _newSourceLocked = value))
                    ]),
                const SizedBox(height: 16),
                FilledButton.icon(
                    onPressed: _working
                        ? null
                        : () => _run(() => controller.create(
                            media: widget.media,
                            source: widget.source,
                            hostOnly: _newHostOnly,
                            sourceLocked: _newSourceLocked,
                            positionMs: widget.positionMs,
                            playing: widget.playing,
                            rate: widget.rate)),
                    icon: const Icon(LucideIcons.plus, size: 20),
                    label: Text(_t(_working ? 'partyWorking' : 'partyCreate'))),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Divider()),
                Text(_t('partyJoin'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                    key: const ValueKey('party-code-input'),
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textDirection: TextDirection.ltr,
                    maxLength: 2048,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [],
                    decoration: InputDecoration(
                        labelText: _t('partyInviteOrCode'),
                        hintText: 'ABC DEF',
                        counterText: '',
                        suffixIcon: IconButton(
                            tooltip: _t('partyPasteInvite'),
                            onPressed: _working ? null : _pasteInvite,
                            icon: const Icon(LucideIcons.clipboard))),
                    onSubmitted: (_) =>
                        _working ? null : _run(() => _joinCode(controller))),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: _working
                        ? null
                        : () => _run(() => _joinCode(controller)),
                    child: Text(_t('partyJoin'))),
                const SizedBox(height: 24),
                if (context.watch<WatchPartyRelaySettings?>()
                    case final settings?)
                  ExpansionTile(
                      key: const PageStorageKey('party-connection-settings'),
                      tilePadding: EdgeInsets.zero,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(_t('partyRelayTitle')),
                      subtitle: Text(_t(settings.enabled
                          ? 'partyRelayCustom'
                          : 'partyRelayDefault')),
                      children: [
                        WatchPartyConnectionSettings(settings: settings)
                      ]),
                const SizedBox(height: 24)
              ])));

  Widget _room(WatchPartyController controller, WatchPartySnapshot room) =>
      Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                  key: const PageStorageKey('party-room-content'),
                  padding: EdgeInsets.all(
                      NovaSpace.gutter(MediaQuery.sizeOf(context).width)),
                  children: [
                    _invitation(controller, room),
                    const SizedBox(height: 32),
                    if (room.media case final media?) ...[
                      Text(_t('partyNowWatching'),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                      const SizedBox(height: 16),
                      _mediaIdentity(media),
                      const SizedBox(height: 12),
                      Text(
                          _t(room.playing
                              ? 'partyPlaybackPlaying'
                              : 'partyPlaybackPaused'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                          key: const ValueKey('party-join-playback'),
                          onPressed: _working
                              ? null
                              : () => _run(() => _joinPlayback(room)),
                          icon: const Icon(LucideIcons.play, size: 20),
                          label: Text(_t(_canReturnToPlayer(room)
                              ? 'partyReturnPlayback'
                              : 'partyJoinPlayback'))),
                      const SizedBox(height: 12),
                      Text(_t('partyLocalSources'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant))
                    ] else ...[
                      const Icon(LucideIcons.film, size: 40),
                      const SizedBox(height: 16),
                      Text(_t('partyChooseTitle'),
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(_t('partyChooseBody')),
                      if (room.isHost)
                        Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: FilledButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(LucideIcons.search),
                                label: Text(_t('partyBrowse'))))
                    ],
                    const SizedBox(height: 24),
                    _controlExplanation(room),
                    const SizedBox(height: 12),
                    _sourceExplanation(room),
                    const SizedBox(height: 24),
                    const Divider(),
                    _details(controller, room),
                    const SizedBox(height: 16)
                  ])));

  Widget _invitation(WatchPartyController controller, WatchPartySnapshot room) {
    final statusKey = room.waiting
        ? 'partyWaiting'
        : !controller.online || !controller.realtimeConnected
            ? 'partyReconnecting'
            : 'partyConnected';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
          liveRegion: true,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                    statusKey == 'partyConnected'
                        ? LucideIcons.radio
                        : LucideIcons.loaderCircle,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_t(statusKey),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)))
          ])),
      const SizedBox(height: 16),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('partyCode'),
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(formatWatchPartyCode(room.code),
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(letterSpacing: 2))
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton.outlined(
                  tooltip: _t('partyCopyInvite'),
                  onPressed: () => unawaited(_copyInvite(room)),
                  icon: const Icon(LucideIcons.copy, size: 20)),
              const SizedBox(width: 8),
              IconButton.outlined(
                  tooltip: _t('partyInvite'),
                  onPressed: () => SharePlus.instance.share(ShareParams(
                      text: watchPartyInvite(room.code, relay: _activeRelay),
                      sharePositionOrigin: Rect.fromLTWH(
                          0, 0, MediaQuery.sizeOf(context).width, 100))),
                  icon: const Icon(LucideIcons.userPlus, size: 20))
            ])
          ]),
      if (_activeRelay case final relay?) ...[
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_t('partyRelayCustom'),
                    style: Theme.of(context).textTheme.labelMedium),
                SelectableText(relay.toString(),
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(_t('partyRelaySameServer'),
                    style: Theme.of(context).textTheme.bodySmall)
              ])),
          IconButton(
              tooltip: _t('partyCopyRelay'),
              onPressed: () => _copyRelay(relay),
              icon: const Icon(LucideIcons.copy, size: 18))
        ])
      ]
    ]);
  }

  Widget _mediaIdentity(WatchPartyMedia media, {bool compact = false}) {
    final text = Theme.of(context).textTheme;
    final posterWidth = compact ? 64.0 : 88.0;
    final identity =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(media.title, style: compact ? text.titleMedium : text.headlineSmall),
      if (media.season != null) ...[
        const SizedBox(height: 8),
        Text(
            NovaStrings.of(context).text('partyEpisode',
                {'season': media.season, 'episode': media.episode}),
            style: text.bodyMedium)
      ]
    ]);
    return LayoutBuilder(builder: (context, constraints) {
      final showPoster = constraints.maxWidth >= 280 &&
          MediaQuery.textScalerOf(context).scale(14) < 25;
      if (!showPoster) return identity;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
                width: posterWidth,
                height: posterWidth * 1.5,
                child: media.poster?.isNotEmpty == true
                    ? NovaNetworkImage(media.poster!,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        cacheWidth: 264)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                            borderRadius: BorderRadius.circular(16)),
                        child: const Center(
                            child: Icon(LucideIcons.film, size: 28))))),
        const SizedBox(width: 16),
        Expanded(child: identity)
      ]);
    });
  }

  Widget _controlExplanation(WatchPartySnapshot room) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
                room.hostOnly ? LucideIcons.crown : LucideIcons.usersRound,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(
                _t(room.hostOnly ? 'partyHostControl' : 'partyGroupControl'),
                style: Theme.of(context).textTheme.bodyMedium))
      ]);

  Widget _sourceExplanation(WatchPartySnapshot room) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(room.sourceLocked ? LucideIcons.link : LucideIcons.layers,
            size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _t(room.sourceLocked
                  ? 'partySourceLocked'
                  : 'partySourceIndependent'),
              style: Theme.of(context).textTheme.bodyMedium),
          if (room.sourceLocked && room.source != null)
            Text(room.source!.name,
                style: Theme.of(context).textTheme.bodySmall)
        ]))
      ]);

  Widget _details(WatchPartyController controller, WatchPartySnapshot room) =>
      ExpansionTile(
          key: const PageStorageKey('party-room-details'),
          initiallyExpanded: _detailsOpen,
          onExpansionChanged: (open) => setState(() => _detailsOpen = open),
          trailing: AnimatedRotation(
              turns: _detailsOpen ? .5 : 0,
              duration: NovaMotion.duration(context, NovaMotion.state),
              curve: NovaMotion.curve,
              child: const Icon(LucideIcons.chevronDown)),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(_t('partyRoomDetails'),
              style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text('${_t('partyMembers')} · ${room.members.length}/8'),
          children: [
            if (room.isHost)
              NovaSwitchListTile(
                  key: const ValueKey('party-host-control-switch'),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  title: Text(_t('partyHostOnly')),
                  subtitle: Text(_t('partyHostOnlyBody')),
                  value: room.hostOnly,
                  onChanged: _working
                      ? null
                      : (value) => _run(() => controller.configure(value))),
            if (room.isHost)
              NovaSwitchListTile(
                  key: const ValueKey('party-source-mode-switch'),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  title: Text(_t('partySourceLocked')),
                  subtitle: Text(_t(room.source == null && widget.source == null
                      ? 'partySourceUnavailable'
                      : 'partySourceLockedBody')),
                  value: room.sourceLocked,
                  onChanged:
                      _working || (room.source == null && widget.source == null)
                          ? null
                          : (value) => _run(() => controller.configure(
                              room.hostOnly,
                              sourceLocked: value,
                              source: room.source ?? widget.source))),
            for (final member in room.members)
              _member(controller, room, member),
            if (context.watch<WatchPartyRelaySettings?>() != null)
              Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                      onPressed: () => showWatchPartyConnectionDialog(context),
                      icon: const Icon(LucideIcons.radio, size: 18),
                      label: Text(_t('partyRelayTitle')))),
            const SizedBox(height: 16)
          ]);

  Widget _member(WatchPartyController controller, WatchPartySnapshot room,
          WatchPartyMember member) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
                radius: 20,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                child: Icon(
                    member.id == room.hostId
                        ? LucideIcons.crown
                        : LucideIcons.userRound,
                    size: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      member.id == room.selfId
                          ? '${member.name} · ${_t('partyYou')}'
                          : member.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                      _t(member.id == room.hostId
                          ? 'partyHost'
                          : switch (member.status) {
                              'ready' => 'partyReady',
                              'buffering' || 'loading' => 'partyLoading',
                              _ => 'partyBrowsing'
                            }),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant))
                ])),
            if (room.isHost && member.id != room.selfId)
              NovaPopupMenuButton<String>(
                  icon: const Icon(LucideIcons.ellipsisVertical),
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
          ]));
}
