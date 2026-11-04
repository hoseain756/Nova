import 'package:nova_mobile/l10n/nova_strings.dart';
import 'package:nova_mobile/shared/widgets/nova_network_image.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/data/iptv_parser.dart';
import '../../core/models/media_item.dart';
import '../../core/state/app_state.dart';
import '../shell/nova_browse_widgets.dart';
import '../../shared/widgets/app_state_message.dart';
import '../../shared/widgets/image_decode.dart';
import '../player/playback_entry_page.dart';

class LiveTvPage extends StatefulWidget {
  const LiveTvPage({super.key});

  @override
  State<LiveTvPage> createState() => _LiveTvPageState();
}

class _LiveTvPageState extends State<LiveTvPage> {
  List<_LiveChannel> _channels = const [];
  Map<String, List<IptvProgram>> _guide = const {};
  bool _loading = false;
  String? _error;
  String _group = 'all';
  String _query = '';
  int _loadToken = 0;

  List<Map<String, dynamic>> _playlists(AppState app) =>
      (app.webSettings['iptvPlaylists'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) => row['url'] is String)
          .toList();

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final token = ++_loadToken;
    final app = context.read<AppState>();
    final playlists = _playlists(app);
    if (playlists.isEmpty) {
      setState(() {
        _channels = const [];
        _guide = const {};
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final channels = <_LiveChannel>[];
    final guide = <String, List<IptvProgram>>{};
    var failures = 0;
    for (final playlist in playlists) {
      final url = playlist['url']!.toString();
      final name = (playlist['name'] ?? 'Playlist').toString();
      try {
        final text = await app.api.proxyText(url);
        final parsed = await compute(parseM3u, text);
        channels.addAll(parsed.map((channel) => _LiveChannel(
              playlistId: playlist['id']?.toString() ?? name,
              playlistName: name,
              channel: channel,
            )));
      } catch (_) {
        failures++;
      }

      final epgUrl = (playlist['epgUrl'] ?? '').toString().trim();
      if (epgUrl.isNotEmpty) {
        try {
          final xml = await app.api.proxyText(epgUrl);
          final parsed = await compute(parseXmltv, xml);
          for (final entry in parsed.entries) {
            guide.putIfAbsent(entry.key, () => []).addAll(entry.value);
          }
        } catch (_) {
          // A missing or malformed guide must not hide usable channels.
        }
      }
    }
    if (!mounted || token != _loadToken) return;
    setState(() {
      _channels = channels;
      _guide = guide;
      _loading = false;
      if (channels.isEmpty && failures > 0) {
        _error = NovaStrings.lookup(app.english, 'message653');
      }
    });
  }

  Future<void> _addPlaylist() async {
    final english = context.read<AppState>().english;
    final entry = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _AddPlaylistDialog(english: english),
    );
    if (entry == null || !mounted) return;
    final app = context.read<AppState>();
    final playlists = _playlists(app);
    playlists.add({
      'id': 'mobile-${DateTime.now().microsecondsSinceEpoch}',
      'name': entry['name']!.isEmpty
          ? (NovaStrings.lookup(
              app.english, 'message654', {'p0': playlists.length + 1}))
          : entry['name'],
      'url': entry['url'],
      if (entry['epgUrl']?.isNotEmpty == true) 'epgUrl': entry['epgUrl'],
    });
    await app.setSetting('iptvPlaylists', playlists);
    await _reload();
  }

  Future<void> _removePlaylist(String id) async {
    final app = context.read<AppState>();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              icon: const Icon(LucideIcons.listVideo),
              title: Text(app.tr('message655')),
              content: Text(app.tr('message656')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(app.tr('cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(app.tr('remove')))
              ],
            ));
    if (confirmed != true || !mounted) return;
    final next = _playlists(app)
      ..removeWhere((playlist) => playlist['id']?.toString() == id);
    await app.setSetting('iptvPlaylists', next);
    await _reload();
  }

  IptvProgram? _nowProgram(IptvChannel channel) {
    final id = channel.tvgId;
    if (id == null) return null;
    final now = DateTime.now();
    for (final program in _guide[id] ?? const <IptvProgram>[]) {
      if (!now.isBefore(program.start) && now.isBefore(program.stop)) {
        return program;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final english = app.english;
    final groups = _channels
        .map((entry) =>
            entry.channel.group ?? (NovaStrings.lookup(english, 'message657')))
        .toSet()
        .toList()
      ..sort();
    final visible = _channels.where((entry) {
      final group =
          entry.channel.group ?? (NovaStrings.lookup(english, 'message657'));
      final matchesGroup = _group == 'all' || group == _group;
      final matchesQuery = _query.isEmpty ||
          entry.channel.name.toLowerCase().contains(_query.toLowerCase());
      return matchesGroup && matchesQuery;
    }).toList();
    final playlists = _playlists(app);
    return Scaffold(
        appBar: AppBar(title: Text(app.tr('message658')), actions: [
          IconButton(
              tooltip: app.tr('message68'),
              onPressed: _reload,
              icon: const Icon(LucideIcons.refreshCw))
        ]),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: RefreshIndicator(
              onRefresh: _reload,
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(
                    child: NovaBrowseHeader(
                        compact: true,
                        eyebrow: app.tr('message659'),
                        title: app.tr('message660'),
                        subtitle: app.tr('message661'),
                        actions: [
                      FilledButton.icon(
                          onPressed: _addPlaylist,
                          icon: const Icon(LucideIcons.plus),
                          label: Text(app.tr('message662')))
                    ])),
                if (playlists.isNotEmpty)
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              24, 0, 24, 24),
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final playlist in playlists)
                              InputChip(
                                  avatar: const Icon(LucideIcons.listVideo,
                                      size: 18),
                                  label: Text(
                                      (playlist['name'] ?? app.tr('message663'))
                                          .toString()),
                                  onDeleted: () => _removePlaylist(
                                      playlist['id']?.toString() ?? ''))
                          ]))),
                if (_channels.isNotEmpty) ...[
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              24, 0, 24, 16),
                          child: TextField(
                              onChanged: (value) =>
                                  setState(() => _query = value.trim()),
                              decoration: InputDecoration(
                                  prefixIcon: const Icon(LucideIcons.search),
                                  hintText: app.tr('message664'))))),
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              24, 0, 24, 24),
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            ChoiceChip(
                                label: Text(app.tr('message665')),
                                selected: _group == 'all',
                                onSelected: (_) =>
                                    setState(() => _group = 'all')),
                            for (final group in groups)
                              ChoiceChip(
                                  label: Text(group),
                                  selected: _group == group,
                                  onSelected: (_) =>
                                      setState(() => _group = group)),
                          ]))),
                ],
                if (_loading && _channels.isEmpty)
                  const SliverToBoxAdapter(
                      child: SizedBox(
                          height: 500, child: NovaBrowseSkeleton(rows: true)))
                else if (_error != null || playlists.isEmpty || visible.isEmpty)
                  SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppStateMessage(
                          icon: LucideIcons.radio,
                          message: _error ??
                              (playlists.isEmpty
                                  ? app.tr('message666')
                                  : app.tr('message667')),
                          actionLabel: playlists.isEmpty
                              ? app.tr('message662')
                              : app.tr('message68'),
                          onAction: playlists.isEmpty ? _addPlaylist : _reload))
                else ...[
                  if (_loading)
                    const SliverToBoxAdapter(
                        child: LinearProgressIndicator(minHeight: 2)),
                  SliverPadding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 48),
                    sliver: SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = visible[index];
                        final playable =
                            _isHttp(Uri.tryParse(entry.channel.url));
                        return _LiveChannelTile(
                          entry: entry,
                          program: _nowProgram(entry.channel),
                          playable: playable,
                          onTap: playable ? () => _play(entry) : null,
                        );
                      },
                    ),
                  ),
                ],
              ])),
        )));
  }

  Future<void> _play(_LiveChannel entry) async {
    final channel = entry.channel;
    final item = MediaItem(
      id: 'live:${entry.playlistId}:${channel.tvgId ?? channel.name}',
      type: 'movie',
      name: channel.name,
      poster: channel.logo,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PlaybackEntryPage(
          item: item,
          url: channel.url,
          streamName: channel.name,
          videoId: item.id,
          recordProgress: false,
        ),
      ),
    );
  }
}

