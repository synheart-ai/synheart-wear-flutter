import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/src/adapters/garmin_adapter.dart';
import 'package:synheart_wear/synheart_wear.dart';

void main() {
  group('GarminAdapter', () {
    late GarminAdapter adapter;

    setUp(() {
      adapter = GarminAdapter(
        provider: GarminProvider(loadFromStorage: false),
      );
    });

    test('has correct id', () {
      expect(adapter.id, equals('garmin'));
    });

    test('supportedPermissions contains expected types', () {
      expect(
        adapter.supportedPermissions,
        contains(PermissionType.heartRate),
      );
      expect(
        adapter.supportedPermissions,
        contains(PermissionType.heartRateVariability),
      );
      expect(
        adapter.supportedPermissions,
        contains(PermissionType.steps),
      );
      expect(
        adapter.supportedPermissions,
        contains(PermissionType.calories),
      );
      expect(
        adapter.supportedPermissions,
        contains(PermissionType.distance),
      );
      expect(
        adapter.supportedPermissions,
        contains(PermissionType.stress),
      );
    });

    test('readSnapshot returns null when not connected', () async {
      // No userId set on the provider, so it should return null
      final result = await adapter.readSnapshot();
      expect(result, isNull);
    });

    test('exposes underlying GarminProvider', () {
      expect(adapter.provider, isA<GarminProvider>());
    });
  });
}
