import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/auth/account_controller.dart';
import '../core/state/app_state.dart';
import '../features/account/account_pages.dart';
import '../features/settings/widgets/settings_tiles.dart';
import '../l10n/nova_strings.dart';

class AccountSettingsSection extends StatelessWidget {
  const AccountSettingsSection(
      {super.key, required this.account, required this.app});

  final AccountController account;
  final AppState app;

  List<ProfileSummary> get _profiles => [
        for (final profile in account.profiles)
          ProfileSummary(
            id: profile.id,
            name: profile.name,
            avatarPackKey:
                profile.avatarKind == 'pack' ? profile.avatarValue : null,
            avatarUrl: profile.avatarKind == 'url' ? profile.avatarValue : null,
            hasPin: profile.hasPin,
            isDefault: profile.id == account.defaultProfileId,
          ),
      ];

  Future<void> _checked(Future<void> Function() action) async {
    await action();
    if (account.error != null) throw StateError('Account action failed');
  }

  Future<void> _manage(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => AnimatedBuilder(
            animation: account,
            builder: (context, _) => ProfileManagementPage(
              profiles: _profiles,
              onCreate: (draft) async {
                final created = await account.createProfile(
                  name: draft.name,
                  avatarPackKey: draft.avatarPackKey,
                  avatarUrl: draft.avatarUrl,
                  pin: draft.pin,
                  setAsDefault: draft.setAsDefault,
                );
                if (created == null) throw StateError('Profile save failed');
              },
              onUpdate: (id, draft) async {
                if (draft.pin != null || draft.removePin) {
                  await _checked(() => account.setProfilePin(
                      id, draft.oldPin, draft.removePin ? null : draft.pin));
                }
                await _checked(() => account.updateProfile(
                      id,
                      name: draft.name,
                      avatarPackKey: draft.avatarPackKey,
                      avatarUrl: draft.avatarUrl,
                    ));
                if (draft.setAsDefault) {
                  await _checked(() => account.setDefaultProfile(id));
                }
              },
              onDelete: (id) => _checked(() => account.deleteProfile(id)),
              onSetDefault: (id) =>
                  _checked(() => account.setDefaultProfile(id)),
              onVerifyPin: account.verifyProfilePin,
            ),
          ),
        ),
      );

  Future<void> _leave(BuildContext context) async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    await app.clearActiveProfile();
    account.leaveProfile();
  }

  Future<void> _changeIdentity(
      BuildContext context, Future<void> Function() action) async {
    final previousUserId = account.user?.id;
    final previousProfileId = account.activeProfileId;
    await app.clearActiveProfile();
    try {
      await _checked(action);
    } catch (_) {
      if (previousUserId != null &&
          previousProfileId != null &&
          account.user?.id == previousUserId) {
        await app.activateProfile(
            accountId: previousUserId, profileId: previousProfileId);
      }
      rethrow;
    }
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _login(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (pageContext) => AccountSignInPage(
            onSubmit: (identifier, password) async {
              await _changeIdentity(
                  pageContext, () => account.signIn(identifier, password));
            },
            onForgotPassword: () => Navigator.of(pageContext).push(
              MaterialPageRoute<void>(
                builder: (_) => AccountResetPage(
                  onSubmit: (email) =>
                      _checked(() => account.sendPasswordReset(email)),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _upgrade(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (pageContext) => AnimatedBuilder(
            animation: account,
            builder: (context, _) => GuestUpgradePage(
              initialSent: account.guestUpgradePending,
              emailVerified: account.guestEmailVerified ||
                  account.user?.emailConfirmedAt != null,
              onStart: (username, email) =>
                  _checked(() => account.beginGuestUpgrade(username, email)),
              onFinish: (password) async {
                await _checked(() => account.finishGuestUpgrade(password));
                if (pageContext.mounted) Navigator.pop(pageContext);
              },
              onCheckVerification: account.checkEmailVerification,
            ),
          ),
        ),
      );

  Future<void> _import(BuildContext context) async {
    final s = NovaStrings.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.text('accountImportLegacy')),
        content: Text(s.text('accountImportLegacyDescription')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(s.text('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(s.text('accountImportLegacy'))),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final ok = await app.importLegacyData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(s.text(ok ? 'accountImportComplete' : 'accountGenericError')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return AnimatedBuilder(
      animation: account,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0, 12, 0, 24),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(LucideIcons.userRound,
                  color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      account.isGuest
                          ? s.text('accountGuest')
                          : (account.username ?? s.text('accountTitle')),
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                      account.isGuest
                          ? s.text('accountGuestDescription')
                          : (account.user?.email ?? ''),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              )),
            ]),
          ),
          const Divider(height: 1),
          SettingsTile(
              icon: LucideIcons.usersRound,
              title: s.text('profileManage'),
              onTap: () => _manage(context)),
          SettingsTile(
              icon: LucideIcons.arrowLeftRight,
              title: s.text('profileChoose'),
              onTap: () => _leave(context)),
          if (account.isGuest) ...[
            SettingsTile(
                icon: LucideIcons.userRoundPlus,
                title: s.text('accountUpgradeTitle'),
                onTap: () => _upgrade(context)),
            SettingsTile(
                icon: LucideIcons.logIn,
                title: s.text('accountLogIn'),
                onTap: () => _login(context)),
          ] else if (account.hasSavedGuest)
            SettingsTile(
                icon: LucideIcons.userRound,
                title: s.text('accountSwitchGuest'),
                onTap: () async {
                  await _changeIdentity(context, account.switchToSavedGuest);
                }),
          if (app.legacyImportAvailable)
            SettingsTile(
                icon: LucideIcons.download,
                title: s.text('accountImportLegacy'),
                onTap: () => _import(context)),
          if (!account.isGuest)
            SettingsTile(
                icon: LucideIcons.logOut,
                title: s.text('accountSignOut'),
                onTap: () async {
                  await _changeIdentity(context, account.signOut);
                }),
        ],
      ),
    );
  }
}
