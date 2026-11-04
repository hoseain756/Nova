import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/nova_theme.dart';
import '../../l10n/nova_strings.dart';
import '../../shared/widgets/nova_brand.dart';

/// Shared layout for account entry routes. The parent's theme supplies the
/// same typography, controls, and colour roles used by the rest of NOVA.
class AccountEntryLayout extends StatelessWidget {
  const AccountEntryLayout({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.leading,
  });

  final String title;
  final String? description;
  final Widget? leading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  NovaSpace.gutter(constraints.maxWidth),
                  NovaSpace.xl,
                  NovaSpace.gutter(constraints.maxWidth),
                  NovaSpace.xl + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (leading != null) ...[
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: leading,
                        ),
                        const SizedBox(height: NovaSpace.xl),
                      ],
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: NovaBrand(width: 148),
                      ),
                      const SizedBox(height: NovaSpace.xxl),
                      Semantics(
                        header: true,
                        child: Text(title,
                            style: Theme.of(context).textTheme.headlineMedium),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: NovaSpace.sm),
                        Text(description!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                )),
                      ],
                      const SizedBox(height: NovaSpace.xl),
                      ...children,
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      );
}

class AccountWelcomePage extends StatefulWidget {
  const AccountWelcomePage({
    super.key,
    required this.onLogIn,
    required this.onCreateAccount,
    required this.onContinueAsGuest,
    this.onResumeGuest,
  });

  final VoidCallback onLogIn;
  final VoidCallback onCreateAccount;
  final Future<void> Function() onContinueAsGuest;
  final Future<void> Function()? onResumeGuest;

  @override
  State<AccountWelcomePage> createState() => _AccountWelcomePageState();
}

class _AccountWelcomePageState extends State<AccountWelcomePage> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onContinueAsGuest();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return AccountEntryLayout(
      title: s.text('accountWelcomeTitle'),
      description: s.text('accountWelcomeBody'),
      children: [
        if (_failed) ...[
          _AccountMessage(s.text('accountGenericError')),
          const SizedBox(height: NovaSpace.md),
        ],
        FilledButton.icon(
          onPressed: _busy ? null : widget.onLogIn,
          icon: const Icon(LucideIcons.logIn),
          label: Text(s.text('accountLogIn')),
        ),
        const SizedBox(height: NovaSpace.md),
        OutlinedButton.icon(
          onPressed: _busy ? null : widget.onCreateAccount,
          icon: const Icon(LucideIcons.userRoundPlus),
          label: Text(s.text('accountCreate')),
        ),
        const SizedBox(height: NovaSpace.md),
        TextButton.icon(
          onPressed: _busy ? null : _continue,
          icon: const Icon(LucideIcons.userRound),
          label: Text(s.text('accountGuest')),
        ),
        if (widget.onResumeGuest != null)
          TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() {
                      _busy = true;
                      _failed = false;
                    });
                    try {
                      await widget.onResumeGuest!();
                    } catch (_) {
                      if (mounted) setState(() => _failed = true);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(LucideIcons.rotateCcw),
            label: Text(s.text('accountSwitchGuest')),
          ),
        if (_busy) ...[
          const SizedBox(height: NovaSpace.md),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}

class AccountSignInPage extends StatefulWidget {
  const AccountSignInPage({
    super.key,
    required this.onSubmit,
    required this.onForgotPassword,
  });

  final Future<void> Function(String identifier, String password) onSubmit;
  final VoidCallback onForgotPassword;

  @override
  State<AccountSignInPage> createState() => _AccountSignInPageState();
}

class _AccountSignInPageState extends State<AccountSignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _failed = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onSubmit(_identifier.text.trim(), _password.text);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return AccountEntryLayout(
      title: s.text('accountLogIn'),
      description: s.text('accountLoginDescription'),
      leading: const _BackButton(),
      children: [
        Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _identifier,
              enabled: !_busy,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email
              ],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: s.text('accountIdentifier'),
                prefixIcon: const Icon(LucideIcons.atSign),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? s.text('accountRequired')
                  : null,
            ),
            const SizedBox(height: NovaSpace.md),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: s.text('accountPassword'),
                prefixIcon: const Icon(LucideIcons.lockKeyhole),
                suffixIcon: IconButton(
                  tooltip: s.text(_showPassword
                      ? 'accountHidePassword'
                      : 'accountShowPassword'),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                      _showPassword ? LucideIcons.eyeOff : LucideIcons.eye),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? s.text('accountRequired')
                  : null,
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _busy ? null : widget.onForgotPassword,
                child: Text(s.text('accountForgotPassword')),
              ),
            ),
            if (_failed) ...[
              _AccountMessage(s.text('accountLoginFailed')),
              const SizedBox(height: NovaSpace.md),
            ],
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(s.text('accountLogIn')),
            ),
            if (_busy) ...[
              const SizedBox(height: NovaSpace.md),
              const LinearProgressIndicator(),
            ],
          ]),
        ),
      ],
    );
  }
}

