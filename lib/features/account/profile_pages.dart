import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/nova_theme.dart';
import '../../l10n/nova_strings.dart';
import '../../shared/widgets/nova_network_image.dart';
import '../settings/widgets/settings_tiles.dart';

const novaAvatarPackKeys = <String>[
  'nova_avatar_01_smile',
  'nova_avatar_02_surprised',
  'nova_avatar_03_sleepy',
  'nova_avatar_04_laughing',
  'nova_avatar_05_cool',
  'nova_avatar_06_love',
  'nova_avatar_07_tongue',
  'nova_avatar_08_excited',
  'nova_avatar_09_wink',
];

/// The repository chooses a random pack key when both avatar fields are null.
class ProfileDraft {
  const ProfileDraft({
    required this.name,
    this.avatarPackKey,
    this.avatarUrl,
    this.pin,
    this.oldPin,
    this.removePin = false,
    this.setAsDefault = false,
  });

  final String name;
  final String? avatarPackKey;
  final String? avatarUrl;
  final String? pin;
  final String? oldPin;
  final bool removePin;
  final bool setAsDefault;
}

class ProfileSummary {
  const ProfileSummary({
    required this.id,
    required this.name,
    this.avatarPackKey,
    this.avatarUrl,
    this.hasPin = false,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String? avatarPackKey;
  final String? avatarUrl;
  final bool hasPin;
  final bool isDefault;
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.packKey,
    this.url,
    this.size = 72,
    this.onImageStateChanged,
  });

  final String? packKey;
  final String? url;
  final double size;
  final ValueChanged<bool>? onImageStateChanged;

  void _reportImageState(bool loaded) {
    final callback = onImageStateChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback(loaded));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final validUrl = Uri.tryParse(url ?? '');
    final image = validUrl?.scheme == 'https' &&
            validUrl?.host.isNotEmpty == true
        ? NovaNetworkImage(
            url!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
            cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
            frameBuilder: onImageStateChanged == null
                ? null
                : (context, child, frame, synchronous) {
                    if (frame != null) _reportImageState(true);
                    return frame == null
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : child;
                  },
            errorBuilder: (context, error, stackTrace) {
              _reportImageState(false);
              return _fallback(context);
            },
          )
        : packKey != null && novaAvatarPackKeys.contains(packKey)
            ? Image.asset(
                'assets/avatars/$packKey.png',
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _fallback(context),
              )
            : _fallback(context);
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: scheme.primaryContainer,
          child: image,
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) => Icon(
        LucideIcons.userRound,
        size: size * .48,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      );
}

class ProfileEditorPage extends StatefulWidget {
  const ProfileEditorPage({
    super.key,
    required this.onSave,
    this.initial,
    this.firstProfile = false,
    this.onBeforeSave,
  });

  final ProfileSummary? initial;
  final bool firstProfile;
  final Future<void> Function(ProfileDraft draft) onSave;
  final Future<bool> Function(ProfileDraft draft)? onBeforeSave;

  @override
  State<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends State<ProfileEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _url;
  Timer? _urlPreviewTimer;
  Timer? _urlLoadTimer;
  final _pin = TextEditingController();
  final _oldPin = TextEditingController();
  String? _packKey;
  late String _randomPackKey;
  String _previewUrl = '';
  int _previewAttempt = 0;
  bool? _urlImageLoaded;
  bool _useUrl = false;
  bool _setDefault = false;
  bool _removePin = false;
  bool _busy = false;
  bool _failed = false;
  bool _unlockFailed = false;

