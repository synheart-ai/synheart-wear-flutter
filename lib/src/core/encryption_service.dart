import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';

/// Where the cache key is kept.
abstract class CacheKeyStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// Keeps the cache key in the iOS Keychain (after first unlock, this device
/// only, never synced) or the Android Keystore-backed secure storage.
class SecureCacheKeyStore implements CacheKeyStore {
  static const _name = 'synheart_wear_cache_key_v2';

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  const SecureCacheKeyStore();

  @override
  Future<String?> read() => _storage.read(key: _name);

  @override
  Future<void> write(String value) => _storage.write(key: _name, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _name);
}

/// AES-256-GCM encryption for cached sessions.
///
/// Each record gets a fresh random 96-bit nonce, so no nonce is reused under
/// the key, and the GCM tag makes a tampered record fail to decrypt instead
/// of returning garbage.
class EncryptionService {
  static const String algorithm = 'AES-256-GCM';
  static const int _formatVersion = 2;
  static const int _keyLength = 32;
  static const int _nonceLength = 12;

  /// Key file written by earlier versions, deleted on first use.
  static const String _legacyKeyFileName = 'synheart_encryption.key';

  static CacheKeyStore _keyStore = const SecureCacheKeyStore();
  static Encrypter? _encrypter;
  static bool _legacyKeyRemoved = false;

  /// Replaces the key store. For tests only.
  @visibleForTesting
  static set keyStoreForTesting(CacheKeyStore store) {
    _keyStore = store;
    _encrypter = null;
    _legacyKeyRemoved = true;
  }

  static Future<Encrypter> _getEncrypter() async {
    final existing = _encrypter;
    if (existing != null) return existing;

    await _removeLegacyKeyFile();
    final key = await _getOrCreateKey();
    return _encrypter = Encrypter(AES(key, mode: AESMode.gcm));
  }

  static Future<Key> _getOrCreateKey() async {
    final stored = await _keyStore.read();
    if (stored != null) {
      final bytes = base64Decode(stored);
      if (bytes.length == _keyLength) return Key(bytes);
    }
    final bytes = _randomBytes(_keyLength);
    await _keyStore.write(base64Encode(bytes));
    return Key(bytes);
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// The old key sat in plain view next to the data it protected.
  static Future<void> _removeLegacyKeyFile() async {
    if (_legacyKeyRemoved) return;
    _legacyKeyRemoved = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_legacyKeyFileName');
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort; a missing documents directory is not fatal.
    }
  }

  /// Encrypts [data] into a self-describing record.
  static Future<Map<String, Object?>> encryptData(
    Map<String, Object?> data,
  ) async {
    final encrypter = await _getEncrypter();
    final nonce = IV(_randomBytes(_nonceLength));
    final sealed = encrypter.encryptBytes(
      utf8.encode(jsonEncode(data)),
      iv: nonce,
    );
    return {
      'v': _formatVersion,
      'algorithm': algorithm,
      'nonce': nonce.base64,
      'ciphertext': sealed.base64,
    };
  }

  /// Decrypts a record produced by [encryptData]. Throws if the record is
  /// not in the current format, was tampered with, or was sealed under a
  /// different key.
  static Future<Map<String, Object?>> decryptData(
    Map<String, Object?> record,
  ) async {
    if (!isEncrypted(record)) {
      throw const FormatException('Not a current encrypted cache record');
    }
    final encrypter = await _getEncrypter();
    final plain = encrypter.decryptBytes(
      Encrypted.fromBase64(record['ciphertext'] as String),
      iv: IV.fromBase64(record['nonce'] as String),
    );
    return jsonDecode(utf8.decode(plain)) as Map<String, Object?>;
  }

  /// Whether [data] is a record in the current encrypted format.
  static bool isEncrypted(Map<String, Object?> data) {
    return data['v'] == _formatVersion &&
        data['algorithm'] == algorithm &&
        data['nonce'] is String &&
        data['ciphertext'] is String;
  }

  /// Whether [data] was written by the earlier encryption, which reused one
  /// IV per process. Such records are deleted rather than decrypted.
  static bool isLegacyEncrypted(Map<String, Object?> data) {
    return data.containsKey('encrypted_data') && data.containsKey('iv');
  }

  /// Replaces the key. Records sealed under the old key become unreadable.
  static Future<void> rotateKey() async {
    await _keyStore.delete();
    _encrypter = null;
  }

  /// Deletes the key, making every encrypted record unreadable.
  static Future<void> deleteKey() async {
    await _keyStore.delete();
    _encrypter = null;
  }
}
