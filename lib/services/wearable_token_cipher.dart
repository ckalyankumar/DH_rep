import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the symmetric key persists between app runs. Abstracted so tests
/// can inject an in-memory fake instead of touching the platform Keychain
/// / Keystore via real [FlutterSecureStorage] platform channels.
abstract class SecureKeyStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class FlutterSecureKeyStorage implements SecureKeyStorage {
  final FlutterSecureStorage _storage;

  const FlutterSecureKeyStorage([this._storage = const FlutterSecureStorage()]);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
}

/// AES-256-GCM encryption for OAuth tokens at rest (WearableSource's
/// encryptedOauthToken / encryptedRefreshToken fields).
///
/// The symmetric key is generated on first use and lives only in the
/// platform Keychain/Keystore — never in Firestore, never in .env, never
/// committed to source. WearableSyncService is the only caller: it
/// encrypts immediately before every WearableSource write and decrypts
/// immediately after every read, so no other code ever sees ciphertext
/// or needs to know this exists.
///
/// Key-loss design choice (flagged, not an oversight): if the
/// secure-storage key is ever lost — app data wiped, device reset,
/// secure enclave cleared, user restores onto a new device without an
/// OS-level Keychain/Keystore backup — every previously stored token
/// becomes permanently undecryptable. There is no recovery path and none
/// is implemented. This is treated exactly like a revoked/expired token:
/// [decryptOrNull] returns null, WearableSyncService treats that as
/// "needs reconnect," and the user re-authenticates. No key rotation or
/// key-backup scheme exists. Given tokens are always re-obtainable via
/// OAuth (unlike, say, encrypted health records), this seemed like the
/// right tradeoff over the added complexity of key backup/rotation — but
/// it's a deliberate choice worth revisiting if that assumption changes.
class WearableTokenCipher {
  static const _keyStorageKey = 'wearable_token_encryption_key_v1';

  final SecureKeyStorage _storage;
  final AesGcm _algorithm = AesGcm.with256bits();

  WearableTokenCipher({SecureKeyStorage? storage})
      : _storage = storage ?? const FlutterSecureKeyStorage();

  SecretKey? _cachedKey;

  Future<SecretKey> _getOrCreateKey() async {
    final cached = _cachedKey;
    if (cached != null) return cached;

    final existing = await _storage.read(_keyStorageKey);
    if (existing != null) {
      final key = SecretKey(base64Decode(existing));
      _cachedKey = key;
      return key;
    }

    final newKey = await _algorithm.newSecretKey();
    final keyBytes = await newKey.extractBytes();
    await _storage.write(_keyStorageKey, base64Encode(keyBytes));
    _cachedKey = newKey;
    return newKey;
  }

  /// Encrypts [plaintext]. An empty string encrypts to itself (`''`) —
  /// callers use `''` as the "no token" sentinel and must never see that
  /// turn into ciphertext-of-empty-string.
  Future<String> encrypt(String plaintext) async {
    if (plaintext.isEmpty) return '';
    final key = await _getOrCreateKey();
    final secretBox = await _algorithm.encrypt(utf8.encode(plaintext), secretKey: key);
    return base64Encode(secretBox.concatenation());
  }

  /// Decrypts [ciphertext]. Returns `null` — never throws — if the value
  /// isn't valid ciphertext for the current key: wrong/rotated key,
  /// corrupted data, or (the pre-encryption migration case) a plaintext
  /// token written before this cipher existed. Callers must treat null
  /// the same as "no usable token" rather than crash.
  Future<String?> decryptOrNull(String ciphertext) async {
    if (ciphertext.isEmpty) return '';
    try {
      final key = await _getOrCreateKey();
      final bytes = base64Decode(ciphertext);
      final secretBox = SecretBox.fromConcatenation(
        bytes,
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      final plainBytes = await _algorithm.decrypt(secretBox, secretKey: key);
      return utf8.decode(plainBytes);
    } catch (_) {
      return null;
    }
  }
}
