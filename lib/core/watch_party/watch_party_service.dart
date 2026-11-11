import 'package:supabase_flutter/supabase_flutter.dart';

/// realtime_client delivers the Phoenix broadcast envelope, not just its data.
Map<String, dynamic>? watchPartyBroadcastData(Map<String, dynamic> envelope) {
  final payload = envelope['payload'];
  return payload is Map ? Map<String, dynamic>.from(payload) : null;
}

abstract interface class WatchPartyGateway {
  Future<Map<String, dynamic>> request(Map<String, dynamic> params);
  void subscribe(
      String memberId,
      void Function(String, Map<String, dynamic>) onEvent,
      void Function(bool) onStatus);
  Future<void> unsubscribe();
}

class SupabaseWatchPartyGateway implements WatchPartyGateway {
  SupabaseWatchPartyGateway(this.client);
  final SupabaseClient client;
  RealtimeChannel? _channel;
  int _generation = 0;
  @override
  Future<Map<String, dynamic>> request(Map<String, dynamic> params) async =>
      Map<String, dynamic>.from(await client
          .rpc('nova_party', params: params)
          .timeout(const Duration(seconds: 10)) as Map);
  @override
  void subscribe(
      String memberId,
      void Function(String, Map<String, dynamic>) onEvent,
      void Function(bool) onStatus) {
    final generation = ++_generation;
    final old = _channel;
    if (old != null) client.removeChannel(old);
    final channel = client.channel('nova-party:$memberId',
        opts: const RealtimeChannelConfig(private: true));
    _channel = channel;
    for (final event in ['snapshot', 'chat', 'closed']) {
      channel.onBroadcast(
          event: event,
          callback: (payload) {
            final data = watchPartyBroadcastData(payload);
            if (generation == _generation && data != null) onEvent(event, data);
          });
    }
    channel.subscribe((status, error) {
      if (generation == _generation) {
        onStatus(status == RealtimeSubscribeStatus.subscribed);
      }
    });
  }

  @override
  Future<void> unsubscribe() async {
    ++_generation;
    final channel = _channel;
    _channel = null;
    if (channel != null) await client.removeChannel(channel);
  }
}