class _LiveChannelTile extends StatelessWidget {
  const _LiveChannelTile(
      {required this.entry,
      required this.program,
      required this.playable,
      required this.onTap});
  final _LiveChannel entry;
  final IptvProgram? program;
  final bool playable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.read<AppState>();
    final channel = entry.channel;
    final current = program;
    final seconds =
        current == null ? 0 : current.stop.difference(current.start).inSeconds;
    final progress = seconds <= 0
        ? 0.0
        : DateTime.now().difference(current!.start).inSeconds / seconds;
    final channelInfo =
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 72,
        height: 72,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: channel.logo == null
              ? Icon(LucideIcons.radio,
                  size: 32, color: theme.colorScheme.onSurfaceVariant)
              : NovaNetworkImage(channel.logo!,
                  fit: BoxFit.contain,
                  cacheWidth: imageCacheWidth(context, 72),
                  errorBuilder: (_, __, ___) => Icon(LucideIcons.radio,
                      color: theme.colorScheme.onSurfaceVariant)),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(channel.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(entry.playlistName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ])),
      const SizedBox(width: 8),
      SizedBox.square(
          dimension: 48,
          child: Icon(playable ? LucideIcons.play : LucideIcons.circleAlert,
              color: playable
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error)),
    ]);
    final guide =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(current == null ? app.tr('message668') : app.tr('message669'),
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.primary)),
      const SizedBox(height: 8),
      Text(
          current?.title ??
              (playable ? app.tr('message670') : app.tr('message671')),
          style: theme.textTheme.bodyLarge),
      if (current != null) ...[
        const SizedBox(height: 16),
        LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 3),
      ],
    ]);
    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 24),
            child: LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth >= 860) {
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: channelInfo),
                      const SizedBox(width: 48),
                      Expanded(child: guide),
                    ]);
              }
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    channelInfo,
                    const SizedBox(height: 24),
                    guide,
                  ]);
            }),
          ),
        ));
  }
}

