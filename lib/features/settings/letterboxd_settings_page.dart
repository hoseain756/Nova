import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/letterboxd/letterboxd_settings.dart';
import '../../core/letterboxd/stremboxd_client.dart';
import '../../core/state/app_state.dart';
import 'widgets/settings_tiles.dart';

class LetterboxdSettingsPage extends StatefulWidget {
  const LetterboxdSettingsPage({super.key});

  @override
  State<LetterboxdSettingsPage> createState() => _LetterboxdSettingsPageState();
}

class _LetterboxdSettingsPageState extends State<LetterboxdSettingsPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _totp = TextEditingController();
  final _listUrl = TextEditingController();
  bool _initialized = false;
  bool _connecting = false;
  bool _addingList = false;
  bool _refreshing = false;
  bool _needsTotp = false;
  bool _showPassword = false;
  String? _feedbackKey;
  int? _connectedCatalogs;
  bool _feedbackError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _username.text = context.read<AppState>().letterboxdSettings.username;
    _initialized = true;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _totp.dispose();
    _listUrl.dispose();
    super.dispose();
  }

  void _feedback(String key, {bool error = false, int? catalogs}) {
    if (!mounted) return;
    setState(() {
      _feedbackKey = key;
      _feedbackError = error;
      _connectedCatalogs = catalogs;
    });
  }

  Future<void> _connectPublic(AppState app) async {
    final username = _username.text.trim();
    setState(() => _connecting = true);
    try {
      final count = await app.connectLetterboxdPublic(username);
      _password.clear();
      _totp.clear();
      _needsTotp = false;
      _feedback('letterboxdConnectedCount', catalogs: count);
    } catch (_) {
      _feedback('letterboxdConnectFailed', error: true);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _connectFull(AppState app) async {
    final username = _username.text.trim();
    if (username.isEmpty || _password.text.isEmpty) {
      _feedback('letterboxdCredentialsRequired', error: true);
      return;
    }
    setState(() => _connecting = true);
    try {
      await app.connectLetterboxdFull(
        username,
        _password.text,
        totp: _totp.text.isEmpty ? null : _totp.text,
      );
      _password.clear();
      _totp.clear();
      _needsTotp = false;
      _feedback('letterboxdFullConnected');
    } on StremboxdException catch (error) {
      if (error.requiresTotp) {
        setState(() => _needsTotp = true);
        _feedback('letterboxdTwoFactorRequired', error: true);
      } else {
        _feedback('letterboxdConnectFailed', error: true);
      }
    } catch (_) {
      _feedback('letterboxdConnectFailed', error: true);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _addList(AppState app) async {
    final url = _listUrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _addingList = true);
    try {
      await app.addLetterboxdList(url);
      _listUrl.clear();
      _feedback('letterboxdListAdded');
    } catch (_) {
      _feedback('letterboxdListFailed', error: true);
    } finally {
      if (mounted) setState(() => _addingList = false);
    }
  }

  Future<void> _refresh(AppState app) async {
    setState(() => _refreshing = true);
    try {
      await app.refreshLetterboxdCatalogs(force: true);
      _feedback('letterboxdRefreshComplete');
    } catch (_) {
      _feedback('letterboxdRefreshFailed', error: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _update(AppState app, LetterboxdSettings settings) {
    unawaited(app.updateLetterboxdSettings(settings));
  }

  void _toggleCatalog(
      AppState app, LetterboxdSettings settings, String id, bool selected) {
    final ids = [...settings.selectedCatalogs];
    if (selected && !ids.contains(id)) ids.add(id);
    if (!selected) ids.remove(id);
    _update(app, settings.copyWith(selectedCatalogs: ids));
  }

  void _toggleHidden(AppState app, LetterboxdSettings settings, String id) {
    final hidden = [...settings.hiddenCatalogs];
    if (hidden.contains(id)) {
      hidden.remove(id);
    } else {
      hidden.add(id);
    }
    _update(app, settings.copyWith(hiddenCatalogs: hidden));
  }

  List<String> _orderedCatalogs(LetterboxdSettings settings) {
    final allowed = {
      ...LetterboxdSettings.allCatalogs,
      for (final list in settings.listRefs) 'letterboxd-list-${list.id}',
    };
    final selected = settings.selectedCatalogs.where(allowed.contains).toSet();
    return [
      ...settings.catalogOrder.where(selected.contains),
      ...settings.selectedCatalogs.where(
          (id) => selected.contains(id) && !settings.catalogOrder.contains(id)),
    ];
  }

  void _move(AppState app, LetterboxdSettings settings, String id, int delta) {
    final order = _orderedCatalogs(settings);
    final index = order.indexOf(id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= order.length) return;
    final other = order[target];
    order[target] = id;
    order[index] = other;
    _update(app, settings.copyWith(catalogOrder: order));
  }

  String _catalogLabel(AppState app, LetterboxdSettings settings, String id) {
    final key = switch (id) {
      LetterboxdSettings.watchlistCatalog => 'letterboxdCatalogWatchlist',
      LetterboxdSettings.diaryCatalog => 'letterboxdCatalogDiary',
      LetterboxdSettings.likedCatalog => 'letterboxdCatalogLiked',
      LetterboxdSettings.friendsCatalog => 'letterboxdCatalogFriends',
      LetterboxdSettings.recommendedCatalog => 'letterboxdCatalogRecommended',
      LetterboxdSettings.popularCatalog => 'letterboxdCatalogPopular',
      LetterboxdSettings.top250Catalog => 'letterboxdCatalogTop250',
      _ => null,
    };
    if (key != null) return app.tr(key);
    for (final list in settings.listRefs) {
      if (id == 'letterboxd-list-${list.id}') return list.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final settings = app.letterboxdSettings;
    final session = app.letterboxdSession;
    final fullConnected =
        session != null && settings.mode == LetterboxdSettings.fullMode;
    final ordered = _orderedCatalogs(settings);
    return Scaffold(
      appBar: AppBar(title: const Text('Letterboxd')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 48),
            children: [
              SettingsPageIntro(
                title: 'Letterboxd',
                description: app.tr('letterboxdServiceDescription'),
                icon: LucideIcons.film,
              ),
              SettingsContentSection(
                title: app.tr('letterboxdIntegration'),
                children: [
                  SettingsOptimisticSwitchTile(
                    title: Text(app.tr('letterboxdEnable')),
                    subtitle: Text(app.tr('letterboxdEnableDescription')),
                    value: settings.enabled,
                    onChanged: (value) =>
                        _update(app, settings.copyWith(enabled: value)),
                  ),
                ],
              ),
              if (settings.enabled) ...[
                SettingsContentSection(
                  title: app.tr('letterboxdConnection'),
                  children: [
                    _modeSelector(app, settings),
                    _textField(
                      context,
                      title: app.tr('letterboxdUsername'),
                      description: app.tr(settings.isPublic
                          ? 'letterboxdUsernameDescriptionPublic'
                          : 'letterboxdUsernameDescription'),
                      controller: _username,
                      hint: app.tr('letterboxdUsernameHint'),
                      textDirection: TextDirection.ltr,
                    ),
                    if (!settings.isPublic)
                      _textField(
                        context,
                        title: app.tr('letterboxdPassword'),
                        description: app.tr('letterboxdPasswordDescription'),
                        controller: _password,
                        hint: app.tr('letterboxdPasswordHint'),
                        obscure: !_showPassword,
                        suffix: IconButton(
                          tooltip: app.tr(_showPassword
                              ? 'letterboxdHidePassword'
                              : 'letterboxdShowPassword'),
                          icon: Icon(_showPassword
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    if (!settings.isPublic && _needsTotp)
                      _textField(
                        context,
                        title: app.tr('letterboxdTwoFactor'),
                        description: app.tr('letterboxdTwoFactorDescription'),
                        controller: _totp,
                        hint: '123456',
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                      ),
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.symmetric(vertical: 20),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.icon(
                          onPressed: _connecting
                              ? null
                              : () => settings.isPublic
                                  ? _connectPublic(app)
                                  : _connectFull(app),
                          icon: Icon(_connecting
                              ? LucideIcons.loaderCircle
                              : LucideIcons.link),
                          label: Text(app.tr(_needsTotp && !settings.isPublic
                              ? 'letterboxdVerifyConnect'
                              : 'letterboxdConnect')),
                        ),
                      ),
                    ),
                    if (session != null)
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.symmetric(vertical: 20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(LucideIcons.circleCheck,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(app.tr('letterboxdSignedIn'),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                          const SizedBox(height: 8),
                                          Text(session.displayName == null
                                              ? '@${session.username}'
                                              : '${session.displayName} (@${session.username})'),
                                        ])),
                                  ]),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                  onPressed: () =>
                                      unawaited(app.disconnectLetterboxd()),
                                  icon: const Icon(LucideIcons.unlink),
                                  label: Text(app.tr('letterboxdDisconnect'))),
                            ]),
                      ),
                    SettingsTile(
                      icon: LucideIcons.externalLink,
                      title: app.tr('letterboxdAboutBridge'),
                      subtitle: app.tr('letterboxdAboutBridgeDescription'),
                      onTap: () => unawaited(launchUrl(
                        Uri.parse('https://stremboxd.com/configure'),
                        mode: LaunchMode.externalApplication,
                      )),
                    ),
                  ],
                ),
                if (_feedbackKey != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 16),
                    child: SettingsInfoBanner(
                      icon: _feedbackError
                          ? LucideIcons.circleAlert
                          : LucideIcons.circleCheck,
                      error: _feedbackError,
                      message: app.tr(_feedbackKey!, {
                        if (_connectedCatalogs != null)
                          'count': _connectedCatalogs,
                      }),
                    ),
                  ),
                SettingsContentSection(
                  title: app.tr('letterboxdCatalogs'),
                  description: app.tr('letterboxdCatalogsDescription'),
                  children: [
                    for (final id in LetterboxdSettings.allCatalogs)
                      SettingsOptimisticSwitchTile(
                        title: Text(_catalogLabel(app, settings, id)),
                        subtitle: Text(app.tr(_catalogDescriptionKey(id)) +
                            (LetterboxdSettings.fullOnlyCatalogs.contains(id) &&
                                    !fullConnected
                                ? ' ${app.tr('letterboxdFullRequired')}'
                                : '')),
                        value: settings.selectedCatalogs.contains(id),
                        onChanged:
                            LetterboxdSettings.fullOnlyCatalogs.contains(id) &&
                                    !fullConnected
                                ? null
                                : (value) =>
                                    _toggleCatalog(app, settings, id, value),
                      ),
                  ],
                ),
                SettingsContentSection(
                  title: app.tr('letterboxdCustomLists'),
                  children: [
                    _textField(
                      context,
                      title: app.tr('letterboxdAddList'),
                      description: app.tr('letterboxdAddListDescription'),
                      controller: _listUrl,
                      hint: 'letterboxd.com/username/list/slug',
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.url,
                      suffix: IconButton(
                        tooltip: app.tr('letterboxdAdd'),
                        onPressed: _addingList ? null : () => _addList(app),
                        icon: const Icon(LucideIcons.plus),
                      ),
                    ),
                    for (final list in settings.listRefs)
                      ListTile(
                        title: Text(list.name),
                        subtitle: Text(_listDescription(app, list)),
                        trailing: IconButton(
                          tooltip: app.tr('letterboxdRemove'),
                          onPressed: () =>
                              unawaited(app.removeLetterboxdList(list.id)),
                          icon: const Icon(LucideIcons.trash2),
                        ),
                      ),
                  ],
                ),
                SettingsContentSection(
                  title: app.tr('letterboxdOnScreen'),
                  children: [
                    SettingsOptimisticSwitchTile(
                      title: Text(app.tr('letterboxdShowMyRating')),
                      subtitle:
                          Text(app.tr('letterboxdShowMyRatingDescription')),
                      value: settings.showRatingsOnPosters,
                      onChanged: (value) => _update(
                          app, settings.copyWith(showRatingsOnPosters: value)),
                    ),
                    SettingsOptimisticSwitchTile(
                      title: Text(app.tr('letterboxdBlurReviews')),
                      subtitle:
                          Text(app.tr('letterboxdBlurReviewsDescription')),
                      value:
                          app.webSettings['letterboxdBlurReviews'] != false &&
                              app.webSettings['blurTraktComments'] != false,
                      onChanged: (value) {
                        unawaited(
                            app.setSetting('letterboxdBlurReviews', value));
                        unawaited(app.setSetting('blurTraktComments', value));
                      },
                    ),
                  ],
                ),
                SettingsContentSection(
                  title: app.tr('letterboxdHomeRows'),
                  description: app.tr('letterboxdHomeRowsDescription'),
                  children: [
                    if (ordered.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.symmetric(vertical: 20),
                        child: Text(app.tr('letterboxdNoRows')),
                      ),
                    for (var index = 0; index < ordered.length; index++)
                      _homeRow(app, settings, ordered, index),
                  ],
                ),
                if (settings.hiddenCatalogs.isNotEmpty)
                  SettingsContentSection(
                    title: app.tr('letterboxdHiddenCatalogs'),
                    description: app.tr('letterboxdHiddenCatalogsDescription'),
                    children: [
                      for (final id in settings.hiddenCatalogs)
                        ListTile(
                          title: Text(_catalogLabel(app, settings, id)),
                          trailing: TextButton(
                            onPressed: () => _toggleHidden(app, settings, id),
                            child: Text(app.tr('letterboxdShow')),
                          ),
                        ),
                    ],
                  ),
                SettingsContentSection(
                  title: app.tr('letterboxdRefresh'),
                  children: [
                    SettingsTile(
                      icon: LucideIcons.refreshCw,
                      title: app.tr('letterboxdRefreshNow'),
                      subtitle: app.tr('letterboxdRefreshDescription'),
                      onTap: _refreshing ? null : () => _refresh(app),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeSelector(AppState app, LetterboxdSettings settings) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(app.tr('letterboxdMode'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final mode in [
              (LetterboxdSettings.publicMode, app.tr('letterboxdPublic')),
              (LetterboxdSettings.fullMode, app.tr('letterboxdFull')),
            ])
              ChoiceChip(
                label: Text(mode.$2),
                selected: settings.mode == mode.$1,
                onSelected: (_) {
                  _feedbackKey = null;
                  _update(app, settings.copyWith(mode: mode.$1));
                },
              ),
          ]),
          const SizedBox(height: 12),
          Text(app.tr(settings.isPublic
              ? 'letterboxdPublicDescription'
              : 'letterboxdFullDescription')),
          if (!settings.isPublic) ...[
            const SizedBox(height: 8),
            Text(
              app.tr('letterboxdThirdPartyDisclosure'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ]),
      );

  Widget _textField(
    BuildContext context, {
    required String title,
    required String description,
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffix,
    TextDirection? textDirection,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) =>
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: !_connecting,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textDirection: textDirection,
            decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
          ),
        ]),
      );

  String _catalogDescriptionKey(String id) => switch (id) {
        LetterboxdSettings.watchlistCatalog =>
          'letterboxdCatalogWatchlistDescription',
        LetterboxdSettings.diaryCatalog => 'letterboxdCatalogDiaryDescription',
        LetterboxdSettings.likedCatalog => 'letterboxdCatalogLikedDescription',
        LetterboxdSettings.friendsCatalog =>
          'letterboxdCatalogFriendsDescription',
        LetterboxdSettings.recommendedCatalog =>
          'letterboxdCatalogRecommendedDescription',
        LetterboxdSettings.popularCatalog =>
          'letterboxdCatalogPopularDescription',
        _ => 'letterboxdCatalogTop250Description',
      };

  String _listDescription(AppState app, LetterboxdListRef list) {
    if (list.owner != null && list.filmCount != null) {
      return app.tr('letterboxdListByWithCount', {
        'owner': list.owner,
        'count': list.filmCount,
      });
    }
    if (list.owner != null) {
      return app.tr('letterboxdListBy', {'owner': list.owner});
    }
    if (list.filmCount != null) {
      return app.tr('letterboxdListCount', {'count': list.filmCount});
    }
    return app.tr('letterboxdPublicList');
  }

  Widget _homeRow(AppState app, LetterboxdSettings settings,
      List<String> ordered, int index) {
    final id = ordered[index];
    final hidden = settings.hiddenCatalogs.contains(id);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_catalogLabel(app, settings, id),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 4,
          children: [
            IconButton(
              tooltip: app.tr(hidden ? 'letterboxdShow' : 'letterboxdHide'),
              onPressed: () => _toggleHidden(app, settings, id),
              icon: Icon(hidden ? LucideIcons.eye : LucideIcons.eyeOff),
            ),
            IconButton(
              tooltip: app.tr('letterboxdMoveUp'),
              onPressed: index == 0 ? null : () => _move(app, settings, id, -1),
              icon: const Icon(LucideIcons.arrowUp),
            ),
            IconButton(
              tooltip: app.tr('letterboxdMoveDown'),
              onPressed: index == ordered.length - 1
                  ? null
                  : () => _move(app, settings, id, 1),
              icon: const Icon(LucideIcons.arrowDown),
            ),
          ],
        ),
      ]),
    );
  }
}
