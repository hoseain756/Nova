import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth/account_controller.dart';
import '../core/state/app_state.dart';
import '../core/theme/nova_theme.dart';
import '../features/account/account_pages.dart';
import '../features/shell/main_shell.dart';
import '../l10n/nova_strings.dart';

/// The only entrance to viewer state after onboarding.
class AccountGate extends StatefulWidget {
  const AccountGate({super.key, required this.account});

  final AccountController account;

  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  String? _defaultCheckedFor;
  bool _chooseAnotherProfile = false;
  bool _clearingForeignScope = false;

  List<ProfileSummary> get _summaries => [
        for (final profile in widget.account.profiles)
          ProfileSummary(
            id: profile.id,
            name: profile.name,
            avatarPackKey:
                profile.avatarKind == 'pack' ? profile.avatarValue : null,
            avatarUrl: profile.avatarKind == 'url' ? profile.avatarValue : null,
            hasPin: profile.hasPin,
            isDefault: profile.id == widget.account.defaultProfileId,
          ),
      ];

  Future<void> _check(Future<void> Function() action) async {
    await action();
    if (widget.account.error != null) {
      throw StateError('Account operation failed');
    }
  }

  Future<void> _openLogin() => _push(AccountSignInPage(
        onSubmit: (identifier, password) async {
          await _check(() => widget.account.signIn(identifier, password));
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        },
        onForgotPassword: () => _push(AccountResetPage(
          onSubmit: (email) =>
              _check(() => widget.account.sendPasswordReset(email)),
        )),
      ));