class AccountSignUpPage extends StatefulWidget {
  const AccountSignUpPage({super.key, required this.onSubmit});

  final Future<void> Function(String username, String email, String password)
      onSubmit;

  @override
  State<AccountSignUpPage> createState() => _AccountSignUpPageState();
}

class _AccountSignUpPageState extends State<AccountSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _failed = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onSubmit(
        _username.text.trim(),
        _email.text.trim(),
        _password.text,
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return AccountEntryLayout(
      title: s.text('accountCreate'),
      description: s.text('accountCreateDescription'),
      leading: const _BackButton(),
      children: [
        Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _username,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: InputDecoration(
                labelText: s.text('accountUsername'),
                prefixIcon: const Icon(LucideIcons.userRound),
              ),
              validator: (value) {
                final username = value?.trim() ?? '';
                return RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(username)
                    ? null
                    : s.text('accountUsernameRule');
              },
            ),
            const SizedBox(height: NovaSpace.md),
            TextFormField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: s.text('accountEmail'),
                prefixIcon: const Icon(LucideIcons.mail),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                    ? null
                    : s.text('accountEmailRule');
              },
            ),
            const SizedBox(height: NovaSpace.md),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: s.text('accountPassword'),
                helperText: s.text('accountPasswordRule'),
                prefixIcon: const Icon(LucideIcons.lockKeyhole),
                suffixIcon: IconButton(
                  tooltip: s.text(_showPassword
                      ? 'accountHidePassword'
                      : 'accountShowPassword'),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                      _showPassword ? LucideIcons.eyeOff : LucideIcons.eye),
                ),
              ),
              validator: (value) {
                final password = value ?? '';
                return password.length >= 12 &&
                        RegExp(r'[A-Za-z]').hasMatch(password) &&
                        RegExp(r'\d').hasMatch(password)
                    ? null
                    : s.text('accountPasswordRule');
              },
            ),
            const SizedBox(height: NovaSpace.lg),
            if (_failed) ...[
              _AccountMessage(s.text('accountCreateFailed')),
              const SizedBox(height: NovaSpace.md),
            ],
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(s.text('accountCreate')),
            ),
            if (_busy) ...[
              const SizedBox(height: NovaSpace.md),
              const LinearProgressIndicator(),
            ],
          ]),
        ),
      ],
    );
  }
}

class AccountResetPage extends StatefulWidget {
  const AccountResetPage({super.key, required this.onSubmit});

  final Future<void> Function(String email) onSubmit;

  @override
  State<AccountResetPage> createState() => _AccountResetPageState();
}

class AccountEmailVerificationPage extends StatefulWidget {
  const AccountEmailVerificationPage({
    super.key,
    required this.onCheckVerification,
    this.onResend,
    this.onCancel,
  });

  final Future<void> Function() onCheckVerification;
  final Future<void> Function()? onResend;
  final VoidCallback? onCancel;

  @override
  State<AccountEmailVerificationPage> createState() =>
      _AccountEmailVerificationPageState();
}

