import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';

import '../core/models.dart';
import 'encryption_service.dart';
import 'logger.dart';

/// Local caching system for wearable data.
///
/// With encryption on, each session is sealed with AES-256-GCM under a key
/// kept in platform secure storage (see [EncryptionService]). If the key
/// can't be obtained, the session is not cached rather than written in the
/// clear. File names carry only the timestamp, so nothing about the device or
/// source is readable without the key.
class LocalCache {
  static const String _cacheDirName = 'synheart_wear';
  static const String _sessionPrefix = 'session_';
  static const String _metaFileName = 'meta.log';

  static Directory? _directoryOverride;

  /// Points the cache at [dir] instead of the documents directory. For tests.
  @visibleForTesting
  static set directoryForTesting(Directory? dir) => _directoryOverride = dir;

  /// Store a session of wearable data
  static Future<void> storeSession(
    WearMetrics data, {
    bool enableEncryption = true,
  }) async {
    final Map<String, Object?> record;
    if (enableEncryption) {
      try {
        record = await EncryptionService.encryptData(data.toJson());
      } catch (e) {
        // Never fall back to plaintext.
        logWarning('Encryption unavailable; session not cached', e);
        return;
      }
    } else {
      record = data.toJson();
    }

    try {
      final cacheDir = await _getCacheDirectory();
      final name = _fileName(data.timestamp);
      final tmp = File('${cacheDir.path}/$name.tmp');
      await tmp.writeAsString(jsonEncode(record), flush: true);
      await tmp.rename('${cacheDir.path}/$name');

      if (enableEncryption) {
        // The meta log names the device and source in plain text.
        final metaFile = File('${cacheDir.path}/$_metaFileName');
        if (await metaFile.exists()) await metaFile.delete();
      } else {
        await _updateMetaLog(name, data);
      }
    } catch (e) {
      throw SynheartWearError('Failed to store session: $e');
    }
  }

  /// Retrieve cached sessions for a date range, newest first.
  ///
  /// Pass [enableEncryption] as configured: when `true`, plaintext records
  /// are deleted instead of returned.
  static Future<List<WearMetrics>> getCachedSessions({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    bool? enableEncryption,
  }) async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (limit != null && limit <= 0) return [];

      final candidates = <(int, File)>[];
      await for (final entity in cacheDir.list()) {
        if (entity is! File) continue;
        final ms = _timestampOf(entity);
        if (ms == null) continue;
        if (startDate != null && ms < startDate.millisecondsSinceEpoch) {
          continue;
        }
        if (endDate != null && ms > endDate.millisecondsSinceEpoch) continue;
        candidates.add((ms, entity));
      }
      candidates.sort((a, b) => b.$1.compareTo(a.$1));