  bool get _canSaveAvatar =>
      !_useUrl ||
      _urlImageLoaded == true ||
      (_url.text.trim() == widget.initial?.avatarUrl &&
          widget.initial?.avatarUrl?.isNotEmpty == true);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _url = TextEditingController(text: widget.initial?.avatarUrl ?? '');
    _url.addListener(_scheduleUrlPreview);
    _packKey = widget.initial?.avatarPackKey;
    _randomPackKey =
        novaAvatarPackKeys[Random.secure().nextInt(novaAvatarPackKeys.length)];
    _useUrl = widget.initial?.avatarUrl != null;
    if (_useUrl) {
      _previewUrl = _url.text.trim();
      _startUrlLoadTimeout(_previewUrl);
    }
    _setDefault = widget.initial?.isDefault ?? false;
  }

  @override
  void dispose() {
    _urlPreviewTimer?.cancel();
    _urlLoadTimer?.cancel();
    _name.dispose();
    _url.dispose();
    _pin.dispose();
    _oldPin.dispose();
    super.dispose();
  }

  void _scheduleUrlPreview() {
    _urlPreviewTimer?.cancel();
    _urlLoadTimer?.cancel();
    setState(() {
      _previewUrl = '';
      _urlImageLoaded = null;
    });
    _urlPreviewTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _previewUrl = _url.text.trim();
        _previewAttempt++;
      });
      _startUrlLoadTimeout(_previewUrl);
    });
  }

  void _startUrlLoadTimeout(String url) {
    _urlLoadTimer?.cancel();
    final uri = Uri.tryParse(url);
    if (uri?.scheme != 'https' || uri?.host.isNotEmpty != true) return;
    _urlLoadTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _useUrl && _previewUrl == url && _urlImageLoaded == null) {
        setState(() => _urlImageLoaded = false);
      }
    });
  }

  void _retryUrlPreview() {
    setState(() {
      _urlImageLoaded = null;
      _previewAttempt++;
    });
    _startUrlLoadTimeout(_previewUrl);
  }

  void _onUrlImageStateChanged(String url, int attempt, bool loaded) {
    if (!mounted ||
        !_useUrl ||
        _previewUrl != url ||
        _previewAttempt != attempt ||
        _urlImageLoaded == loaded) {
      return;
    }
    _urlLoadTimer?.cancel();
    setState(() => _urlImageLoaded = loaded);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failed = false;
      _unlockFailed = false;
    });
    try {
      final draft = ProfileDraft(
        name: _name.text.trim(),
        avatarPackKey: _useUrl ? null : (_packKey ?? _randomPackKey),
        avatarUrl: _useUrl ? _url.text.trim() : null,
        pin: _pin.text.isEmpty ? null : _pin.text,
        oldPin: _oldPin.text.isEmpty ? null : _oldPin.text,
        removePin: _removePin,
        setAsDefault: _setDefault,
      );
      if (widget.onBeforeSave != null && !await widget.onBeforeSave!(draft)) {
        if (mounted) setState(() => _unlockFailed = true);
        return;
      }
      await widget.onSave(draft);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final previewUrl = _previewUrl;
    final previewAttempt = _previewAttempt;
    return Scaffold(
      appBar: widget.firstProfile
          ? null
          : AppBar(
              title: Text(s.text(
                  widget.initial == null ? 'profileAdd' : 'profileEdit'))),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(
                NovaSpace.gutter(constraints.maxWidth),
                NovaSpace.lg,
                NovaSpace.gutter(constraints.maxWidth),
                NovaSpace.xl + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingsPageIntro(
                        title: s.text(widget.firstProfile
                            ? 'profileFirstTitle'
                            : widget.initial == null
                                ? 'profileAdd'
                                : 'profileEdit'),
                        description: s.text('profileEditorDescription'),
                        icon: LucideIcons.usersRound,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            label: s.text('profileAvatarPreview'),
                            image: true,
                            child: ExcludeSemantics(
                              child: ProfileAvatar(
                                key: ValueKey(_useUrl
                                    ? (previewUrl, previewAttempt)
                                    : (_packKey ?? _randomPackKey)),
                                packKey: _useUrl
                                    ? null
                                    : (_packKey ?? _randomPackKey),
                                url: _useUrl && _urlImageLoaded != false
                                    ? previewUrl
                                    : null,
                                size: 56,
                                onImageStateChanged:
                                    _useUrl && previewUrl.isNotEmpty
                                        ? (loaded) => _onUrlImageStateChanged(
                                            previewUrl, previewAttempt, loaded)
                                        : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: NovaSpace.md),
                          Expanded(
                            child: TextFormField(
                              controller: _name,
                              enabled: !_busy,
                              textInputAction: TextInputAction.next,
                              maxLength: 32,
                              decoration: InputDecoration(
                                labelText: s.text('profileName'),
                              ),
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                      ? s.text('accountRequired')
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NovaSpace.md),
                      Text(s.text('profileAvatar'),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: NovaSpace.sm),
                      Text(s.text('profileAvatarHint'),
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: NovaSpace.md),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ChoiceChip(
                          label: Text(s.text('profileRandomAvatar')),
                          selected: !_useUrl && _packKey == null,
                          onSelected: _busy
                              ? null
                              : (_) => setState(() {
                                    _urlLoadTimer?.cancel();
                                    _useUrl = false;
                                    _packKey = null;
                                    _randomPackKey = novaAvatarPackKeys[
                                        Random.secure().nextInt(
                                            novaAvatarPackKeys.length)];
                                  }),
                        ),
                        ChoiceChip(
                          label: Text(s.text('profileImageUrl')),
                          selected: _useUrl,
                          onSelected: _busy
                              ? null
                              : (_) => setState(() {
                                    _useUrl = true;
                                    _previewUrl = _url.text.trim();
                                    _urlImageLoaded = null;
                                    _previewAttempt++;
                                    _startUrlLoadTimeout(_previewUrl);
                                  }),
                        ),
                      ]),
                      const SizedBox(height: NovaSpace.md),
                      if (_useUrl)
                        TextFormField(
                          controller: _url,
                          enabled: !_busy,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          textDirection: TextDirection.ltr,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: s.text('profileImageUrl'),
                            helperText: s.text('profileImageUrlHint'),
                            helperMaxLines: 8,
                            prefixIcon: const Icon(LucideIcons.link),
                          ),
                          validator: (value) {
                            final uri = Uri.tryParse(value?.trim() ?? '');
                            return uri?.scheme == 'https' &&
                                    uri?.host.isNotEmpty == true
                                ? null
                                : s.text('profileUrlRule');
                          },
                        ),
                      if (_useUrl && _urlImageLoaded == false) ...[
                        const SizedBox(height: NovaSpace.sm),
                        Text(s.text('profileImageLoadFailed'),
                            style: TextStyle(color: scheme.error)),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: _busy ? null : _retryUrlPreview,
                            icon: const Icon(LucideIcons.rotateCcw),
                            label: Text(s.text('profileImageRetry')),
                          ),
                        ),
                      ],
                      if (!_useUrl)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 120,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                          itemCount: novaAvatarPackKeys.length,
                          itemBuilder: (context, index) {
                            final key = novaAvatarPackKeys[index];
                            final selected = key == _packKey;
                            return Semantics(
                              button: true,
                              selected: selected,
                              label: '${s.text('profileAvatar')} ${index + 1}',
                              child: InkWell(
                                onTap: _busy
                                    ? null
                                    : () => setState(() {
                                          _urlLoadTimer?.cancel();
                                          _packKey = key;
                                          _useUrl = false;
                                        }),
                                borderRadius: BorderRadius.circular(16),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      width: selected ? 2 : 1,
                                      color: selected
                                          ? scheme.primary
                                          : scheme.outlineVariant,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: FittedBox(
                                      child:
                                          ProfileAvatar(packKey: key, size: 64),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: NovaSpace.lg),
                      TextFormField(
                        controller: _pin,
                        enabled: !_busy && !_removePin,
                        onChanged: (_) => setState(() {}),
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: s.text(widget.initial?.hasPin == true
                              ? 'profileChangePin'
                              : 'profileOptionalPin'),
                          helperText: s.text('profilePinHint'),
                          helperMaxLines: 8,
                          prefixIcon: const Icon(LucideIcons.lockKeyhole),
                        ),
                        validator: (value) {
                          final pin = value ?? '';
                          return pin.isEmpty || RegExp(r'^\d{6}$').hasMatch(pin)
                              ? null
                              : s.text('profilePinRule');
                        },
                      ),
                      if (widget.initial?.hasPin == true &&
                          (_removePin || _pin.text.isNotEmpty))
                        TextFormField(
                          controller: _oldPin,
                          enabled: !_busy,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: s.text('profileCurrentPin'),
                            prefixIcon: const Icon(LucideIcons.lockKeyhole),
                          ),
                          validator: (value) =>
                              RegExp(r'^\d{6}$').hasMatch(value ?? '')
                                  ? null
                                  : s.text('profilePinRule'),
                        ),
                      if (widget.initial?.hasPin == true)
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.text('profileRemovePin')),
                          value: _removePin,
                          onChanged: _busy
                              ? null
                              : (value) => setState(() {
                                    _removePin = value;
                                    if (value) _pin.clear();
                                  }),
                        ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.text('profileSetDefault')),
                        subtitle: Text(s.text('profileSetDefaultHint')),
                        value: _setDefault,
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _setDefault = value),
                      ),
                      const SizedBox(height: NovaSpace.lg),
                      if (_failed) ...[
                        Text(s.text('profileSaveFailed'),
                            style: TextStyle(color: scheme.error)),
                        const SizedBox(height: NovaSpace.md),
                      ],
                      if (_unlockFailed) ...[
                        Text(s.text('profileUnlockFailed'),
                            style: TextStyle(color: scheme.error)),
                        const SizedBox(height: NovaSpace.md),
                      ],
                      FilledButton(
                        onPressed: _busy || !_canSaveAvatar ? null : _save,
                        child: Text(s.text('profileSave')),
                      ),
                      if (_busy) ...[
                        const SizedBox(height: NovaSpace.md),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ProfilePickerPage extends StatefulWidget {
  const ProfilePickerPage({
    super.key,
    required this.profiles,
    required this.onSelect,
    this.onManage,
  });

  final List<ProfileSummary> profiles;
  final Future<void> Function(String profileId, String? pin) onSelect;
  final VoidCallback? onManage;

  @override
  State<ProfilePickerPage> createState() => _ProfilePickerPageState();
}

class _ProfilePickerPageState extends State<ProfilePickerPage> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _select(ProfileSummary profile) async {
    String? pin;
    if (profile.hasPin) {
      pin = await _askForPin(context, profile.name);
      if (pin == null) return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onSelect(profile.id, pin);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(NovaSpace.gutter(constraints.maxWidth)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsPageIntro(
                      title: s.text('profileWhoIsWatching'),
                      description: s.text('profileChooseHint'),
                    ),
                    if (_failed) ...[
                      Text(s.text('profileUnlockFailed'),
                          style: TextStyle(color: scheme.error)),
                      const SizedBox(height: NovaSpace.md),
                    ],
                    LayoutBuilder(builder: (context, constraints) {
                      final columns =
                          (constraints.maxWidth / 180).floor().clamp(1, 3);
                      final width =
                          (constraints.maxWidth - (columns - 1) * 20) / columns;
                      return Wrap(spacing: 20, runSpacing: 24, children: [
                        for (final profile in widget.profiles)
                          SizedBox(
                            width: width,
                            child: Semantics(
                              button: true,
                              enabled: !_busy,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: _busy ? null : () => _select(profile),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(children: [
                                      ProfileAvatar(
                                        packKey: profile.avatarPackKey,
                                        url: profile.avatarUrl,
                                        size: 88,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(profile.name,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      if (profile.isDefault) ...[
                                        const SizedBox(height: 8),
                                        Text(s.text('profileDefault'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                    color: scheme.primary)),
                                      ],
                                      if (profile.hasPin) ...[
                                        const SizedBox(height: 8),
                                        Icon(LucideIcons.lockKeyhole,
                                            size: 18,
                                            semanticLabel:
                                                s.text('profileEnterPin'),
                                            color: scheme.onSurfaceVariant),
                                      ],
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ]);
                    }),
                    if (widget.onManage != null) ...[
                      const SizedBox(height: NovaSpace.md),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : widget.onManage,
                        icon: const Icon(LucideIcons.settings2),
                        label: Text(s.text('profileManage')),
                      ),
                    ],
                    if (_busy) ...[
                      const SizedBox(height: NovaSpace.md),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ProfileManagementPage extends StatefulWidget {
  const ProfileManagementPage({
    super.key,
    required this.profiles,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
    required this.onSetDefault,
    required this.onVerifyPin,
  });

  final List<ProfileSummary> profiles;
  final Future<void> Function(ProfileDraft draft) onCreate;
  final Future<void> Function(String profileId, ProfileDraft draft) onUpdate;
  final Future<void> Function(String profileId) onDelete;
  final Future<void> Function(String? profileId) onSetDefault;
  final Future<bool> Function(String profileId, String pin) onVerifyPin;

  @override
  State<ProfileManagementPage> createState() => _ProfileManagementPageState();
}

class _ProfileManagementPageState extends State<ProfileManagementPage> {
  bool _busy = false;
  bool _failed = false;
  bool _unlockFailed = false;

  Future<bool> _authorize(ProfileSummary profile) async {
    if (!profile.hasPin) return true;
    final pin = await _askForPin(context, profile.name);
    if (pin == null || !mounted) return false;
    setState(() {
      _busy = true;
      _unlockFailed = false;
    });
    try {
      final verified = await widget.onVerifyPin(profile.id, pin);
      if (!verified && mounted) setState(() => _unlockFailed = true);
      return verified;
    } catch (_) {
      if (mounted) setState(() => _unlockFailed = true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor([ProfileSummary? profile]) async {
    if (profile != null && !await _authorize(profile)) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => ProfileEditorPage(
        initial: profile,
        onBeforeSave: (draft) async {
          if (!draft.setAsDefault) return true;
          for (final current in widget.profiles) {
            if (current.id != profile?.id &&
                current.isDefault &&
                !await _authorize(current)) {
              return false;
            }
          }
          return true;
        },
        onSave: (draft) async {
          if (profile == null) {
            await widget.onCreate(draft);
          } else {
            await widget.onUpdate(profile.id, draft);
          }
          if (context.mounted) Navigator.pop(context);
        },
      ),
    ));
  }

  Future<void> _confirmDelete(ProfileSummary profile) async {
    final s = NovaStrings.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.text('profileDelete')),
        content: Text(s.text('profileDeleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.text('profileDelete')),
          ),
        ],
      ),
    );
    if (accepted == true && await _authorize(profile) && mounted) {
      await _run(() => widget.onDelete(profile.id));
    }
  }

  Future<void> _changeDefault(ProfileSummary profile, bool value) async {
    if (value) {
      for (final current in widget.profiles) {
        if (current.id != profile.id &&
            current.isDefault &&
            !await _authorize(current)) {
          return;
        }
      }
    }
    if (!await _authorize(profile) || !mounted) return;
    await _run(() => widget.onSetDefault(value ? profile.id : null));
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.text('profileManage'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 48),
            children: [
              SettingsPageIntro(
                title: s.text('profileManage'),
                description: s.text('profileManageHint'),
                icon: LucideIcons.usersRound,
              ),
              if (_failed) ...[
                Text(s.text('profileSaveFailed'),
                    style: TextStyle(color: scheme.error)),
                const SizedBox(height: NovaSpace.md),
              ],
              if (_unlockFailed) ...[
                Text(s.text('profileUnlockFailed'),
                    style: TextStyle(color: scheme.error)),
                const SizedBox(height: NovaSpace.md),
              ],
              for (final profile in widget.profiles) ...[
                Row(children: [
                  ProfileAvatar(
                    packKey: profile.avatarPackKey,
                    url: profile.avatarUrl,
                    size: 72,
                  ),
                  const SizedBox(width: NovaSpace.md),
                  Expanded(
                    child: Text(profile.name,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: s.text('profileEdit'),
                    onPressed: _busy ? null : () => _openEditor(profile),
                    icon: const Icon(LucideIcons.pencil),
                  ),
                  IconButton(
                    tooltip: s.text('profileDelete'),
                    onPressed: _busy || widget.profiles.length <= 1
                        ? null
                        : () => _confirmDelete(profile),
                    icon: const Icon(LucideIcons.trash2),
                  ),
                ]),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.text('profileSetDefault')),
                  value: profile.isDefault,
                  onChanged:
                      _busy ? null : (value) => _changeDefault(profile, value),
                ),
                const Divider(height: NovaSpace.xl),
              ],
              const SizedBox(height: NovaSpace.md),
              OutlinedButton.icon(
                onPressed: _busy || widget.profiles.length >= 5
                    ? null
                    : () => _openEditor(),
                icon: const Icon(LucideIcons.plus),
                label: Text(s.text('profileAdd')),
              ),
              if (widget.profiles.length >= 5)
                Padding(
                  padding: const EdgeInsets.only(top: NovaSpace.sm),
                  child: Text(s.text('profileMaximum'),
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              if (_busy) ...[
                const SizedBox(height: NovaSpace.md),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _askForPin(BuildContext context, String profileName) async {
  return showDialog<String>(
    context: context,
    builder: (context) => _ProfilePinDialog(profileName: profileName),
  );
}

class _ProfilePinDialog extends StatefulWidget {
  const _ProfilePinDialog({required this.profileName});

  final String profileName;

  @override
  State<_ProfilePinDialog> createState() => _ProfilePinDialogState();
}

class _ProfilePinDialogState extends State<_ProfilePinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (RegExp(r'^\d{6}$').hasMatch(_controller.text)) {
      Navigator.pop(context, _controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return AlertDialog(
      title: Text(widget.profileName),
      scrollable: true,
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: InputDecoration(labelText: s.text('profileEnterPin')),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.text('cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(s.text('profileUnlock')),
        ),
      ],
    );
  }
}
