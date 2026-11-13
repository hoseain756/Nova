import 'watch_party_relay_settings.dart';

const watchPartyCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
String normalizeWatchPartyCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
bool validWatchPartyCode(String code) =>
    RegExp(r'^(?:[A-HJ-NP-Z2-9]{6}|[A-HJ-NP-Z2-9]{8})$').hasMatch(code);
String formatWatchPartyCode(String code) {
  final split = code.length == 6 ? 3 : 4;
  return validWatchPartyCode(code)
      ? '${code.substring(0, split)} ${code.substring(split)}'
      : code;
}

String? watchPartyCodeFromInput(String input) {
  final text = input.trim();
  final invite = parseWatchPartyInvitation(text);
  if (invite != null) return invite.code;
  final code = normalizeWatchPartyCode(text);
  return validWatchPartyCode(code) ? code : null;
}

String watchPartyInvite(String code, {Uri? relay}) =>
    Uri(scheme: 'app.nova.mobile', host: 'watch-party', queryParameters: {
      'code': code,
      if (relay != null)
        'relay': normalizeWatchPartyRelayEndpoint(relay.toString()).toString()
    }).toString();
String? parseWatchPartyInvite(String input) {
  final invitation = parseWatchPartyInvitation(input);
  // Legacy automatic handlers must never discard a relay's explicit consent.
  return invitation?.relay == null ? invitation?.code : null;
}

WatchPartyInvitation? parseWatchPartyInvitation(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null ||
      uri.scheme != 'app.nova.mobile' ||
      uri.host != 'watch-party' ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.fragment.isNotEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.queryParameters.keys.any((key) => key != 'code' && key != 'relay') ||
      uri.queryParametersAll['code']?.length != 1 ||
      (uri.queryParametersAll.containsKey('relay') &&
          uri.queryParametersAll['relay']?.length != 1)) {
    return null;
  }
  final code = normalizeWatchPartyCode(uri.queryParameters['code'] ?? '');
  if (!validWatchPartyCode(code)) return null;
  Uri? relay;
  if (uri.queryParameters.containsKey('relay')) {
    try {
      relay = normalizeWatchPartyRelayEndpoint(uri.queryParameters['relay']!);
    } on FormatException {
      return null;
    }
  }
  return WatchPartyInvitation(code: code, relay: relay);
}

class WatchPartyInvitation {
  const WatchPartyInvitation({required this.code, this.relay});
  final String code;
  final Uri? relay;
}
