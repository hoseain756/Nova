import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../l10n/nova_strings.dart';

/// A pending room change can retry this once the player is visible. The action
/// rechecks visibility, so it never starts navigation behind a later modal.
bool showWatchPartyFollowPrompt(
  BuildContext context, {
  required String messageKey,
  required bool Function() canShow,
  required VoidCallback onFollow,
}) {
  if (!context.mounted ||
      !canShow() ||
      WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
    return false;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return false;
  final strings = NovaStrings.of(context);
  messenger.showSnackBar(SnackBar(
    content: Text(strings.text(messageKey)),
    duration: const Duration(seconds: 12),
    action: SnackBarAction(
      label: strings.text('partyFollowPlayback'),
      onPressed: () {
        if (context.mounted && canShow()) onFollow();
      },
    ),
  ));
  return true;
}