class _AddPlaylistDialog extends StatefulWidget {
  const _AddPlaylistDialog({required this.english});
  final bool english;

  @override
  State<_AddPlaylistDialog> createState() => _AddPlaylistDialogState();
}

class _AddPlaylistDialogState extends State<_AddPlaylistDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _epg = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _epg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: const Icon(LucideIcons.radio, size: 32),
        title: Text(NovaStrings.lookup(widget.english, 'message672')),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                      labelText:
                          NovaStrings.lookup(widget.english, 'message620')),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                      labelText:
                          NovaStrings.lookup(widget.english, 'message673')),
                  validator: (value) =>
                      _isHttp(Uri.tryParse(value?.trim() ?? ''))
                          ? null
                          : (NovaStrings.lookup(widget.english, 'message674')),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _epg,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                      labelText:
                          NovaStrings.lookup(widget.english, 'message675')),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty || _isHttp(Uri.tryParse(text))) {
                      return null;
                    }
                    return NovaStrings.lookup(widget.english, 'message674');
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(NovaStrings.lookup(widget.english, 'cancel'))),
          FilledButton(
            onPressed: () {
              if (_formKey.currentState?.validate() != true) return;
              final playlistUri = Uri.parse(_url.text.trim());
              final guideText = _epg.text.trim();
              Navigator.pop(context, {
                'name': _name.text.trim(),
                'url': playlistUri.toString(),
                if (guideText.isNotEmpty)
                  'epgUrl': Uri.parse(guideText).toString(),
              });
            },
            child: Text(NovaStrings.lookup(widget.english, 'message676')),
          ),
        ],
      );
}

class _LiveChannel {
  const _LiveChannel(
      {required this.playlistId,
      required this.playlistName,
      required this.channel});
  final String playlistId;
  final String playlistName;
  final IptvChannel channel;
}

bool _isHttp(Uri? uri) =>
    uri != null &&
    uri.hasAuthority &&
    (uri.scheme == 'http' || uri.scheme == 'https');
