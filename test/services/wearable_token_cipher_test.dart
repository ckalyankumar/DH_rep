import 'package:flutter_test/flutter_test.dart';

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
  group('WearableTokenCipher', () {
    test('round-trips a plaintext token through encrypt/decrypt', () async {
      final cipher = WearableTokenCipher(storage: FakeSecureKeyStorage());

      final ciphertext = await cipher.encrypt('my-access-token');
      expect(ciphertext, isNot('my-access-token'));
      expect(ciphertext, isNotEmpty);

      final decrypted = await cipher.decryptOrNull(ciphertext);
      expect(decrypted, 'my-access-token');
    });

    test('empty string round-trips to empty string, never real ciphertext', () async {
      final cipher = WearableTokenCipher(storage: FakeSecureKeyStorage());

      expect(await cipher.encrypt(''), '');
      expect(await cipher.decryptOrNull(''), '');
    });

    test('reuses the same key across calls (persisted via storage)', () async {
      final storage = FakeSecureKeyStorage();
      final cipherA = WearableTokenCipher(storage: storage);
      final cipherB = WearableTokenCipher(storage: storage);

      final ciphertext = await cipherA.encrypt('token-123');
      // A fresh instance backed by the same storage should still decrypt
      // it — the key persists independently of the cipher object.
      final decrypted = await cipherB.decryptOrNull(ciphertext);
      expect(decrypted, 'token-123');
    });

    test('decryptOrNull returns null for a pre-encryption plaintext value '
        '(migration case) instead of throwing', () async {
      final cipher = WearableTokenCipher(storage: FakeSecureKeyStorage());

      // Simulates a WearableSource doc written before this cipher existed
      // — a raw plaintext token sitting in the encryptedOauthToken field.
      final result = await cipher.decryptOrNull('mock_token_appleHealth');
      expect(result, isNull);
    });

    test('decryptOrNull returns null for garbage/corrupted ciphertext', () async {
      final cipher = WearableTokenCipher(storage: FakeSecureKeyStorage());
      final result = await cipher.decryptOrNull('not-valid-base64-ciphertext!!!');
      expect(result, isNull);
    });

    test('decryptOrNull returns null when the key has changed (key-loss case)', () async {
      final storageA = FakeSecureKeyStorage();
      final cipherA = WearableTokenCipher(storage: storageA);
      final ciphertext = await cipherA.encrypt('token-456');

      // A different storage backing = a different device/reinstall that
      // never had the original key — simulates the documented key-loss
      // scenario (Keychain/Keystore wiped, no backup).
      final cipherB = WearableTokenCipher(storage: FakeSecureKeyStorage());
      final result = await cipherB.decryptOrNull(ciphertext);
      expect(result, isNull);
    });
  });
}