class AccountUsernameCompletionPage extends StatefulWidget {
  const AccountUsernameCompletionPage({super.key, required this.onSubmit});

  final Future<void> Function(String username) onSubmit;

  @override
  State<AccountUsernameCompletionPage> createState() =>
      _AccountUsernameCompletionPageState();
}

class _AccountUsernameCompletionPageState
    extends State<AccountUsernameCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onSubmit(_username.text.trim());
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return AccountEntryLayout(
      title: s.text('accountUsernameCompletionTitle'),
      description: s.text('accountUsernameCompletionDescription'),
      children: [
        Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _username,
              enabled: !_busy,
              decoration: InputDecoration(labelText: s.text('accountUsername')),
              validator: (value) =>
                  RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : s.text('accountUsernameRule'),
            ),
            const SizedBox(height: NovaSpace.lg),
            if (_failed) ...[
              _AccountMessage(s.text('accountCreateFailed')),
              const SizedBox(height: NovaSpace.md),
            ],
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(s.text('accountContinue')),
            ),
            if (_busy) ...[
              const SizedBox(height: NovaSpace.md),
              const LinearProgressIndicator(),
            ],
          ]),
        ),
      ],
    );
  }
}

class AccountNewPasswordPage extends StatefulWidget {
  const AccountNewPasswordPage({super.key, required this.onSubmit});

  final Future<void> Function(String password) onSubmit;

  @override
  State<AccountNewPasswordPage> createState() => _AccountNewPasswordPageState();
}

class _AccountNewPasswordPageState extends State<AccountNewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onSubmit(_password.text);
      _password.clear();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return AccountEntryLayout(
      title: s.text('accountNewPasswordTitle'),
      description: s.text('accountNewPasswordDescription'),
      children: [
        Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: s.text('accountPassword'),
                helperText: s.text('accountPasswordRule'),
              ),
              validator: (value) {
                final password = value ?? '';
                return password.length >= 12 &&
                        RegExp(r'[A-Za-z]').hasMatch(password) &&
                        RegExp(r'\d').hasMatch(password)
                    ? null
                    : s.text('accountPasswordRule');
              },
            ),
            const SizedBox(height: NovaSpace.lg),
            if (_failed) ...[
              _AccountMessage(s.text('accountGenericError')),
              const SizedBox(height: NovaSpace.md),
            ],
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(s.text('accountSavePassword')),
            ),
            if (_busy) ...[
              const SizedBox(height: NovaSpace.md),
              const LinearProgressIndicator(),
            ],
          ]),
        ),
      ],
    );
  }
}