      final sessions = <WearMetrics>[];
      for (final (_, file) in candidates) {
        final metrics = await _read(file, enableEncryption: enableEncryption);
        if (metrics == null) continue;
        sessions.add(metrics);
        if (limit != null && sessions.length >= limit) break;
      }
      return sessions;
    } catch (e) {
      throw SynheartWearError('Failed to retrieve cached sessions: $e');
    }
  }

  /// Get the most recent cached session
  static Future<WearMetrics?> getLatestSession() async {
    final sessions = await getCachedSessions(limit: 1);
    return sessions.isNotEmpty ? sessions.first : null;
  }

  /// Clear cached data older than specified duration
  static Future<void> clearOldData({
    Duration maxAge = const Duration(days: 30),
  }) async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) return;

      final cutoffDate = DateTime.now().subtract(maxAge);
      await for (final entity in cacheDir.list()) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
          }
        } catch (e) {
          // Skip files that can't be processed
          continue;
        }
      }
    } catch (e) {
      throw SynheartWearError('Failed to clear old data: $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, Object?>> getCacheStats({
    bool? encryptionEnabled,
  }) async {
    try {
      final cacheDir = await _getCacheDirectory();
      int totalSessions = 0;
      int totalSize = 0;
      DateTime? oldestSession;

      await for (final entity in cacheDir.list()) {
        if (entity is! File || _timestampOf(entity) == null) continue;
        totalSessions++;
        totalSize += await entity.length();

        final stat = await entity.stat();
        if (oldestSession == null || stat.modified.isBefore(oldestSession)) {
          oldestSession = stat.modified;
        }
      }

      return {
        'total_sessions': totalSessions,
        'cache_size_bytes': totalSize,
        'oldest_session': oldestSession?.toIso8601String(),
        'encryption_enabled': encryptionEnabled ?? false,
      };
    } catch (e) {
      throw SynheartWearError('Failed to get cache stats: $e');
    }
  }

  /// Get cache directory path
  static Future<Directory> _getCacheDirectory() async {
    final Directory cacheDir;
    final override = _directoryOverride;
    if (override != null) {
      cacheDir = override;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      cacheDir = Directory('${appDir.path}/$_cacheDirName');
    }

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    if (_legacyCleanedDir != cacheDir.path) {
      _legacyCleanedDir = cacheDir.path;
      await _removeLegacyFiles(cacheDir);
    }

    return cacheDir;
  }

  static String? _legacyCleanedDir;

  /// Deletes session files from earlier versions. Their names carry the
  /// device id, and their contents are either plaintext or sealed by the
  /// old, unsafe encryption; neither is worth keeping in a cache.
  static Future<void> _removeLegacyFiles(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final legacySession =
            name.startsWith(_sessionPrefix) && !_namePattern.hasMatch(name);
        if (legacySession || name.endsWith('.tmp')) await entity.delete();
      }
    } catch (e) {
      logWarning('Failed to remove old cache files', e);
    }
  }

  /// `session_<epoch ms>_<random>.json`. The random suffix keeps two sessions
  /// with the same timestamp from overwriting each other.
  static String _fileName(DateTime timestamp) {
    final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '$_sessionPrefix${timestamp.millisecondsSinceEpoch}_$suffix.json';
  }

  /// The epoch-ms timestamp in a current file name, or `null` for anything
  /// else (metadata, temp files, names from earlier versions).
  static int? _timestampOf(File file) {
    final name = file.uri.pathSegments.last;
    final match = _namePattern.firstMatch(name);
    return match == null ? null : int.parse(match.group(1)!);
  }

  static final RegExp _namePattern = RegExp(r'^session_(\d+)_[0-9a-f]+\.json$');

  /// Reads one record. Records that can't be trusted or decoded are
  /// deleted: earlier versions' encryption, tampered or foreign-key records,
  /// and plaintext when encryption is on.
  static Future<WearMetrics?> _read(
    File file, {
    required bool? enableEncryption,
  }) async {
    try {
      final record =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;

      final Map<String, Object?> json;
      if (EncryptionService.isEncrypted(record)) {
        json = await EncryptionService.decryptData(record);
      } else if (EncryptionService.isLegacyEncrypted(record) ||
          enableEncryption == true) {
        await file.delete();
        return null;
      } else {
        json = record;
      }
      return WearMetrics.fromJson(json);
    } catch (e) {
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }
  }

  /// Update meta log with session information (unencrypted caches only)
  static Future<void> _updateMetaLog(String sessionId, WearMetrics data) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metaFile = File('${cacheDir.path}/$_metaFileName');

      final metaEntry = {
        'session_id': sessionId,
        'timestamp': data.timestamp.toIso8601String(),
        'device_id': data.deviceId,
        'source': data.source,
        'metrics_count': data.metrics.length,
      };

      final existingContent = await metaFile.exists()
          ? await metaFile.readAsString()
          : '';
      final lines = existingContent
          .split('\n')
          .where((line) => line.isNotEmpty)
          .toList();
      lines.add(jsonEncode(metaEntry));

      await metaFile.writeAsString(lines.join('\n'));
    } catch (e) {
      // Meta log failure shouldn't break the main operation
      logWarning('Failed to update meta log', e);
    }
  }

  /// Store metadata (e.g., connection status, user IDs)
  static Future<void> storeMetadata(Map<String, Object?> metadata) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metadataFile = File('${cacheDir.path}/metadata.json');

      // Read existing metadata
      Map<String, Object?> existing = {};
      if (await metadataFile.exists()) {
        try {
          final content = await metadataFile.readAsString();
          existing = jsonDecode(content) as Map<String, Object?>;
        } catch (e) {
          // If corrupted, start fresh
        }
      }

      // Merge new metadata
      existing.addAll(metadata);
      // Remove null values
      existing.removeWhere((key, value) => value == null);

      await metadataFile.writeAsString(jsonEncode(existing));
    } catch (e) {
      throw SynheartWearError('Failed to store metadata: $e');
    }
  }

  /// Get stored metadata
  static Future<Map<String, Object?>> getMetadata() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final metadataFile = File('${cacheDir.path}/metadata.json');

      if (!await metadataFile.exists()) {
        return {};
      }

      final content = await metadataFile.readAsString();
      return jsonDecode(content) as Map<String, Object?>;
    } catch (e) {
      // If file doesn't exist or is corrupted, return empty map
      return {};
    }
  }
}
