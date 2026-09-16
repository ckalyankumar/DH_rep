import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/services/wearable_repository.dart';
import 'package:dhealth/services/wearable_sync_service.dart';
import 'package:dhealth/services/wearable_token_cipher.dart';

/// In-memory fake so tests never touch the platform Keychain/Keystore.
class FakeSecureKeyStorage implements SecureKeyStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }
}

void main() {
  group('WearableSyncService token plumbing', () {
    late FakeFirebaseFirestore db;
    late WearableRepository repo;
    late WearableTokenCipher cipher;
    late WearableSyncService sync;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = WearableRepository(firestore: db);
      cipher = WearableTokenCipher(storage: FakeSecureKeyStorage());
      sync = WearableSyncService(repo: repo, cipher: cipher);
    });

    test('connect() persists the token set returned by authenticate(), encrypted',
        () async {
      await sync.connect('uid1', WearableProvider.appleHealth);

      final source = await repo.getSource('uid1', WearableProvider.appleHealth);
      expect(source, isNotNull);
      expect(source!.isActive, isTrue);

      // What's on the document must NOT be the plaintext mock token —
      // it's ciphertext now.
      expect(source.encryptedOauthToken, isNot('mock_token_appleHealth'));
      expect(source.encryptedOauthToken, isNotEmpty);

      // But it decrypts back to exactly what authenticate() returned.
      final decrypted = await cipher.decryptOrNull(source.encryptedOauthToken);
      expect(decrypted, 'mock_token_appleHealth');

      // Mock adapters return no refresh token / expiry — fields should
      // round-trip as empty/null, not crash or default to garbage.
      expect(source.encryptedRefreshToken, '');
      expect(source.tokenExpiresAt, isNull);
    });

    test('syncDate() decrypts the stored token, fetches a summary, and '
        're-encrypts on write', () async {
      await sync.connect('uid1', WearableProvider.appleHealth);
      final before = await repo.getSource('uid1', WearableProvider.appleHealth);

      final agg = await sync.syncDate('uid1', WearableProvider.appleHealth, '2026-09-01');

      expect(agg, isNotNull);
      expect(agg!.uid, 'uid1');
      expect(agg.date, '2026-09-01');

      final stored = await repo.getAggregate('uid1', '2026-09-01');
      expect(stored, isNotNull);

      final after = await repo.getSource('uid1', WearableProvider.appleHealth);
      expect(after!.lastSyncedAt.isAfter(before!.lastSyncedAt) ||
          after.lastSyncedAt.isAtSameMomentAs(before.lastSyncedAt), isTrue);
      // Still ciphertext after the round trip, still decrypts correctly.
      expect(after.encryptedOauthToken, isNot('mock_token_appleHealth'));
      expect(await cipher.decryptOrNull(after.encryptedOauthToken),
          'mock_token_appleHealth');
    });

    test('syncDate() returns null for a disconnected provider', () async {
      final agg = await sync.syncDate('uid1', WearableProvider.appleHealth, '2026-09-01');
      expect(agg, isNull);
    });

    test('syncDate() returns null once the source is deactivated', () async {
      await sync.connect('uid1', WearableProvider.appleHealth);
      final source = await repo.getSource('uid1', WearableProvider.appleHealth);
      await repo.saveSource(source!.copyWith(isActive: false));

      final agg = await sync.syncDate('uid1', WearableProvider.appleHealth, '2026-09-01');
      expect(agg, isNull);
    });

    test('syncDate() returns null after disconnect() removes the source',
        () async {
      await sync.connect('uid1', WearableProvider.appleHealth);
      await sync.disconnect('uid1', WearableProvider.appleHealth);

      final agg = await sync.syncDate('uid1', WearableProvider.appleHealth, '2026-09-01');
      expect(agg, isNull);
    });

    test('syncDate() returns null (not a crash) when the stored token is '
        'plaintext from before encryption existed — the migration case',
        () async {
      // Simulates a WearableSource written by an older build, before
      // WearableSyncService started encrypting these fields.
      await repo.saveSource(WearableSource(
        id: WearableProvider.appleHealth.name,
        uid: 'uid1',
        provider: WearableProvider.appleHealth,
        scopes: const [],
        encryptedOauthToken: 'mock_token_appleHealth', // plaintext, not ciphertext
        lastSyncedAt: DateTime.now(),
        isActive: true,
        consentGrantedAt: DateTime.now(),
      ));

      final agg = await sync.syncDate('uid1', WearableProvider.appleHealth, '2026-09-01');
      expect(agg, isNull);
    });

    test('a token encrypted under one device key cannot be read back after '
        'the key is lost (key-loss case), and does not crash', () async {
      await sync.connect('uid1', WearableProvider.appleHealth);

      // A new WearableSyncService backed by a *different* cipher/storage
      // simulates a fresh device install with no access to the original
      // Keychain/Keystore key.
      final syncOnNewDevice = WearableSyncService(
        repo: repo,
        cipher: WearableTokenCipher(storage: FakeSecureKeyStorage()),
      );

      final agg =
          await syncOnNewDevice.syncDate('uid1', WearableProvider.appleHealth, '2026-09-01');
      expect(agg, isNull);
    });
  });
}
