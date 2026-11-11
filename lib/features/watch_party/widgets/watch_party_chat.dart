import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/nova_theme.dart';
import '../../../core/watch_party/watch_party_controller.dart';
import '../../../core/watch_party/watch_party_models.dart';
import '../../../l10n/nova_strings.dart';

/// The conversation scrolls independently while the draft stays in reach.
class WatchPartyChat extends StatefulWidget {
  const WatchPartyChat(
      {super.key,
      required this.controller,
      required this.room,
      required this.messageController});
  final WatchPartyController controller;
  final WatchPartySnapshot room;
  final TextEditingController messageController;
  @override
  State<WatchPartyChat> createState() => _WatchPartyChatState();
}

class _WatchPartyChatState extends State<WatchPartyChat>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String _t(String key) => NovaStrings.of(context).text(key);
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: LayoutBuilder(
                builder: (context, constraints) => Column(children: [
                      Expanded(child: _messages()),
                      ConstrainedBox(
                          constraints: BoxConstraints(
                              maxHeight: constraints.maxHeight * .7),
                          child: SingleChildScrollView(
                              key: const ValueKey('party-composer-scroll'),
                              child: _composer()))
                    ]))));
  }

  Widget _messages() => widget.controller.messages.isEmpty
      ? Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.messageCircle,
                    size: 32,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(_t('partyChatEmpty'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge)
              ])))
      : ListView.builder(
          key: const PageStorageKey('party-messages'),
          reverse: true,
          padding: EdgeInsets.all(
              NovaSpace.gutter(MediaQuery.sizeOf(context).width)),
          itemCount: widget.controller.messages.length,
          itemBuilder: (context, index) {
            final message = widget.controller
                .messages[widget.controller.messages.length - 1 - index];
            final self = message.memberId == widget.room.selfId;
            return Align(
                key: ValueKey(
                    'party-message-${message.memberId}-${message.clientId}'),
                alignment: self
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHigh
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(message.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary)),
                                      const SizedBox(height: 4),
                                      SelectableText(message.body,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge),
                                      if (message.pending)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Text(_t('partySending'),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall)),
                                      if (message.failed)
                                        TextButton.icon(
                                            onPressed: () => unawaited(widget
                                                .controller
                                                .sendMessage(message.body,
                                                    clientId:
                                                        message.clientId)),
                                            icon: const Icon(
                                                LucideIcons.refreshCw,
                                                size: 16),
                                            label:
                                                Text(_t('partyRetryMessage')))
                                    ]))))));
          });

  Widget _composer() {
    final message = widget.messageController.text;
    final length = message.trim().runes.length;
    final valid = length > 0 && length <= 500;
    return DecoratedBox(
        decoration: BoxDecoration(
            border: Border(
                top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant))),
        child: Padding(
            padding: EdgeInsets.all(
                NovaSpace.gutter(MediaQuery.sizeOf(context).width)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: TextField(
                      key: const ValueKey('party-message-input'),
                      controller: widget.messageController,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 500,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                          labelText: _t('partyMessage'),
                          counterText: message.isEmpty
                              ? ''
                              : '${message.runes.length}/500',
                          errorMaxLines: 6,
                          errorText:
                              length > 500 ? _t('partyMessageLimit') : null),
                      onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filled(
                      key: const ValueKey('party-send-message'),
                      tooltip: _t('partySend'),
                      style: IconButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          disabledForegroundColor:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          disabledBackgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest),
                      onPressed: valid
                          ? () {
                              final body = widget.messageController.text;
                              widget.messageController.clear();
                              setState(() {});
                              unawaited(widget.controller.sendMessage(body));
                            }
                          : null,
                      icon: const Icon(LucideIcons.send, size: 20)))
            ])));
  }
}