class _AccountEmailVerificationPageState
    extends State<AccountEmailVerificationPage> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return AccountEntryLayout(
      title: s.text('accountVerifyTitle'),
      description: s.text('accountVerifyDescription'),
      children: [
        if (_failed) ...[
          _AccountMessage(s.text('accountGenericError')),
          const SizedBox(height: NovaSpace.md),
        ],
        FilledButton(
          onPressed: _busy ? null : () => _run(widget.onCheckVerification),
          child: Text(s.text('accountUpgradeCheck')),
        ),
        if (widget.onResend != null) ...[
          const SizedBox(height: NovaSpace.sm),
          TextButton(
            onPressed: _busy ? null : () => _run(widget.onResend!),
            child: Text(s.text('accountVerifyResend')),
          ),
        ],
        if (widget.onCancel != null)
          TextButton(
              onPressed: widget.onCancel,
              child: Text(s.text('accountReturnWelcome'))),
        if (_busy) ...[
          const SizedBox(height: NovaSpace.md),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}

/// Converts the current anonymous account without changing its user ID.
/// [emailVerified] must come from a refreshed server Auth user, not local state.
class GuestUpgradePage extends StatefulWidget {
  const GuestUpgradePage({
    super.key,
    required this.emailVerified,
    required this.onStart,
    required this.onFinish,
    required this.onCheckVerification,
    this.initialSent = false,
    this.showBack = true,
  });

  final bool emailVerified;
  final bool initialSent;
  final bool showBack;
  final Future<void> Function(String username, String email) onStart;
  final Future<void> Function(String password) onFinish;
  final Future<void> Function() onCheckVerification;

  @override
  State<GuestUpgradePage> createState() => _GuestUpgradePageState();
}

class _GuestUpgradePageState extends State<GuestUpgradePage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _sent;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _sent = widget.initialSent;
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onStart(_username.text.trim(), _email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onFinish(_password.text);
      _password.clear();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onCheckVerification();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return AccountEntryLayout(
      title: s.text('accountUpgradeTitle'),
      description: s.text('accountUpgradeDescription'),
      leading: widget.showBack ? const _BackButton() : null,
      children: [
        if (_failed) ...[
          _AccountMessage(s.text('accountGenericError')),
          const SizedBox(height: NovaSpace.md),
        ],
        if (widget.emailVerified)
          Form(
            key: _formKey,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.text('accountUpgradeVerified')),
                  const SizedBox(height: NovaSpace.md),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: s.text('accountPassword'),
                      helperText: s.text('accountPasswordRule'),
                    ),
                    validator: (value) {
                      final password = value ?? '';
                      return password.length >= 12 &&
                              RegExp(r'[A-Za-z]').hasMatch(password) &&
                              RegExp(r'\d').hasMatch(password)
                          ? null
                          : s.text('accountPasswordRule');
                    },
                  ),
                  const SizedBox(height: NovaSpace.lg),
                  FilledButton(
                    onPressed: _busy ? null : _finish,
                    child: Text(s.text('accountUpgradeFinish')),
                  ),
                ]),
          )
        else if (_sent) ...[
          Text(s.text('accountUpgradeSent')),
          const SizedBox(height: NovaSpace.lg),
          FilledButton(
            onPressed: _busy ? null : _checkVerification,
            child: Text(s.text('accountUpgradeCheck')),
          ),
        ] else
          Form(
            key: _formKey,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _username,
                    enabled: !_busy,
                    decoration:
                        InputDecoration(labelText: s.text('accountUsername')),
                    validator: (value) => RegExp(r'^[A-Za-z0-9_]{3,24}$')
                            .hasMatch(value?.trim() ?? '')
                        ? null
                        : s.text('accountUsernameRule'),
                  ),
                  const SizedBox(height: NovaSpace.md),
                  TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        InputDecoration(labelText: s.text('accountEmail')),
                    validator: (value) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(value?.trim() ?? '')
                        ? null
                        : s.text('accountEmailRule'),
                  ),
                  const SizedBox(height: NovaSpace.lg),
                  FilledButton(
                    onPressed: _busy ? null : _start,
                    child: Text(s.text('accountUpgradeSend')),
                  ),
                ]),
          ),
        if (_busy) ...[
          const SizedBox(height: NovaSpace.md),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}

class _AccountResetPageState extends State<AccountResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _submitted = false;
  bool _failed = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onSubmit(_email.text.trim());
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return AccountEntryLayout(
      title: s.text('accountResetTitle'),
      description: s.text('accountResetDescription'),
      leading: const _BackButton(),
      children: [
        if (_submitted)
          Text(s.text('accountResetSent'))
        else
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => _submit(),
                  decoration:
                      InputDecoration(labelText: s.text('accountEmail')),
                  validator: (value) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : s.text('accountEmailRule'),
                ),
                const SizedBox(height: NovaSpace.lg),
                if (_failed) ...[
                  _AccountMessage(s.text('accountGenericError')),
                  const SizedBox(height: NovaSpace.md),
                ],
                FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(s.text('accountResetAction'))),
                if (_busy) ...[
                  const SizedBox(height: NovaSpace.md),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: Navigator.of(context).pop,
        icon: Icon(Directionality.of(context) == TextDirection.rtl
            ? LucideIcons.arrowRight
            : LucideIcons.arrowLeft),
      );
}

class _AccountMessage extends StatelessWidget {
  const _AccountMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
      );
}
