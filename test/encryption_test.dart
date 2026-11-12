import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/src/core/encryption_service.dart';
import 'package:synheart_wear/src/core/local_cache.dart';
import 'package:synheart_wear/src/core/models.dart';

class _MemoryKeyStore implements CacheKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async => value = v;
  @override
  Future<void> delete() async => value = null;
}

class _FailingKeyStore implements CacheKeyStore {
  @override
  Future<String?> read() async => throw Exception('keychain unavailable');
  @override
  Future<void> write(String v) async => throw Exception('keychain unavailable');
  @override
  Future<void> delete() async {}
}

WearMetrics _metrics(int ms, {num hr = 60}) => WearMetrics(
  timestamp: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
  deviceId: 'device-a',
  source: 'apple_healthkit',
  metrics: {'hr': hr, 'hrv_rmssd': 42.5},
  meta: {'note': 'x'},
  rrIntervalsMs: [800, 810],
);

void main() {
  late Directory dir;
  late _MemoryKeyStore keys;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wear-cache');
    keys = _MemoryKeyStore();
    EncryptionService.keyStoreForTesting = keys;
    LocalCache.directoryForTesting = dir;
  });

  tearDown(() async {
    LocalCache.directoryForTesting = null;
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  List<File> files() => dir.listSync().whereType<File>().toList();

  group('EncryptionService', () {
    test('round-trips a record', () async {
      final record = await EncryptionService.encryptData({'hr': 72});
      expect(EncryptionService.isEncrypted(record), isTrue);
      expect(record['algorithm'], 'AES-256-GCM');
      expect(await EncryptionService.decryptData(record), {'hr': 72});
    });

    test('uses a fresh nonce for every record', () async {
      final a = await EncryptionService.encryptData({'hr': 72});
      final b = await EncryptionService.encryptData({'hr': 72});
      expect(a['nonce'], isNot(b['nonce']));
      expect(a['ciphertext'], isNot(b['ciphertext']));
    });

    test('stores a 256-bit key in the key store', () async {
      await EncryptionService.encryptData({'hr': 72});
      expect(base64Decode(keys.value!).length, 32);
    });

    test('rejects a tampered record', () async {
      final record = await EncryptionService.encryptData({'hr': 72});
      final bytes = base64Decode(record['ciphertext'] as String);
      bytes[0] ^= 1;
      final tampered = {...record, 'ciphertext': base64Encode(bytes)};
      expect(() => EncryptionService.decryptData(tampered), throwsA(anything));
    });

    test('rejects a record sealed under another key', () async {
      final record = await EncryptionService.encryptData({'hr': 72});
      await EncryptionService.rotateKey();
      expect(() => EncryptionService.decryptData(record), throwsA(anything));
    });

    test('recognises the old format as legacy, not current', () {
      final old = {
        'encrypted_data': 'x',
        'iv': 'y',
        'algorithm': 'AES-256-CBC',
      };
      expect(EncryptionService.isEncrypted(old), isFalse);
      expect(EncryptionService.isLegacyEncrypted(old), isTrue);
      expect(EncryptionService.isEncrypted({'hr': 72}), isFalse);
    });
  });

  group('LocalCache', () {
    test('encrypted round trip', () async {
      await LocalCache.storeSession(_metrics(1000));
      final sessions = await LocalCache.getCachedSessions(
        enableEncryption: true,
      );
      expect(sessions, hasLength(1));
      expect(sessions.single.metrics, {'hr': 60, 'hrv_rmssd': 42.5});
      expect(sessions.single.rrIntervalsMs, [800, 810]);
      expect(sessions.single.timestamp.millisecondsSinceEpoch, 1000);
    });

    test('encrypted files reveal nothing about the session', () async {
      await LocalCache.storeSession(_metrics(1000));
      final stored = files();
      expect(stored, hasLength(1));
      final name = stored.single.uri.pathSegments.last;
      expect(name, isNot(contains('device-a')));
      final text = stored.single.readAsStringSync();
      expect(text, isNot(contains('apple_healthkit')));
      expect(text, isNot(contains('device-a')));
      expect(text, isNot(contains('hrv_rmssd')));
    });

    test('writes no meta log when encrypted', () async {
      await LocalCache.storeSession(_metrics(1000));
      expect(File('${dir.path}/meta.log').existsSync(), isFalse);
    });

    test('does not write anything when the key is unavailable', () async {
      EncryptionService.keyStoreForTesting = _FailingKeyStore();
      await LocalCache.storeSession(_metrics(1000));
      expect(files(), isEmpty);
    });

    test('drops a tampered record', () async {
      await LocalCache.storeSession(_metrics(1000));
      final file = files().single;
      final record =
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final bytes = base64Decode(record['ciphertext'] as String);
      bytes[bytes.length - 1] ^= 1;
      file.writeAsStringSync(
        jsonEncode({...record, 'ciphertext': base64Encode(bytes)}),
      );

      expect(
        await LocalCache.getCachedSessions(enableEncryption: true),
        isEmpty,
      );
      expect(file.existsSync(), isFalse);
    });

    test('deletes plaintext records when encryption is on', () async {
      await LocalCache.storeSession(_metrics(1000), enableEncryption: false);
      expect(
        await LocalCache.getCachedSessions(enableEncryption: true),
        isEmpty,
      );
      expect(files().where((f) => f.path.contains('session_')), isEmpty);
    });

    test('deletes files written by earlier versions', () async {
      final legacy =
          File('${dir.path}/session_2026-01-01T00-00-00.000_device-a.json')
            ..writeAsStringSync(
              jsonEncode({
                'encrypted_data': 'x',
                'iv': 'y',
                'algorithm': 'AES-256-CBC',
              }),
            );
      // Each test gets a new directory, so the one-time cleanup runs here.
      await LocalCache.getCachedSessions();

      expect(legacy.existsSync(), isFalse);
    });

    test('unencrypted mode stores readable JSON', () async {
      await LocalCache.storeSession(_metrics(1000), enableEncryption: false);
      final session = files().firstWhere(
        (f) => f.uri.pathSegments.last.startsWith('session_'),
      );
      expect(session.readAsStringSync(), contains('apple_healthkit'));
      expect(
        await LocalCache.getCachedSessions(enableEncryption: false),
        hasLength(1),
      );
    });

    test('filters by range, sorts newest first, then limits', () async {
      for (final ms in [1000, 5000, 3000, 9000, 7000]) {
        await LocalCache.storeSession(_metrics(ms));
      }
      final sessions = await LocalCache.getCachedSessions(
        startDate: DateTime.fromMillisecondsSinceEpoch(2000),
        endDate: DateTime.fromMillisecondsSinceEpoch(8000),
        limit: 2,
        enableEncryption: true,
      );
      expect(sessions.map((s) => s.timestamp.millisecondsSinceEpoch), [
        7000,
        5000,
      ]);
    });

    test('two sessions with the same timestamp are both kept', () async {
      await LocalCache.storeSession(_metrics(1000, hr: 60));
      await LocalCache.storeSession(_metrics(1000, hr: 70));
      expect(await LocalCache.getCachedSessions(), hasLength(2));
    });

    test('stats count only session records', () async {
      await LocalCache.storeSession(_metrics(1000));
      await LocalCache.storeSession(_metrics(2000));
      await LocalCache.storeMetadata({'k': 'v'});
      final stats = await LocalCache.getCacheStats(encryptionEnabled: true);
      expect(stats['total_sessions'], 2);
      expect(stats['encryption_enabled'], isTrue);
    });
  });
}
