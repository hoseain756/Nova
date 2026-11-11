import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/account_controller.dart';
import '../../core/state/app_state.dart';
import '../../core/watch_party/watch_party_controller.dart';
import '../../core/watch_party/watch_party_models.dart';
import '../../core/watch_party/watch_party_service.dart';

class WatchPartyScope extends StatefulWidget {
  const WatchPartyScope(
      {super.key,
      required this.account,
      required this.app,
      required this.child});
  final AccountController? account;
  final AppState app;
  final Widget child;
  @override
  State<WatchPartyScope> createState() => _WatchPartyScopeState();
}

class _WatchPartyScopeState extends State<WatchPartyScope> {
  WatchPartyController? _controller;
  @override
  void initState() {
    super.initState();
    widget.account?.addListener(_bind);
    widget.app.addListener(_bind);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (widget.account == null) return;
    String device;
    try {
      final prefs = await SharedPreferences.getInstance();
      device = prefs.getString('nova.watch-party.device') ?? newWatchPartyId();
      await prefs.setString('nova.watch-party.device', device);
    } catch (_) {
      device = newWatchPartyId();
    }
    if (!mounted) return;
    _controller = WatchPartyController(
        SupabaseWatchPartyGateway(Supabase.instance.client),
        deviceId: device);
    _bind();
    setState(() {});
  }

  void _bind() {
    final account = widget.account;
    final eligible = account?.user != null &&
        account?.isGuest == false &&
        account?.activeProfileId != null &&
        account?.activeProfileId == widget.app.activeProfileId &&
        widget.app.sync.accountId == account?.user?.id &&
        !widget.app.kidsSession;
    _controller?.bindIdentity(eligible ? account!.user!.id : null,
        eligible ? account!.activeProfileId : null);
  }

  @override
  void dispose() {
    widget.account?.removeListener(_bind);
    widget.app.removeListener(_bind);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Provider<WatchPartyHandle>.value(
      value: WatchPartyHandle(_controller),
      child: ChangeNotifierProvider<WatchPartyController?>.value(
          value: _controller, child: widget.child));
}
