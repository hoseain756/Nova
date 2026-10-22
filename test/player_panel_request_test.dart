import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/widgets/player_panel_request.dart';

void main() {
  test('refresh supersedes an older subtitle result or error', () {
    final requests = PlayerPanelRequest();
    final first = requests.begin();
    final refresh = requests.begin();

    expect(requests.isCurrent(first), isFalse);
    expect(requests.isCurrent(refresh), isTrue);
  });

  test('closing or switching panels invalidates a pending fetch', () {
    final requests = PlayerPanelRequest();
    final subtitleFetch = requests.begin();
    requests.invalidate();
    expect(requests.isCurrent(subtitleFetch), isFalse);

    final sourceFetch = requests.begin();
    expect(requests.isCurrent(sourceFetch), isTrue);
  });
}
