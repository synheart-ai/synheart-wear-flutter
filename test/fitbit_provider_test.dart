// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synheart_wear/synheart_wear.dart' show FitbitProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FitbitProvider configuration', () {
    test('defaults to Synheart Wear API base URL', () {
      final p = FitbitProvider(loadFromStorage: false);
      expect(p.baseUrl, contains('/wear/v1'));
    });

    test('vendorName matches domain.VendorFitbit on the cloud', () {
      expect(FitbitProvider.vendorName, 'fitbit');
    });

    test('explicit baseUrl overrides default', () {
      final p = FitbitProvider(
        baseUrl: 'https://staging.example.com/wear/v1',
        loadFromStorage: false,
      );
      expect(p.baseUrl, 'https://staging.example.com/wear/v1');
    });

    test('default redirect URI uses synheart://oauth/callback', () {
      final p = FitbitProvider(loadFromStorage: false);
      expect(p.redirectUri, FitbitProvider.defaultRedirectUri);
      expect(p.redirectUri, startsWith('synheart://'));
    });
  });

  group('FitbitProvider storage round-trip', () {
    test(
      'saveConfiguration persists fields and loadConfiguration reads them',
      () async {
        final p = FitbitProvider(loadFromStorage: false);
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
      },
    );

    test('saveUserId then loadUserId round-trips', () async {
      final p = FitbitProvider(loadFromStorage: false);
      await p.saveUserId('user-9999');
      expect(await p.loadUserId(), 'user-9999');
      expect(p.userId, 'user-9999');
    });

    test('clearUserId removes both in-memory and persisted', () async {
      final p = FitbitProvider(loadFromStorage: false);
      await p.saveUserId('user-1');
      await p.clearUserId();
      expect(p.userId, isNull);
      expect(await p.loadUserId(), isNull);
    });
  });

  group('FitbitProvider initiateOAuthConnection', () {
    test('rejects when userId is missing', () async {
      final p = FitbitProvider(loadFromStorage: false);
      expect(() => p.initiateOAuthConnection(), throwsA(isA<StateError>()));
    });
  });

  group('FitbitProvider deep-link callback', () {
    test('saves user_id when callback succeeds', () async {
      final p = FitbitProvider(loadFromStorage: false);
      final uri = Uri.parse(
        'synheart://oauth/callback?vendor=fitbit&status=success&user_id=user-42',
      );
      final result = await p.handleDeepLinkCallback(uri);
      expect(result, 'user-42');
      expect(p.userId, 'user-42');
      expect(await p.loadUserId(), 'user-42');
    });

    test('ignores callbacks for other vendors', () async {
      final p = FitbitProvider(loadFromStorage: false);
      final uri = Uri.parse(
        'synheart://oauth/callback?vendor=oura&status=success&user_id=user-x',
      );
      final result = await p.handleDeepLinkCallback(uri);
      expect(result, isNull);
      expect(p.userId, isNull);
    });

    test('rejects callbacks with non-success status', () async {
      final p = FitbitProvider(loadFromStorage: false);
      final uri = Uri.parse(
        'synheart://oauth/callback?vendor=fitbit&status=cancelled',
      );
      final result = await p.handleDeepLinkCallback(uri);
      expect(result, isNull);
      expect(p.userId, isNull);
    });

    test('rejects callbacks missing user_id', () async {
      final p = FitbitProvider(loadFromStorage: false);
      final uri = Uri.parse(
        'synheart://oauth/callback?vendor=fitbit&status=success',
      );
      final result = await p.handleDeepLinkCallback(uri);
      expect(result, isNull);
    });
  });

  group('FitbitProvider markConnected', () {
    test('persists user id like a deep-link success', () async {
      final p = FitbitProvider(loadFromStorage: false);
      await p.markConnected('user-direct');
      expect(p.userId, 'user-direct');
    });
  });

  group('FitbitProvider data fetchers (no connection)', () {
    test('fetchHrv throws when not connected', () async {
      final p = FitbitProvider(loadFromStorage: false);
      expect(() => p.fetchHrv(), throwsA(isA<StateError>()));
    });

    test('fetchSleep throws when not connected', () async {
      final p = FitbitProvider(loadFromStorage: false);
      expect(() => p.fetchSleep(), throwsA(isA<StateError>()));
    });

    test('fetchActivity throws when not connected', () async {
      final p = FitbitProvider(loadFromStorage: false);
      expect(() => p.fetchActivity(), throwsA(isA<StateError>()));
    });

    test('fetchUserProfile returns null when not connected', () async {
      final p = FitbitProvider(loadFromStorage: false);
      expect(await p.fetchUserProfile(), isNull);
    });
  });

  group('FitbitProvider disconnect (no userId)', () {
    test('is a no-op when nothing is connected', () async {
      final p = FitbitProvider(loadFromStorage: false);
      await p.disconnect();
      expect(p.userId, isNull);
    });
  });
}
