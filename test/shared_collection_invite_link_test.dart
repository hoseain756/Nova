import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/shared_collections/invite_link.dart';

void main() {
  const token =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test('parses a collection invitation without treating OAuth as an invite',
      () {
    expect(
      parseSharedCollectionInvite(
          'app.nova.mobile://collection-invite?token=$token'),
      token,
    );
    expect(
      parseSharedCollectionInvite('app.nova.mobile://callback?token=$token'),
      isNull,
    );
  });

  test('rejects malformed, duplicated, and ambiguous invite tokens', () {
    expect(
      parseSharedCollectionInvite(
          'app.nova.mobile://collection-invite?token=${token.toUpperCase()}'),
      isNull,
    );
    expect(
      parseSharedCollectionInvite(
          'app.nova.mobile://collection-invite?token=$token&token=$token'),
      isNull,
    );
    expect(
      parseSharedCollectionInvite(
          'app.nova.mobile://collection-invite/other?token=$token'),
      isNull,
    );
    expect(
      parseSharedCollectionInvite(
          'https://example.com/collection-invite?token=$token'),
      isNull,
    );
    expect(
      parseSharedCollectionInvite(
          'app.nova.mobile://collection-invite?token=$token#extra'),
      isNull,
    );
  });
}
