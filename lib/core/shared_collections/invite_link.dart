/// Accept only NOVA's dedicated collection-invite URL and a 256-bit
/// lowercase hex bearer token. OAuth callbacks never enter this path.
String? parseSharedCollectionInvite(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'app.nova.mobile' ||
      uri.host.toLowerCase() != 'collection-invite' ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.userInfo.isNotEmpty ||
      uri.port != 0 ||
      uri.queryParameters.length != 1 ||
      uri.queryParametersAll['token']?.length != 1 ||
      uri.fragment.isNotEmpty) {
    return null;
  }
  final token = uri.queryParameters['token'];
  return token != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(token)
      ? token
      : null;
}
