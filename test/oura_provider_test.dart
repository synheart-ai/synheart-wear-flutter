// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synheart_wear/synheart_wear.dart' show OuraProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OuraProvider configuration', () {
    test('defaults to Synheart Wear API base URL', () {
      final p = OuraProvider(loadFromStorage: false);
      expect(p.baseUrl, contains('/wear/v1'));
    });

    test('vendorName is the wire-name shared with the cloud', () {
      // This must match domain.VendorOura ("oura") on the Synheart Wear API
      // side. Renaming requires a coordinated change.
      expect(OuraProvider.vendorName, 'oura');
    });

    test('explicit baseUrl overrides default', () {
      final p = OuraProvider(
        baseUrl: 'https://staging.example.com/wear/v1',
        loadFromStorage: false,
      );
      expect(p.baseUrl, 'https://staging.example.com/wear/v1');
    });

    test('default redirect URI uses synheart://oauth/callback', () {
      final p = OuraProvider(loadFromStorage: false);
      expect(p.redirectUri, OuraProvider.defaultRedirectUri);
      expect(p.redirectUri, startsWith('synheart://'));
    });
  });

  group('OuraProvider storage round-trip', () {
    test(
      'saveConfiguration persists fields and loadConfiguration reads them',
      () async {
        final p = OuraProvider(loadFromStorage: false);
        await p.saveConfiguration(
          baseUrl: 'https://api.example.com/wear/v1',
          appId: 'app_abc',
          apiKey: 'key_xyz',
          projectId: 'proj_1',
          redirectUri: 'app://cb',
        );
        expect(p.appId, 'app_abc');
        expect(p.apiKey, 'key_xyz');
        expect(p.projectId, 'proj_1');
        expect(p.redirectUri, 'app://cb');

        final config = await p.loadConfiguration();
        expect(config['sdk_app_id'], 'app_abc');
        expect(config['sdk_api_key'], 'key_xyz');
        expect(config['sdk_project_id'], 'proj_1');
        expect(config['sdk_base_url'], 'https://api.example.com/wear/v1');
      },
    );

    test('saveUserId then loadUserId round-trips', () async {
      final p = OuraProvider(loadFromStorage: false);
      await p.saveUserId('user-9999');
      final loaded = await p.loadUserId();
      expect(loaded, 'user-9999');
      expect(p.userId, 'user-9999');
    });

    test('clearUserId removes both in-memory and persisted', () async {
      final p = OuraProvider(loadFromStorage: false);
      await p.saveUserId('user-1');
      await p.clearUserId();
      expect(p.userId, isNull);
      expect(await p.loadUserId(), isNull);
    });
  });

  group('OuraProvider initiateOAuthConnection', () {
    test('rejects when userId is missing', () async {
      final p = OuraProvider(loadFromStorage: false);
      expect(() => p.initiateOAuthConnection(), throwsA(isA<StateError>()));
    });

    // Live HTTP exchange tests would require a mock client; the
    // Synheart Wear API contract (BuildAuthURL + capabilities) is covered
    // server-side. We cover the wiring shape here and rely on
    // integration tests for the full handshake.
  });

  group('OuraProvider deep-link callback', () {
    test('saves user_id when callback succeeds', () async {
      final p = OuraProvider(loadFromStorage: false);
      final uri = Uri.parse(
        'synheart://oauth/callback?vendor=oura&status=success&user_id=user-42',
      );
      final result = await p.handleDeepLinkCallback(uri);
      expect(result, 'user-42');
      expect(p.userId, 'user-42');
      expect(await p.loadUserId(), 'user-42');
    });

    test('ignores callbacks for other vendors', () async {
      final p = OuraProvider(loadFromStorage: false);
      final uri = Uri.parse(
        'synheart://oauth/callback?vendor=whoop&status=success&user_id=user-x',
      );
      final result = await p.handleDeepLinkCallback(uri);
      expect(result, isNull);
      expect(p.userId, isNull);
    });

    test('rejects callbacks with non-success status', () async {
      final p = OuraProvider(loadFromStorage: false);
      final uri = Uri.parse(
        'synheart://oauth/callback?vendor=oura&status=cancelled',
      );
      final result = await p.handleDeepLinkCallback(uri);
      expect(result, isNull);
      expect(p.userId, isNull);
    });

    test('rejects callbacks missing user_id', () async {
      final p = OuraProvider(loadFromStorage: false);
      final uri = Uri.parse(
        'synheart://oauth/callback?vendor=oura&status=success',
      );
      final result = await p.handleDeepLinkCallback(uri);
      expect(result, isNull);
    });
  });

  group('OuraProvider markConnected', () {
    test('persists user id like a deep-link success', () async {
      final p = OuraProvider(loadFromStorage: false);
      await p.markConnected('user-direct');
      expect(p.userId, 'user-direct');
      expect(await p.loadUserId(), 'user-direct');
    });
  });

  group('OuraProvider data fetchers (no connection)', () {
    test('fetchSleep throws when not connected', () async {
      final p = OuraProvider(loadFromStorage: false);
      expect(() => p.fetchSleep(), throwsA(isA<StateError>()));
    });

    test('fetchHrv throws when not connected', () async {
      final p = OuraProvider(loadFromStorage: false);
      expect(() => p.fetchHrv(), throwsA(isA<StateError>()));
    });

    test('fetchActivity throws when not connected', () async {
      final p = OuraProvider(loadFromStorage: false);
      expect(() => p.fetchActivity(), throwsA(isA<StateError>()));
    });

    test('fetchReadiness throws when not connected', () async {
      final p = OuraProvider(loadFromStorage: false);
      expect(() => p.fetchReadiness(), throwsA(isA<StateError>()));
    });

    test('fetchUserProfile returns null when not connected', () async {
      final p = OuraProvider(loadFromStorage: false);
      expect(await p.fetchUserProfile(), isNull);
    });
  });

  group('OuraProvider disconnect (no userId)', () {
    test('is a no-op when nothing is connected', () async {
      final p = OuraProvider(loadFromStorage: false);
      // Must not throw even though no HTTP call would land.
      await p.disconnect();
      expect(p.userId, isNull);
    });
  });
}