  Future<void> _openSignup() => _push(AccountSignUpPage(
        onSubmit: (username, email, password) async {
          await _check(() => widget.account.signUp(username, email, password));
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
          if (widget.account.awaitingEmailConfirmation) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(NovaStrings.of(context).text('accountCheckEmail')),
            ));
          }
        },
      ));

  Future<void> _push(Widget page) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      );

  Future<void> _select(String id, String? pin) async {
    final app = context.read<AppState>();
    final selected = await widget.account.selectProfile(id, pin: pin);
    if (!selected) throw StateError('Profile unlock failed');
    final user = widget.account.user;
    if (user == null) throw StateError('Session missing');
    try {
      await app.activateProfile(
        accountId: user.id,
        profileId: id,
      );
    } catch (_) {
      widget.account.leaveProfile();
      rethrow;
    }
  }

  Future<void> _create(ProfileDraft draft) async {
    final created = await widget.account.createProfile(
      name: draft.name,
      avatarPackKey: draft.avatarPackKey,
      avatarUrl: draft.avatarUrl,
      pin: draft.pin,
      setAsDefault: draft.setAsDefault,
    );
    if (created == null) throw StateError('Profile creation failed');
    await _select(created.id, draft.pin);
  }

  void _tryDefault() {
    final account = widget.account;
    final user = account.user;
    final defaultId = account.defaultProfileId;
    if (user == null ||
        defaultId == null ||
        account.activeProfileId != null ||
        _defaultCheckedFor == user.id) {
      return;
    }
    _defaultCheckedFor = user.id;
    final profile =
        account.profiles.where((p) => p.id == defaultId).firstOrNull;
    if (profile == null || profile.hasPin) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && account.activeProfileId == null) {
        _select(defaultId, null).catchError((Object _) {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return AnimatedBuilder(
      animation: Listenable.merge([widget.account, app]),
      builder: (context, _) {
        final account = widget.account;
        if (app.sync.accountId != null &&
            app.sync.accountId != account.user?.id) {
          if (!_clearingForeignScope) {
            _clearingForeignScope = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await app.clearActiveProfile();
              _clearingForeignScope = false;
            });
          }
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (account.passwordRecoveryPending) {
          return AccountNewPasswordPage(
              onSubmit: (password) =>
                  _check(() => account.setRecoveredPassword(password)));
        }
        if (!account.signedIn) {
          if (account.awaitingEmailConfirmation) {
            return AccountEmailVerificationPage(
              onCheckVerification: account.checkEmailVerification,
              onCancel: account.cancelEmailWait,
            );
          }
          return AccountWelcomePage(
            onLogIn: _openLogin,
            onCreateAccount: _openSignup,
            onContinueAsGuest: () => _check(account.continueAsGuest),
            onResumeGuest: account.hasSavedGuest
                ? () => _check(account.switchToSavedGuest)
                : null,
          );
        }
        if (!account.profilesReady) {
          return Scaffold(
              body: SafeArea(
                  child: Center(
                      child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(NovaStrings.of(context).text('accountGenericError')),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: account.refresh,
                  child: Text(NovaStrings.of(context).text('retry'))),
            ],
          ))));
        }
        if (!account.isGuest && account.guestUpgradePending) {
          return GuestUpgradePage(
            initialSent: true,
            showBack: false,
            emailVerified: account.guestEmailVerified ||
                account.user?.emailConfirmedAt != null,
            onStart: (name, email) =>
                _check(() => account.beginGuestUpgrade(name, email)),
            onFinish: (password) =>
                _check(() => account.finishGuestUpgrade(password)),
            onCheckVerification: account.checkEmailVerification,
          );
        }
        if (!account.isGuest && account.username == null) {
          return AccountUsernameCompletionPage(
              onSubmit: (name) => _check(() => account.setUsername(name)));
        }
        if (account.profiles.isEmpty) {
          return ProfileEditorPage(
            firstProfile: true,
            onSave: _create,
          );
        }
        _tryDefault();
        if (account.activeProfileId == null) {
          final defaultProfile = account.profiles
              .where((p) => p.id == account.defaultProfileId && p.hasPin)
              .firstOrNull;
          if (defaultProfile != null && !_chooseAnotherProfile) {
            return _DefaultProfileUnlock(
              profile: _summaries.firstWhere((p) => p.id == defaultProfile.id),
              onUnlock: (pin) => _select(defaultProfile.id, pin),
              onChooseAnother: () =>
                  setState(() => _chooseAnotherProfile = true),
            );
          }
          return ProfilePickerPage(
            profiles: _summaries,
            onSelect: _select,
            onManage: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AnimatedBuilder(
                    animation: account,
                    builder: (context, _) => ProfileManagementPage(
                          profiles: _summaries,
                          onCreate: (draft) async {
                            final created = await account.createProfile(
                              name: draft.name,
                              avatarPackKey: draft.avatarPackKey,
                              avatarUrl: draft.avatarUrl,
                              pin: draft.pin,
                              setAsDefault: draft.setAsDefault,
                            );
                            if (created == null) {
                              throw StateError('Profile creation failed');
                            }
                          },
                          onUpdate: (id, draft) async {
                            if (draft.pin != null || draft.removePin) {
                              await _check(() => account.setProfilePin(
                                  id,
                                  draft.oldPin,
                                  draft.removePin ? null : draft.pin));
                            }
                            await _check(() => account.updateProfile(id,
                                name: draft.name,
                                avatarPackKey: draft.avatarPackKey,
                                avatarUrl: draft.avatarUrl));
                            if (draft.setAsDefault) {
                              await _check(() => account.setDefaultProfile(id));
                            }
                          },
                          onDelete: (id) =>
                              _check(() => account.deleteProfile(id)),
                          onSetDefault: (id) =>
                              _check(() => account.setDefaultProfile(id)),
                          onVerifyPin: account.verifyProfilePin,
                        )))),
          );
        }
        return const MainShell();
      },
    );
  }
}

class _DefaultProfileUnlock extends StatefulWidget {
  const _DefaultProfileUnlock({
    required this.profile,
    required this.onUnlock,
    required this.onChooseAnother,
  });
  final ProfileSummary profile;
  final Future<void> Function(String pin) onUnlock;
  final VoidCallback onChooseAnother;

  @override
  State<_DefaultProfileUnlock> createState() => _DefaultProfileUnlockState();
}

class _DefaultProfileUnlockState extends State<_DefaultProfileUnlock> {
  final _pin = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_pin.text.length != 6) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onUnlock(_pin.text);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _pin.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NovaSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: ProfileAvatar(
                    packKey: widget.profile.avatarPackKey,
                    url: widget.profile.avatarUrl,
                    size: 96,
                  )),
                  const SizedBox(height: NovaSpace.lg),
                  Text(widget.profile.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: NovaSpace.lg),
                  TextField(
                    controller: _pin,
                    obscureText: true,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: s.text('profilePin')),
                    onSubmitted: (_) => _unlock(),
                  ),
                  if (_failed)
                    Text(s.text('profileUnlockFailed'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  FilledButton(
                      onPressed: _busy ? null : _unlock,
                      child: Text(s.text('profileUnlock'))),
                  TextButton(
                      onPressed: _busy ? null : widget.onChooseAnother,
                      child: Text(s.text('profileChooseAnother'))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
