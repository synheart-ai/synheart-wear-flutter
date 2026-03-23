import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/synheart_wear.dart';
import 'package:synheart_wear/src/adapters/wear_adapter.dart';

void main() {
  group('Generic Device Types', () {
    test('ScannedDevice can be constructed', () {
      final device = ScannedDevice(
        identifier: 'AA:BB:CC:DD:EE:FF',
        name: 'My Watch',
        modelName: 'Forerunner 255',
        rssi: -65,
        isPaired: false,
        adapter: DeviceAdapter.garmin,
      );

      expect(device.identifier, equals('AA:BB:CC:DD:EE:FF'));
      expect(device.name, equals('My Watch'));
      expect(device.modelName, equals('Forerunner 255'));
      expect(device.rssi, equals(-65));
      expect(device.isPaired, isFalse);
      expect(device.adapter, equals(DeviceAdapter.garmin));
      expect(device.discoveredAt, isNotNull);
    });

    test('ScannedDevice equality based on identifier', () {
      final device1 = ScannedDevice(
        identifier: 'id1',
        name: 'Device 1',
        adapter: DeviceAdapter.garmin,
      );
      final device2 = ScannedDevice(
        identifier: 'id1',
        name: 'Device 1 Updated',
        adapter: DeviceAdapter.garmin,
      );
      final device3 = ScannedDevice(
        identifier: 'id2',
        name: 'Device 2',
        adapter: DeviceAdapter.garmin,
      );

      expect(device1, equals(device2));
      expect(device1, isNot(equals(device3)));
    });

    test('PairedDevice can be constructed', () {
      final device = PairedDevice(
        deviceId: '123456',
        identifier: 'device-uuid',
        name: 'My Fenix',
        modelName: 'Outdoor Watch',
        connectionState: DeviceConnectionState.connected,
        batteryLevel: 85,
        supportsStreaming: true,
        adapter: DeviceAdapter.garmin,
      );

      expect(device.deviceId, equals('123456'));
      expect(device.identifier, equals('device-uuid'));
      expect(device.name, equals('My Fenix'));
      expect(device.connectionState, equals(DeviceConnectionState.connected));
      expect(device.batteryLevel, equals(85));
      expect(device.supportsStreaming, isTrue);
      expect(device.isConnected, isTrue);
      expect(device.adapter, equals(DeviceAdapter.garmin));
    });

    test('PairedDevice equality based on deviceId', () {
      final device1 = PairedDevice(
        deviceId: '42',
        identifier: 'id1',
        name: 'Device',
        adapter: DeviceAdapter.garmin,
      );
      final device2 = PairedDevice(
        deviceId: '42',
        identifier: 'id1',
        name: 'Device Updated',
        adapter: DeviceAdapter.garmin,
      );
      final device3 = PairedDevice(
        deviceId: '99',
        identifier: 'id2',
        name: 'Other',
        adapter: DeviceAdapter.garmin,
      );

      expect(device1, equals(device2));
      expect(device1, isNot(equals(device3)));
    });

    test('PairedDevice isConnected reflects connectionState', () {
      final connected = PairedDevice(
        deviceId: '1',
        identifier: 'id',
        name: 'Device',
        connectionState: DeviceConnectionState.connected,
        adapter: DeviceAdapter.garmin,
      );
      final disconnected = PairedDevice(
        deviceId: '2',
        identifier: 'id2',
        name: 'Device',
        connectionState: DeviceConnectionState.disconnected,
        adapter: DeviceAdapter.garmin,
      );

      expect(connected.isConnected, isTrue);
      expect(disconnected.isConnected, isFalse);
    });

    test('DeviceConnectionEvent can be constructed', () {
      final event = DeviceConnectionEvent(
        state: DeviceConnectionState.connected,
        deviceId: '123',
      );

      expect(event.state, equals(DeviceConnectionState.connected));
      expect(event.deviceId, equals('123'));
      expect(event.error, isNull);
      expect(event.timestamp, isNotNull);
    });

    test('DeviceConnectionEvent with error', () {
      final event = DeviceConnectionEvent(
        state: DeviceConnectionState.failed,
        deviceId: '456',
        error: 'Connection timeout',
      );

      expect(event.state, equals(DeviceConnectionState.failed));
      expect(event.error, equals('Connection timeout'));
    });

    test('DeviceConnectionState has all expected values', () {
      expect(DeviceConnectionState.values, containsAll([
        DeviceConnectionState.disconnected,
        DeviceConnectionState.connecting,
        DeviceConnectionState.connected,
        DeviceConnectionState.failed,
        DeviceConnectionState.unknown,
      ]));
    });
  });

  group('GarminHealth', () {
    test('can be created with license key', () {
      final garmin = GarminHealth(licenseKey: 'test-key');

      expect(garmin, isNotNull);
      expect(garmin.isInitialized, isFalse);

      garmin.dispose();
    });

    test('adapter getter returns WearAdapter', () {
      final garmin = GarminHealth(licenseKey: 'test-key');

      expect(garmin.adapter, isA<WearAdapter>());

      garmin.dispose();
    });
  });

  group('Public API surface', () {
    test('WearMetrics is accessible from barrel', () {
      final metrics = WearMetrics(
        timestamp: DateTime.now(),
        deviceId: 'garmin_123',
        source: 'garmin_sdk',
        metrics: {'hr': 72},
      );

      expect(metrics.getMetric(MetricType.hr), equals(72));
    });

    test('SynheartWearError is accessible from barrel', () {
      final error = SynheartWearError('test error', code: 'TEST');

      expect(error.message, equals('test error'));
      expect(error.code, equals('TEST'));
    });

    test('SynheartWear accepts GarminHealth parameter', () {
      final garmin = GarminHealth(licenseKey: 'test-key');
      final synheart = SynheartWear(
        config: SynheartWearConfig.withAdapters({DeviceAdapter.garmin}),
        garminHealth: garmin,
      );

      expect(synheart.garminHealth, isNotNull);
      expect(synheart.garminHealth, equals(garmin));

      synheart.dispose();
    });

    test('SynheartWear garminHealth is null when not configured', () {
      final synheart = SynheartWear(
        config: SynheartWearConfig.withAdapters({DeviceAdapter.appleHealthKit}),
      );

      expect(synheart.garminHealth, isNull);

      synheart.dispose();
    });
  });
}
