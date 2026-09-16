import 'package:flutter_test/flutter_test.dart';

import 'package:dhealth/models/oauth_token_set.dart';

void main() {
  group('OAuthTokenSet.isExpired', () {
    test('false when expiresAt is unset (on-device / mock adapters)', () {
      const tokenSet = OAuthTokenSet(accessToken: 'a');
      expect(tokenSet.isExpired, isFalse);
    });

    test('false when expiresAt is comfortably in the future', () {
      final tokenSet = OAuthTokenSet(
        accessToken: 'a',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(tokenSet.isExpired, isFalse);
    });

    test('true once within the 5-minute refresh buffer', () {
      final tokenSet = OAuthTokenSet(
        accessToken: 'a',
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      );
      expect(tokenSet.isExpired, isTrue);
    });

    test('true when expiresAt is in the past', () {
      final tokenSet = OAuthTokenSet(
        accessToken: 'a',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(tokenSet.isExpired, isTrue);
    });
  });
}
