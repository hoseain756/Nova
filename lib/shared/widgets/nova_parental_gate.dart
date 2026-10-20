import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/nova_strings.dart';

/// Local-only parent credential, deliberately excluded from settings/cloud sync.
abstract final class NovaParentalGate {
  static const _storage = FlutterSecureStorage();
  static const _key = 'nova.parent-pin.v1';

  static Future<({bool available, String? value})> _readCredential(
      BuildContext context) async {
    try {
      return (available: true, value: await _storage.read(key: _key));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(NovaStrings.of(context).text('errorBody'))));
      }
      return (available: false, value: null);
    }
  }

  static Future<bool> ensureConfigured(BuildContext context) async {
    final credential = await _readCredential(context);
    if (!context.mounted || !credential.available) return false;
    if (credential.value != null) return true;
    return await _show(context, create: true);
  }

  static Future<bool> verify(BuildContext context) async {
    final credential = await _readCredential(context);
    // An unconfigured gate never silently unlocks an already active Kids session.
    if (!context.mounted || !credential.available || credential.value == null) {
      return false;
    }
    return _show(context, create: false);
  }

  static Future<bool> change(BuildContext context) async {
    final credential = await _readCredential(context);
    if (!context.mounted || !credential.available) return false;
    if (credential.value != null && !await verify(context)) return false;
    if (!context.mounted) return false;
    return _show(context, create: true);
  }

  static Future<bool> _show(BuildContext context,
          {required bool create}) async =>
      await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _PinDialog(create: create)) ??
      false;

  static String _digest(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
  static bool _equal(String a, String b) {
    var difference = a.length ^ b.length;
    for (var i = 0; i < min(a.length, b.length); i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.create});
  final bool create;
  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final strings = NovaStrings.of(context);
    final value = _pin.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(value) ||
        widget.create && value != _confirm.text) {
      setState(() => _error = strings.text('pinInvalid'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockUntil = prefs.getInt('nova.parent-pin.lock-until') ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < lockUntil) {
        if (mounted) setState(() => _error = strings.text('pinLocked'));
        return;
      }
      if (widget.create) {
        final random = Random.secure();
        final salt =
            base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
        await NovaParentalGate._storage.write(
            key: NovaParentalGate._key,
            value: jsonEncode(
                {'salt': salt, 'hash': NovaParentalGate._digest(salt, value)}));
      } else {
        final raw =
            await NovaParentalGate._storage.read(key: NovaParentalGate._key);
        if (raw == null) {
          if (mounted) setState(() => _error = strings.text('errorBody'));
          return;
        }
        final record = jsonDecode(raw) as Map;
        if (!NovaParentalGate._equal(
            NovaParentalGate._digest(record['salt'] as String, value),
            record['hash'] as String)) {
          final attempts = (prefs.getInt('nova.parent-pin.attempts') ?? 0) + 1;
          await prefs.setInt(
              'nova.parent-pin.attempts', attempts >= 5 ? 0 : attempts);
          if (attempts >= 5) {
            await prefs.setInt(
                'nova.parent-pin.lock-until',
                DateTime.now()
                    .add(const Duration(minutes: 1))
                    .millisecondsSinceEpoch);
          }
          if (mounted) {
            setState(() => _error =
                strings.text(attempts >= 5 ? 'pinLocked' : 'pinWrong'));
          }
          return;
        }
      }
      await prefs.remove('nova.parent-pin.attempts');
      await prefs.remove('nova.parent-pin.lock-until');
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = strings.text('errorBody'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NovaStrings.of(context);
    return AlertDialog(
      scrollable: true,
      icon: Icon(LucideIcons.shieldCheck,
          color: Theme.of(context).colorScheme.secondary, size: 32),
      title: Text(s.text(widget.create ? 'createPin' : 'parentGate')),
      content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.text(widget.create ? 'createPinBody' : 'parentExplain')),
            const SizedBox(height: 24),
            TextField(
                controller: _pin,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                inputFormatters: _pinFormatters,
                textDirection: TextDirection.ltr,
                decoration:
                    InputDecoration(labelText: s.text('pin'), counterText: ''),
                onSubmitted: (_) {
                  if (!widget.create) _submit();
                }),
            if (widget.create) ...[
              const SizedBox(height: 16),
              TextField(
                  controller: _confirm,
                  obscureText: true,
                  maxLength: 8,
                  keyboardType: TextInputType.number,
                  inputFormatters: _pinFormatters,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                      labelText: s.text('confirmPin'), counterText: ''),
                  onSubmitted: (_) => _submit())
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsetsDirectional.only(top: 16),
                  child: Semantics(
                      liveRegion: true,
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)))),
          ])),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: Text(s.text('cancel'))),
        FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(s.text(widget.create ? 'save' : 'unlock')))
      ],
    );
  }
}

// Arabic keyboards can emit either digit alphabet. Normalize before filtering
// so the same PIN works across app language and keyboard changes.
final _pinFormatters = <TextInputFormatter>[
  TextInputFormatter.withFunction((oldValue, newValue) {
    final normalized = String.fromCharCodes(newValue.text.runes.map((digit) {
      if (digit >= 0x0660 && digit <= 0x0669) return digit - 0x0660 + 0x30;
      if (digit >= 0x06f0 && digit <= 0x06f9) return digit - 0x06f0 + 0x30;
      return digit;
    }));
    return newValue.copyWith(text: normalized);
  }),
  FilteringTextInputFormatter.digitsOnly,
];
