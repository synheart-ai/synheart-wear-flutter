import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/src/models/garmin_connection_state.dart';
import 'package:synheart_wear/src/models/garmin_device.dart';
import 'package:synheart_wear/src/models/garmin_realtime_data.dart';
import 'package:synheart_wear/src/models/garmin_wellness_data.dart';
import 'package:synheart_wear/src/models/garmin_sleep_data.dart';

void main() {
  group('GarminConnectionState', () {
    test('parseGarminConnectionState handles all valid states', () {
      expect(
        parseGarminConnectionState('connected'),
        equals(GarminConnectionState.connected),
      );
      expect(
        parseGarminConnectionState('connecting'),
        equals(GarminConnectionState.connecting),
      );
      expect(
        parseGarminConnectionState('disconnected'),
        equals(GarminConnectionState.disconnected),
      );
      expect(
        parseGarminConnectionState('failed'),
        equals(GarminConnectionState.failed),
      );
      expect(
        parseGarminConnectionState('not_connected'),
        equals(GarminConnectionState.disconnected),
      );
      expect(
        parseGarminConnectionState('error'),
        equals(GarminConnectionState.failed),
      );
    });

    test('parseGarminConnectionState handles null and unknown', () {
      expect(
        parseGarminConnectionState(null),
        equals(GarminConnectionState.unknown),
      );
      expect(
        parseGarminConnectionState('invalid'),
        equals(GarminConnectionState.unknown),
      );
    });

    test('GarminConnectionState extension methods work correctly', () {
      expect(GarminConnectionState.connected.isConnected, isTrue);
      expect(GarminConnectionState.connecting.isConnecting, isTrue);
      expect(GarminConnectionState.failed.hasFailed, isTrue);
      expect(GarminConnectionState.connected.displayName, equals('Connected'));
    });
  });

  group('GarminConnectionStateEvent', () {
    test('fromMap creates correct event', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final map = {
        'state': 'connected',
        'deviceId': 12345,
        'error': null,
        'timestamp': timestamp,
      };

      final event = GarminConnectionStateEvent.fromMap(map);

      expect(event.state, equals(GarminConnectionState.connected));
      expect(event.deviceId, equals(12345));
      expect(event.error, isNull);
    });

    test('toMap produces correct output', () {
      final event = GarminConnectionStateEvent(
        state: GarminConnectionState.failed,
        deviceId: 99,
        error: 'Connection timeout',
      );

      final map = event.toMap();

      expect(map['state'], equals('failed'));
      expect(map['deviceId'], equals(99));
      expect(map['error'], equals('Connection timeout'));
      expect(map.containsKey('timestamp'), isTrue);
    });

    test('roundtrip serialization works', () {
      final original = GarminConnectionStateEvent(
        state: GarminConnectionState.connected,
        deviceId: 42,
      );

      final map = original.toMap();
      final restored = GarminConnectionStateEvent.fromMap(map);

      expect(restored.state, equals(original.state));
      expect(restored.deviceId, equals(original.deviceId));
    });
  });

  group('GarminDeviceType', () {
    test('parseGarminDeviceType handles various strings', () {
      expect(
        parseGarminDeviceType('fitness_tracker'),
        equals(GarminDeviceType.fitnessTracker),
      );
      expect(
        parseGarminDeviceType('forerunner'),
        equals(GarminDeviceType.runningWatch),
      );
      expect(
        parseGarminDeviceType('fenix'),
        equals(GarminDeviceType.outdoorWatch),
      );
      expect(
        parseGarminDeviceType('edge'),
        equals(GarminDeviceType.cyclingComputer),
      );
      expect(
        parseGarminDeviceType('unknown_device'),
        equals(GarminDeviceType.unknown),
      );
      expect(parseGarminDeviceType(null), equals(GarminDeviceType.unknown));
    });

    test('supportsRealTimeStreaming returns correct values', () {
      expect(GarminDeviceType.fitnessTracker.supportsRealTimeStreaming, isTrue);
      expect(GarminDeviceType.runningWatch.supportsRealTimeStreaming, isTrue);
      expect(GarminDeviceType.outdoorWatch.supportsRealTimeStreaming, isTrue);
      expect(
        GarminDeviceType.cyclingComputer.supportsRealTimeStreaming,
        isFalse,
      );
      expect(GarminDeviceType.golfWatch.supportsRealTimeStreaming, isFalse);
    });

    test('displayName returns human readable strings', () {
      expect(
        GarminDeviceType.fitnessTracker.displayName,
        equals('Fitness Tracker'),
      );
      expect(
        GarminDeviceType.runningWatch.displayName,
        equals('Running Watch'),
      );
    });
  });

  group('GarminScannedDevice', () {
    test('fromMap creates device correctly', () {
      final map = {
        'identifier': 'AA:BB:CC:DD:EE:FF',
        'name': 'Forerunner 255',
        'type': 'running_watch',
        'rssi': -65,
        'isPaired': false,
        'modelName': 'Forerunner 255',
        'firmwareVersion': '1.2.3',
      };

      final device = GarminScannedDevice.fromMap(map);

      expect(device.identifier, equals('AA:BB:CC:DD:EE:FF'));
      expect(device.name, equals('Forerunner 255'));
      expect(device.type, equals(GarminDeviceType.runningWatch));
      expect(device.rssi, equals(-65));
      expect(device.isPaired, isFalse);
    });

    test('toMap produces correct output', () {
      final device = GarminScannedDevice(
        identifier: 'test-id',
        name: 'Test Device',
        type: GarminDeviceType.fitnessTracker,
        rssi: -70,
      );

      final map = device.toMap();

      expect(map['identifier'], equals('test-id'));
      expect(map['name'], equals('Test Device'));
      expect(map['type'], equals('fitnessTracker'));
      expect(map['rssi'], equals(-70));
    });

    test('equality works based on identifier', () {
      final device1 = GarminScannedDevice(identifier: 'id1', name: 'Device 1');
      final device2 = GarminScannedDevice(
        identifier: 'id1',
        name: 'Device 1 Updated',
      );
      final device3 = GarminScannedDevice(identifier: 'id2', name: 'Device 2');

      expect(device1, equals(device2));
      expect(device1, isNot(equals(device3)));
    });

    test('roundtrip serialization works', () {
      final original = GarminScannedDevice(
        identifier: 'test-uuid',
        name: 'Garmin Venu',
        type: GarminDeviceType.fitnessTracker,
        rssi: -55,
        isPaired: true,
        modelName: 'Venu 2',
      );

      final map = original.toMap();
      final restored = GarminScannedDevice.fromMap(map);

      expect(restored.identifier, equals(original.identifier));
      expect(restored.name, equals(original.name));
      expect(restored.type, equals(original.type));
      expect(restored.rssi, equals(original.rssi));
      expect(restored.isPaired, equals(original.isPaired));
    });
  });

  group('GarminDevice', () {
    test('fromMap creates device correctly', () {
      final map = {
        'unitId': 123456,
        'identifier': 'device-uuid',
        'name': 'My Fenix',
        'type': 'outdoor_watch',
        'connectionState': 'connected',
        'batteryLevel': 85,
        'supportsStreaming': true,
      };

      final device = GarminDevice.fromMap(map);

      expect(device.unitId, equals(123456));
      expect(device.identifier, equals('device-uuid'));
      expect(device.name, equals('My Fenix'));
      expect(device.type, equals(GarminDeviceType.outdoorWatch));
      expect(device.connectionState, equals(GarminConnectionState.connected));
      expect(device.batteryLevel, equals(85));
      expect(device.supportsStreaming, isTrue);
      expect(device.isConnected, isTrue);
    });

    test('toMap produces correct output', () {
      final device = GarminDevice(
        unitId: 999,
        identifier: 'uuid-123',
        name: 'Test Watch',
        type: GarminDeviceType.runningWatch,
        connectionState: GarminConnectionState.disconnected,
        batteryLevel: 50,
      );

      final map = device.toMap();

      expect(map['unitId'], equals(999));
      expect(map['identifier'], equals('uuid-123'));
      expect(map['connectionState'], equals('disconnected'));
      expect(map['batteryLevel'], equals(50));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = GarminDevice(
        unitId: 1,
        identifier: 'id',
        name: 'Original',
        connectionState: GarminConnectionState.disconnected,
      );

      final updated = original.copyWith(
        connectionState: GarminConnectionState.connected,
        batteryLevel: 100,
      );

      expect(updated.unitId, equals(original.unitId));
      expect(updated.connectionState, equals(GarminConnectionState.connected));
      expect(updated.batteryLevel, equals(100));
      expect(
        original.connectionState,
        equals(GarminConnectionState.disconnected),
      );
    });

    test('roundtrip serialization works', () {
      final lastSync = DateTime.now();
      final original = GarminDevice(
        unitId: 42,
        identifier: 'test-id',
        name: 'Forerunner 965',
        type: GarminDeviceType.runningWatch,
        modelName: 'Forerunner 965',
        firmwareVersion: '2.0.1',
        connectionState: GarminConnectionState.connected,
        batteryLevel: 75,
        lastSyncTime: lastSync,
        supportsStreaming: true,
      );

      final map = original.toMap();
      final restored = GarminDevice.fromMap(map);

      expect(restored.unitId, equals(original.unitId));
      expect(restored.identifier, equals(original.identifier));
      expect(restored.name, equals(original.name));
      expect(restored.type, equals(original.type));
      expect(restored.modelName, equals(original.modelName));
      expect(restored.connectionState, equals(original.connectionState));
      expect(restored.batteryLevel, equals(original.batteryLevel));
      expect(restored.supportsStreaming, equals(original.supportsStreaming));
    });
  });

  group('GarminRealTimeData', () {
    test('fromMap creates data correctly', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final map = {
        'timestamp': timestamp,
        'deviceId': 123,
        'heartRate': 72,
        'stress': 45,
        'hrv': 55,
        'steps': 5000,
        'spo2': 98,
        'respiration': 16,
      };

      final data = GarminRealTimeData.fromMap(map);

      expect(data.deviceId, equals(123));
      expect(data.heartRate, equals(72));
      expect(data.stress, equals(45));
      expect(data.hrv, equals(55));
      expect(data.steps, equals(5000));
      expect(data.spo2, equals(98));
      expect(data.respiration, equals(16));
    });

    test('fromMap handles BBI intervals', () {
      final map = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'heartRate': 75,
        'bbiIntervals': [800.5, 810.2, 795.8, 805.1],
      };

      final data = GarminRealTimeData.fromMap(map);

      expect(data.bbiIntervals, isNotNull);
      expect(data.bbiIntervals!.length, equals(4));
      expect(data.bbiIntervals![0], closeTo(800.5, 0.01));
    });

    test('fromMap handles accelerometer data', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final map = {
        'timestamp': timestamp,
        'accelerometer': {
          'x': 0.5,
          'y': -0.3,
          'z': 9.8,
          'timestamp': timestamp,
        },
      };

      final data = GarminRealTimeData.fromMap(map);

      expect(data.accelerometer, isNotNull);
      expect(data.accelerometer!.x, closeTo(0.5, 0.01));
      expect(data.accelerometer!.y, closeTo(-0.3, 0.01));
      expect(data.accelerometer!.z, closeTo(9.8, 0.01));
    });

    test('toMap produces correct output', () {
      final data = GarminRealTimeData(
        timestamp: DateTime.now(),
        heartRate: 80,
        stress: 30,
        steps: 1000,
      );

      final map = data.toMap();

      expect(map['heartRate'], equals(80));
      expect(map['stress'], equals(30));
      expect(map['steps'], equals(1000));
      expect(map.containsKey('spo2'), isFalse); // null values not included
    });

    test('hasValidData returns correct result', () {
      final dataWithValues = GarminRealTimeData(
        timestamp: DateTime.now(),
        heartRate: 75,
      );
      expect(dataWithValues.hasValidData, isTrue);

      final dataEmpty = GarminRealTimeData(timestamp: DateTime.now());
      expect(dataEmpty.hasValidData, isFalse);
    });

    test('roundtrip serialization works', () {
      final original = GarminRealTimeData(
        timestamp: DateTime.now(),
        deviceId: 5,
        heartRate: 68,
        stress: 25,
        hrv: 60,
        bbiIntervals: [850.0, 860.0, 840.0],
        steps: 3500,
        spo2: 99,
        respiration: 14,
        bodyBattery: 80,
      );

      final map = original.toMap();
      final restored = GarminRealTimeData.fromMap(map);

      expect(restored.heartRate, equals(original.heartRate));
      expect(restored.stress, equals(original.stress));
      expect(restored.hrv, equals(original.hrv));
      expect(
        restored.bbiIntervals!.length,
        equals(original.bbiIntervals!.length),
      );
      expect(restored.steps, equals(original.steps));
      expect(restored.spo2, equals(original.spo2));
    });
  });

  group('GarminAccelerometerData', () {
    test('fromMap creates data correctly', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final map = {'x': 1.5, 'y': -2.3, 'z': 9.81, 'timestamp': timestamp};

      final data = GarminAccelerometerData.fromMap(map);

      expect(data.x, closeTo(1.5, 0.01));
      expect(data.y, closeTo(-2.3, 0.01));
      expect(data.z, closeTo(9.81, 0.01));
    });

    test('magnitude calculates correctly', () {
      final data = GarminAccelerometerData(
        x: 3.0,
        y: 4.0,
        z: 0.0,
        timestamp: DateTime.now(),
      );

      // magnitude = sqrt(3^2 + 4^2 + 0^2) = sqrt(9 + 16) = sqrt(25) = 5
      expect(data.magnitude, equals(5.0));
    });

    test('roundtrip serialization works', () {
      final original = GarminAccelerometerData(
        x: 0.1,
        y: 0.2,
        z: 9.8,
        timestamp: DateTime.now(),
      );

      final map = original.toMap();
      final restored = GarminAccelerometerData.fromMap(map);

      expect(restored.x, closeTo(original.x, 0.001));
      expect(restored.y, closeTo(original.y, 0.001));
      expect(restored.z, closeTo(original.z, 0.001));
    });
  });

  group('GarminWellnessEpoch', () {
    test('fromMap creates epoch correctly', () {
      final startTime = DateTime.now().subtract(const Duration(minutes: 15));
      final endTime = DateTime.now();

      final map = {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'averageHeartRate': 72,
        'steps': 500,
        'distance': 450.5,
        'activeCalories': 35.2,
        'activityLevel': 'moderate',
      };

      final epoch = GarminWellnessEpoch.fromMap(map);

      expect(epoch.averageHeartRate, equals(72));
      expect(epoch.steps, equals(500));
      expect(epoch.distance, closeTo(450.5, 0.01));
      expect(epoch.activeCalories, closeTo(35.2, 0.01));
      expect(epoch.activityLevel, equals(GarminActivityLevel.moderate));
    });

    test('duration calculates correctly', () {
      final startTime = DateTime.now().subtract(const Duration(minutes: 15));
      final endTime = DateTime.now();

      final epoch = GarminWellnessEpoch(startTime: startTime, endTime: endTime);

      expect(epoch.duration.inMinutes, equals(15));
    });

    test('roundtrip serialization works', () {
      final original = GarminWellnessEpoch(
        startTime: DateTime.now().subtract(const Duration(minutes: 15)),
        endTime: DateTime.now(),
        deviceId: 1,
        averageHeartRate: 75,
        minHeartRate: 60,
        maxHeartRate: 90,
        steps: 1000,
        distance: 800.0,
        activeCalories: 50.0,
        activityLevel: GarminActivityLevel.light,
      );

      final map = original.toMap();
      final restored = GarminWellnessEpoch.fromMap(map);

      expect(restored.averageHeartRate, equals(original.averageHeartRate));
      expect(restored.steps, equals(original.steps));
      expect(restored.distance, closeTo(original.distance!, 0.01));
      expect(restored.activityLevel, equals(original.activityLevel));
    });
  });

  group('GarminWellnessSummary', () {
    test('fromMap creates summary correctly', () {
      final date = DateTime.now();

      final map = {
        'date': date.millisecondsSinceEpoch,
        'totalSteps': 8500,
        'stepGoal': 10000,
        'totalDistance': 6500.5,
        'activeCalories': 350.0,
        'restingHeartRate': 58,
        'averageStress': 30,
        'intensityMinutes': 45,
        'floorsClimbed': 8,
      };

      final summary = GarminWellnessSummary.fromMap(map);

      expect(summary.totalSteps, equals(8500));
      expect(summary.stepGoal, equals(10000));
      expect(summary.totalDistance, closeTo(6500.5, 0.01));
      expect(summary.restingHeartRate, equals(58));
    });

    test('stepGoalPercentage calculates correctly', () {
      final summary = GarminWellnessSummary(
        date: DateTime.now(),
        totalSteps: 7500,
        stepGoal: 10000,
      );

      expect(summary.stepGoalPercentage, closeTo(75.0, 0.01));
    });

    test('stepGoalPercentage handles null values', () {
      final summary = GarminWellnessSummary(
        date: DateTime.now(),
        totalSteps: null,
        stepGoal: 10000,
      );

      expect(summary.stepGoalPercentage, isNull);
    });

    test('roundtrip serialization works', () {
      final original = GarminWellnessSummary(
        date: DateTime.now(),
        totalSteps: 12000,
        stepGoal: 10000,
        totalDistance: 9000.0,
        activeCalories: 500.0,
        restingHeartRate: 55,
        averageStress: 25,
        intensityMinutes: 60,
        moderateIntensityMinutes: 40,
        vigorousIntensityMinutes: 20,
      );

      final map = original.toMap();
      final restored = GarminWellnessSummary.fromMap(map);

      expect(restored.totalSteps, equals(original.totalSteps));
      expect(restored.stepGoal, equals(original.stepGoal));
      expect(restored.totalDistance, closeTo(original.totalDistance!, 0.01));
      expect(restored.intensityMinutes, equals(original.intensityMinutes));
    });
  });

  group('GarminSleepSession', () {
    test('fromMap creates session correctly', () {
      final startTime = DateTime.now().subtract(const Duration(hours: 8));
      final endTime = DateTime.now();

      final map = {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'totalSleepSeconds': 25200, // 7 hours
        'deepSleepSeconds': 5400, // 1.5 hours
        'lightSleepSeconds': 14400, // 4 hours
        'remSleepSeconds': 5400, // 1.5 hours
        'sleepScore': 82,
        'quality': 'good',
      };

      final session = GarminSleepSession.fromMap(map);

      expect(session.totalSleepSeconds, equals(25200));
      expect(session.deepSleepSeconds, equals(5400));
      expect(session.sleepScore, equals(82));
      expect(session.quality, equals(GarminSleepQuality.good));
    });

    test('fromMap handles sleep stages', () {
      final startTime = DateTime.now().subtract(const Duration(hours: 8));
      final midTime = DateTime.now().subtract(const Duration(hours: 4));
      final endTime = DateTime.now();

      final map = {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'stages': [
          {
            'startTime': startTime.millisecondsSinceEpoch,
            'endTime': midTime.millisecondsSinceEpoch,
            'stage': 'deep',
          },
          {
            'startTime': midTime.millisecondsSinceEpoch,
            'endTime': endTime.millisecondsSinceEpoch,
            'stage': 'light',
          },
        ],
      };

      final session = GarminSleepSession.fromMap(map);

      expect(session.stages, isNotNull);
      expect(session.stages!.length, equals(2));
      expect(session.stages![0].stage, equals(GarminSleepStageType.deep));
      expect(session.stages![1].stage, equals(GarminSleepStageType.light));
    });

    test('sleepEfficiency calculates correctly', () {
      final startTime = DateTime.now().subtract(const Duration(hours: 8));
      final endTime = DateTime.now();

      final session = GarminSleepSession(
        startTime: startTime,
        endTime: endTime,
        totalSleepSeconds: 25200, // 7 hours = 25200 seconds
      );

      // 7 hours of sleep in 8 hours = 87.5%
      expect(session.sleepEfficiency, closeTo(87.5, 0.5));
    });

    test('deepSleepPercentage calculates correctly', () {
      final session = GarminSleepSession(
        startTime: DateTime.now().subtract(const Duration(hours: 8)),
        endTime: DateTime.now(),
        totalSleepSeconds: 25200,
        deepSleepSeconds: 5040, // 20% of total
      );

      expect(session.deepSleepPercentage, closeTo(20.0, 0.1));
    });

    test('roundtrip serialization works', () {
      final original = GarminSleepSession(
        startTime: DateTime.now().subtract(const Duration(hours: 8)),
        endTime: DateTime.now(),
        deviceId: 1,
        totalSleepSeconds: 25200,
        deepSleepSeconds: 5400,
        lightSleepSeconds: 14400,
        remSleepSeconds: 5400,
        sleepScore: 85,
        averageSpo2: 97,
        averageHrv: 45,
        restingHeartRate: 52,
        quality: GarminSleepQuality.excellent,
      );

      final map = original.toMap();
      final restored = GarminSleepSession.fromMap(map);

      expect(restored.totalSleepSeconds, equals(original.totalSleepSeconds));
      expect(restored.deepSleepSeconds, equals(original.deepSleepSeconds));
      expect(restored.sleepScore, equals(original.sleepScore));
      expect(restored.quality, equals(original.quality));
    });
  });

  group('GarminSleepStage', () {
    test('fromMap creates stage correctly', () {
      final startTime = DateTime.now().subtract(const Duration(hours: 2));
      final endTime = DateTime.now();

      final map = {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'stage': 'rem',
      };

      final stage = GarminSleepStage.fromMap(map);

      expect(stage.stage, equals(GarminSleepStageType.rem));
      expect(stage.duration.inHours, equals(2));
    });

    test('parseSleepStageType handles variants', () {
      final map1 = {'startTime': 0, 'endTime': 1000, 'stage': 'n3'};
      expect(
        GarminSleepStage.fromMap(map1).stage,
        equals(GarminSleepStageType.deep),
      );

      final map2 = {'startTime': 0, 'endTime': 1000, 'stage': 'wake'};
      expect(
        GarminSleepStage.fromMap(map2).stage,
        equals(GarminSleepStageType.awake),
      );
    });
  });

  group('GarminSleepQuality', () {
    test('displayName returns correct strings', () {
      expect(GarminSleepQuality.poor.displayName, equals('Poor'));
      expect(GarminSleepQuality.fair.displayName, equals('Fair'));
      expect(GarminSleepQuality.good.displayName, equals('Good'));
      expect(GarminSleepQuality.excellent.displayName, equals('Excellent'));
    });
  });

  group('GarminActivityLevel', () {
    test('parsing handles various inputs', () {
      final map1 = {
        'startTime': 0,
        'endTime': 1000,
        'activityLevel': 'sedentary',
      };
      expect(
        GarminWellnessEpoch.fromMap(map1).activityLevel,
        equals(GarminActivityLevel.sedentary),
      );

      final map2 = {
        'startTime': 0,
        'endTime': 1000,
        'activityLevel': 'highly_active',
      };
      expect(
        GarminWellnessEpoch.fromMap(map2).activityLevel,
        equals(GarminActivityLevel.vigorous),
      );
    });
  });
}
