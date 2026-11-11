const watchPartyCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
String normalizeWatchPartyCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
bool validWatchPartyCode(String code) =>
    RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code);
String watchPartyInvite(String code) => Uri(
    scheme: 'app.nova.mobile',
    host: 'watch-party',
    queryParameters: {'code': code}).toString();
String? parseWatchPartyInvite(String input) {
  final uri = Uri.tryParse(input);
  if (uri == null ||
      uri.scheme != 'app.nova.mobile' ||
      uri.host != 'watch-party' ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.fragment.isNotEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.queryParametersAll['code']?.length != 1) {
    return null;
  }
  final code = normalizeWatchPartyCode(uri.queryParameters['code'] ?? '');
  return validWatchPartyCode(code) ? code : null;
}
