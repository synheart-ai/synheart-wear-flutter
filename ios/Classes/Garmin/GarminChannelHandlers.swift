import Flutter
import Foundation

/// Handler for the `synheart_wear/garmin_sdk/connection_state` event channel.
///
/// The Garmin SDK auto-reconnects paired devices during `initialize(...)` and
/// fires `didConnect` before Flutter has subscribed to this EventChannel —
/// which means the first "connected" event was being silently dropped and the
/// UI stayed on "disconnected" until the watch physically re-paired. Caching
/// the latest state for every known device lets us replay it the moment
/// Flutter attaches, so the UI converges to truth without waiting for the
/// next disconnect/reconnect cycle.
///
/// Pure-Swift: no Garmin SDK symbols are referenced here. This lives in the
/// open-source tree because replay semantics are not licensed.
public class GarminConnectionStateHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    private var lastStateByDevice: [Int: [String: Any]] = [:]
    private var lastStateOrder: [Int] = []
    // Bounded buffer for events without a deviceId (e.g. service-level
    // failures) so a chatty signal can't grow unbounded while unlistened.
    private var anonymousEvents: [[String: Any]] = []
    private let anonymousCap = 16
    private let queue = DispatchQueue(label: "ai.synheart.wear.garmin.connstate")

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        queue.sync {
            self.eventSink = events
            let ordered = lastStateOrder.compactMap { lastStateByDevice[$0] }
            let anon = anonymousEvents
            DispatchQueue.main.async {
                ordered.forEach { events($0) }
                anon.forEach { events($0) }
            }
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        queue.sync { eventSink = nil }
        return nil
    }

    public func sendConnectionState(_ state: String, deviceId: Int?, error: String?) {
        var data: [String: Any] = ["state": state]
        if let deviceId = deviceId {
            data["deviceId"] = deviceId
        }
        if let error = error {
            data["error"] = error
        }
        data["timestamp"] = Int64(Date().timeIntervalSince1970 * 1000)
        queue.sync {
            if let deviceId = deviceId {
                if lastStateByDevice[deviceId] == nil {
                    lastStateOrder.append(deviceId)
                }
                lastStateByDevice[deviceId] = data
            } else {
                anonymousEvents.append(data)
                if anonymousEvents.count > anonymousCap {
                    anonymousEvents.removeFirst(anonymousEvents.count - anonymousCap)
                }
            }
            let sink = eventSink
            DispatchQueue.main.async { sink?(data) }
        }
    }
}

/// Handler for the `synheart_wear/garmin_sdk/scanned_devices` event channel.
/// Emits `List<Map<String, Any>>` to match the Dart-side `data is List` check.
public class GarminScannedDevicesHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    public func sendScannedDevices(_ devices: [[String: Any]]) {
        eventSink?(devices)
    }
}

/// Handler for the `synheart_wear/garmin_sdk/real_time_data` event channel.
public class GarminRealTimeDataHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    public func sendRealTimeData(_ data: [String: Any]) {
        eventSink?(data)
    }
}

/// Handler for the `synheart_wear/garmin_sdk/sync_progress` event channel.
public class GarminSyncProgressHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    public func sendSyncProgress(progress: Double, direction: String, deviceId: Int) {
        eventSink?([
            "progress": progress,
            "direction": direction,
            "deviceId": deviceId
        ])
    }
}
