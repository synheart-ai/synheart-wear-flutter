import Flutter
import Foundation

// Conditionally import Companion SDK if available
#if canImport(Companion)
import Companion
private let isGarminSDKAvailable = true
#else
private let isGarminSDKAvailable = false
#endif

/// Main bridge class for Garmin SDK integration on iOS
/// Note: Actual GarminSDK framework must be linked separately
public class GarminSDKBridge: NSObject {
    private var methodChannel: FlutterMethodChannel?
    private var connectionStateChannel: FlutterEventChannel?
    private var scannedDevicesChannel: FlutterEventChannel?
    private var realTimeDataChannel: FlutterEventChannel?
    private var syncProgressChannel: FlutterEventChannel?

    private var connectionStateHandler: GarminConnectionStateHandler?
    private var scannedDevicesHandler: GarminScannedDevicesHandler?
    private var realTimeDataHandler: GarminRealTimeDataHandler?
    private var syncProgressHandler: GarminSyncProgressHandler?

    private var isSDKInitialized = false
    private var licenseKey: String?

    #if canImport(Companion)
    private var activeDevice: Device?
    private var scannedDevicesCache: [ScannedDevice] = []
    #endif

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = GarminSDKBridge()
        instance.setupChannels(registrar: registrar)
    }

    private func setupChannels(registrar: FlutterPluginRegistrar) {
        // Method channel
        methodChannel = FlutterMethodChannel(
            name: "synheart_wear/garmin_sdk",
            binaryMessenger: registrar.messenger()
        )
        methodChannel?.setMethodCallHandler(handle)

        // Connection state event channel
        connectionStateHandler = GarminConnectionStateHandler()
        connectionStateChannel = FlutterEventChannel(
            name: "synheart_wear/garmin_sdk/connection_state",
            binaryMessenger: registrar.messenger()
        )
        connectionStateChannel?.setStreamHandler(connectionStateHandler)

        // Scanned devices event channel
        scannedDevicesHandler = GarminScannedDevicesHandler()
        scannedDevicesChannel = FlutterEventChannel(
            name: "synheart_wear/garmin_sdk/scanned_devices",
            binaryMessenger: registrar.messenger()
        )
        scannedDevicesChannel?.setStreamHandler(scannedDevicesHandler)

        // Real-time data event channel
        realTimeDataHandler = GarminRealTimeDataHandler()
        realTimeDataChannel = FlutterEventChannel(
            name: "synheart_wear/garmin_sdk/real_time_data",
            binaryMessenger: registrar.messenger()
        )
        realTimeDataChannel?.setStreamHandler(realTimeDataHandler)

        // Sync progress event channel
        syncProgressHandler = GarminSyncProgressHandler()
        syncProgressChannel = FlutterEventChannel(
            name: "synheart_wear/garmin_sdk/sync_progress",
            binaryMessenger: registrar.messenger()
        )
        syncProgressChannel?.setStreamHandler(syncProgressHandler)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            handleIsAvailable(result: result)

        case "initializeSDK":
            handleInitializeSDK(call: call, result: result)

        case "isInitialized":
            result(isSDKInitialized)

        case "startScanning":
            handleStartScanning(call: call, result: result)

        case "stopScanning":
            handleStopScanning(result: result)

        case "pairDevice":
            handlePairDevice(call: call, result: result)

        case "cancelPairing":
            handleCancelPairing(result: result)

        case "forgetDevice":
            handleForgetDevice(call: call, result: result)

        case "getPairedDevices":
            handleGetPairedDevices(result: result)

        case "getConnectionState":
            handleGetConnectionState(call: call, result: result)

        case "requestSync":
            handleRequestSync(call: call, result: result)

        case "getBatteryLevel":
            handleGetBatteryLevel(call: call, result: result)

        case "startStreaming":
            handleStartStreaming(call: call, result: result)

        case "stopStreaming":
            handleStopStreaming(call: call, result: result)

        case "readLoggedHeartRate":
            handleReadLoggedHeartRate(call: call, result: result)

        case "readLoggedStress":
            handleReadLoggedStress(call: call, result: result)

        case "readLoggedRespiration":
            handleReadLoggedRespiration(call: call, result: result)

        case "readWellnessEpochs":
            handleReadWellnessEpochs(call: call, result: result)

        case "readWellnessSummaries":
            handleReadWellnessSummaries(call: call, result: result)

        case "readSleepSessions":
            handleReadSleepSessions(call: call, result: result)

        case "readActivitySummaries":
            handleReadActivitySummaries(call: call, result: result)

        case "scanAccessPoints":
            handleScanAccessPoints(call: call, result: result)

        case "storeAccessPoint":
            handleStoreAccessPoint(call: call, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - SDK Initialization

    private func handleIsAvailable(result: @escaping FlutterResult) {
        result(isGarminSDKAvailable)
    }

    private func handleInitializeSDK(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let licenseKey = args["licenseKey"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "License key is required",
                details: nil
            ))
            return
        }

        self.licenseKey = licenseKey

        #if canImport(Companion)
        Task {
            do {
                let sdkConfiguration = SDKConfiguration(processData: false, persistFITFiles: true)
                let sdkLoggerConfiguration = SDKLoggerConfiguration(mode: .verbose, writeToFile: true, overwriteFile: false)

                try await ConfigurationManager.shared.start(
                    withSDKConfiguration: sdkConfiguration,
                    loggerConfiguration: sdkLoggerConfiguration,
                    delegate: nil
                )
                try ConfigurationManager.shared.set(license: licenseKey)

                // Set up delegates
                DeviceManager.shared.set(scanDelegate: self)
                DeviceManager.shared.add(connectionDelegate: self)
                DeviceManager.shared.add(syncDelegate: self)

                await MainActor.run {
                    self.isSDKInitialized = true
                    result(true)
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "LICENSE_INVALID",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
        #else
        // SDK not available - return success for development
        isSDKInitialized = true
        result(true)
        #endif
    }

    // MARK: - Device Scanning

    private func handleStartScanning(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isSDKInitialized else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "Garmin SDK not initialized",
                details: nil
            ))
            return
        }

        #if canImport(Companion)
        let args = call.arguments as? [String: Any]
        let deviceTypeStrings = args?["deviceTypes"] as? [String]

        // Convert string device types to SDK types
        var deviceTypes: [DeviceType] = [.all]
        if let typeStrings = deviceTypeStrings {
            deviceTypes = typeStrings.compactMap { parseDeviceType($0) }
        }

        scannedDevicesCache.removeAll()

        do {
            try DeviceManager.shared.scan(for: deviceTypes)
            result(nil)
        } catch {
            result(FlutterError(
                code: "SCAN_FAILED",
                message: error.localizedDescription,
                details: nil
            ))
        }
        #else
        result(nil)
        #endif
    }

    private func handleStopScanning(result: @escaping FlutterResult) {
        #if canImport(Companion)
        try? DeviceManager.shared.stopScanning()
        scannedDevicesCache.removeAll()
        #endif
        result(nil)
    }

    // MARK: - Device Pairing

    private func handlePairDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isSDKInitialized else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "Garmin SDK not initialized",
                details: nil
            ))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let identifier = args["identifier"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Device identifier is required",
                details: nil
            ))
            return
        }

        #if canImport(Companion)
        // Find the scanned device with matching identifier
        guard let scannedDevice = scannedDevicesCache.first(where: { $0.identifier.uuidString == identifier }) else {
            result(FlutterError(
                code: "DEVICE_NOT_FOUND",
                message: "Device not found in scanned devices",
                details: nil
            ))
            return
        }

        Task {
            do {
                let device = try await DeviceManager.shared.pair(scannedDevice)
                self.activeDevice = device
                await MainActor.run {
                    result(self.deviceToMap(device))
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "PAIRING_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
        #else
        // Placeholder response for development
        result([
            "unitId": 12345,
            "identifier": identifier,
            "name": "Garmin Device",
            "type": "fitness_tracker",
            "connectionState": "connected",
            "supportsStreaming": true
        ])
        #endif
    }

    private func handleCancelPairing(result: @escaping FlutterResult) {
        #if canImport(Companion)
        // Cancel pairing is handled by the SDK automatically when scan is stopped
        try? DeviceManager.shared.stopScanning()
        #endif
        result(nil)
    }

    private func handleForgetDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let unitId = args["unitId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Unit ID is required",
                details: nil
            ))
            return
        }

        let deleteData = args["deleteData"] as? Bool ?? false

        #if canImport(Companion)
        Task {
            do {
                if let devices = try? DeviceManager.shared.getPairedDevices(),
                   let device = devices.first(where: { $0.unitID == UInt32(unitId) }) {
                    try await DeviceManager.shared.delete(device: device, deleteData: deleteData)
                    if self.activeDevice?.unitID == UInt32(unitId) {
                        self.activeDevice = nil
                    }
                }
                await MainActor.run {
                    result(nil)
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "DELETE_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
        #else
        result(nil)
        #endif
    }

    private func handleGetPairedDevices(result: @escaping FlutterResult) {
        guard isSDKInitialized else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "Garmin SDK not initialized",
                details: nil
            ))
            return
        }

        #if canImport(Companion)
        do {
            let devices = try DeviceManager.shared.getPairedDevices()
            let deviceMaps = devices.map { deviceToMap($0) }
            result(deviceMaps)
        } catch {
            result(FlutterError(
                code: "GET_DEVICES_FAILED",
                message: error.localizedDescription,
                details: nil
            ))
        }
        #else
        result([])
        #endif
    }

    // MARK: - Connection State

    private func handleGetConnectionState(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let unitId = args["unitId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Unit ID is required",
                details: nil
            ))
            return
        }

        #if canImport(Companion)
        if let devices = try? DeviceManager.shared.getPairedDevices(),
           let device = devices.first(where: { $0.unitID == UInt32(unitId) }) {
            result(device.isConnected ? "connected" : "disconnected")
        } else {
            result("disconnected")
        }
        #else
        result("disconnected")
        #endif
    }

    // MARK: - Sync Operations

    private func handleRequestSync(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let unitId = args["unitId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Unit ID is required",
                details: nil
            ))
            return
        }

        #if canImport(Companion)
        Task {
            do {
                if let devices = try? DeviceManager.shared.getPairedDevices(),
                   let device = devices.first(where: { $0.unitID == UInt32(unitId) }) {
                    try await DeviceManager.shared.requestSync(with: device)
                }
                await MainActor.run {
                    result(nil)
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "SYNC_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
        #else
        result(nil)
        #endif
    }

    private func handleGetBatteryLevel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let unitId = args["unitId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Unit ID is required",
                details: nil
            ))
            return
        }

        #if canImport(Companion)
        Task {
            do {
                if let devices = try? DeviceManager.shared.getPairedDevices(),
                   let device = devices.first(where: { $0.unitID == UInt32(unitId) }) {
                    let level = try await device.getBatteryChargeLevel()
                    await MainActor.run {
                        result(level)
                    }
                } else {
                    await MainActor.run {
                        result(nil)
                    }
                }
            } catch {
                await MainActor.run {
                    result(nil)
                }
            }
        }
        #else
        result(nil)
        #endif
    }

    // MARK: - Real-Time Streaming

    private func handleStartStreaming(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isSDKInitialized else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "Garmin SDK not initialized",
                details: nil
            ))
            return
        }

        #if canImport(Companion)
        let args = call.arguments as? [String: Any]
        let dataTypeStrings = args?["dataTypes"] as? [String]

        // Default to all supported real-time types
        var realTimeTypes: RealTimeTypes = [
            .heartRate,
            .stress,
            .heartRateVariability,
            .spo2,
            .respiration,
            .bodyBattery,
            .steps,
            .accelerometer
        ]

        // Parse data types if provided
        if let typeStrings = dataTypeStrings, !typeStrings.isEmpty {
            realTimeTypes = []
            for typeString in typeStrings {
                if let type = parseRealTimeType(typeString) {
                    realTimeTypes.insert(type)
                }
            }
        }

        if let device = activeDevice {
            device.add(realTimeDelegate: self)
            do {
                try device.startListening(for: realTimeTypes)
                result(nil)
            } catch {
                result(FlutterError(
                    code: "STREAMING_FAILED",
                    message: error.localizedDescription,
                    details: nil
                ))
            }
        } else {
            result(FlutterError(
                code: "NO_DEVICE",
                message: "No active device",
                details: nil
            ))
        }
        #else
        result(nil)
        #endif
    }

    private func handleStopStreaming(call: FlutterMethodCall, result: @escaping FlutterResult) {
        #if canImport(Companion)
        if let device = activeDevice {
            device.stopListening(for: [
                .heartRate,
                .stress,
                .heartRateVariability,
                .spo2,
                .respiration,
                .bodyBattery,
                .steps,
                .accelerometer
            ])
            device.remove(realTimeDelegate: self)
        }
        #endif
        result(nil)
    }

    // MARK: - Logged Data Reading

    private func handleReadLoggedHeartRate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Note: The Companion SDK stores logged data in FIT files
        // This would require processing FIT files to extract heart rate data
        result([])
    }

    private func handleReadLoggedStress(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result([])
    }

    private func handleReadLoggedRespiration(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result([])
    }

    // MARK: - Wellness Data

    private func handleReadWellnessEpochs(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result([])
    }

    private func handleReadWellnessSummaries(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result([])
    }

    // MARK: - Sleep Data

    private func handleReadSleepSessions(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result([])
    }

    // MARK: - Activity Data

    private func handleReadActivitySummaries(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result([])
    }

    // MARK: - WiFi Operations

    private func handleScanAccessPoints(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let unitId = args["unitId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Unit ID is required",
                details: nil
            ))
            return
        }

        #if canImport(Companion)
        Task {
            do {
                if let devices = try? DeviceManager.shared.getPairedDevices(),
                   let device = devices.first(where: { $0.unitID == UInt32(unitId) }) {
                    let accessPoints = try await device.scanAccessPoints()
                    let maps = accessPoints.map { ap -> [String: Any] in
                        return [
                            "ssid": ap.ssid,
                            "signalStrength": ap.signalStrength,
                            "isSecured": ap.isSecured
                        ]
                    }
                    await MainActor.run {
                        result(maps)
                    }
                } else {
                    await MainActor.run {
                        result([])
                    }
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "WIFI_SCAN_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
        #else
        result([])
        #endif
    }

    private func handleStoreAccessPoint(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let unitId = args["unitId"] as? Int,
              let ssid = args["ssid"] as? String,
              let password = args["password"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Unit ID, SSID, and password are required",
                details: nil
            ))
            return
        }

        #if canImport(Companion)
        // This would require finding the scanned access point with matching SSID
        // and then storing it on the device
        result(nil)
        #else
        result(nil)
        #endif
    }

    // MARK: - Helper Methods

    #if canImport(Companion)
    private func deviceToMap(_ device: Device) -> [String: Any] {
        var map: [String: Any] = [
            "unitId": Int(device.unitID ?? 0),
            "identifier": device.identifier.uuidString,
            "name": device.name,
            "type": deviceTypeToString(device.type),
            "connectionState": device.isConnected ? "connected" : "disconnected",
            "supportsStreaming": true
        ]

        if let version = device.softwareVersionString as String? {
            map["firmwareVersion"] = version
        }

        return map
    }

    private func scannedDeviceToMap(_ device: ScannedDevice) -> [String: Any] {
        return [
            "identifier": device.identifier.uuidString,
            "name": device.name,
            "type": deviceTypeToString(device.type),
            "rssi": device.rssi,
            "isPaired": false
        ]
    }

    private func deviceTypeToString(_ type: DeviceType) -> String {
        switch type {
        case .all:
            return "unknown"
        case .vivosmart:
            return "fitness_tracker"
        case .vivoactive:
            return "fitness_tracker"
        case .venu:
            return "fitness_tracker"
        case .forerunner:
            return "running_watch"
        case .fenix:
            return "outdoor_watch"
        case .instinct:
            return "outdoor_watch"
        case .edge:
            return "cycling_computer"
        case .descent:
            return "diving_watch"
        case .d2:
            return "aviation_watch"
        case .approach:
            return "golf_watch"
        default:
            return "unknown"
        }
    }

    private func parseDeviceType(_ typeString: String) -> DeviceType? {
        switch typeString.lowercased() {
        case "fitness_tracker", "vivosmart", "vivoactive", "venu":
            return .venu
        case "running_watch", "forerunner":
            return .forerunner
        case "outdoor_watch", "fenix", "instinct":
            return .fenix
        case "cycling_computer", "edge":
            return .edge
        case "all", "unknown":
            return .all
        default:
            return .all
        }
    }

    private func parseRealTimeType(_ typeString: String) -> RealTimeTypes? {
        switch typeString.lowercased() {
        case "heart_rate", "heartrate":
            return .heartRate
        case "stress":
            return .stress
        case "hrv", "heart_rate_variability":
            return .heartRateVariability
        case "spo2":
            return .spo2
        case "respiration":
            return .respiration
        case "body_battery", "bodybattery":
            return .bodyBattery
        case "steps":
            return .steps
        case "accelerometer":
            return .accelerometer
        default:
            return nil
        }
    }
    #endif
}

// MARK: - SDK Delegate Extensions

#if canImport(Companion)
extension GarminSDKBridge: @preconcurrency ScanDelegate {
    public func didScan(device: ScannedDevice) {
        scannedDevicesCache.append(device)
        let deviceMaps = scannedDevicesCache.map { scannedDeviceToMap($0) }
        scannedDevicesHandler?.sendScannedDevices(deviceMaps)
    }

    public func didFail(error: Error) {
        // Handle scan failure
    }
}

extension GarminSDKBridge: @preconcurrency ConnectionDelegate {
    public func didConnect(device: Device) {
        connectionStateHandler?.sendConnectionState(
            "connected",
            deviceId: Int(device.unitID ?? 0),
            error: nil
        )
    }

    public func didDisconnect(device: Device) {
        connectionStateHandler?.sendConnectionState(
            "disconnected",
            deviceId: Int(device.unitID ?? 0),
            error: nil
        )
    }

    public func didFail(device: Device, error: Error) {
        connectionStateHandler?.sendConnectionState(
            "failed",
            deviceId: Int(device.unitID ?? 0),
            error: error.localizedDescription
        )
    }
}

extension GarminSDKBridge: @preconcurrency SyncDelegate {
    public func didStart(uuid: UUID) {
        syncProgressHandler?.sendSyncProgress(progress: 0, direction: "download", deviceId: 0)
    }

    public func progress(uuid: UUID, amount: Double, direction: SyncDirection) {
        let directionString = direction == .download ? "download" : "upload"
        syncProgressHandler?.sendSyncProgress(progress: amount, direction: directionString, deviceId: 0)
    }

    public func didComplete(uuid: UUID, error: Error?) {
        syncProgressHandler?.sendSyncProgress(progress: 1.0, direction: "complete", deviceId: 0)
    }
}

extension GarminSDKBridge: @preconcurrency RealTimeDelegate {
    public func didUpdate(results: RealTimeResult, type: RealTimeTypes, device: Device) {
        var data: [String: Any] = [
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "deviceId": Int(device.unitID ?? 0)
        ]

        if let hr = results.heartRate {
            data["heartRate"] = hr
        }

        if let stress = results.stressLevel {
            data["stress"] = stress
        }

        if let hrv = results.heartRateVariability {
            data["hrv"] = hrv
        }

        if let bbi = results.beatToBeatIntervals, !bbi.isEmpty {
            data["bbiIntervals"] = bbi.map { Double($0) }
        }

        if let spo2 = results.spo2 {
            data["spo2"] = spo2
        }

        if let respiration = results.respirationRate {
            data["respiration"] = respiration
        }

        if let bodyBattery = results.bodyBattery {
            data["bodyBattery"] = bodyBattery
        }

        if let steps = results.steps {
            data["steps"] = steps
        }

        if let accel = results.accelerometerSamples?.last {
            data["accelerometer"] = [
                "x": accel.x,
                "y": accel.y,
                "z": accel.z,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
        }

        realTimeDataHandler?.sendRealTimeData(data)
    }

    public func didError(_ error: Error, device: Device) {
        // Handle streaming error
    }
}
#endif

// MARK: - Event Channel Handlers

/// Handler for connection state events
class GarminConnectionStateHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func sendConnectionState(_ state: String, deviceId: Int?, error: String?) {
        var data: [String: Any] = ["state": state]
        if let deviceId = deviceId {
            data["deviceId"] = deviceId
        }
        if let error = error {
            data["error"] = error
        }
        data["timestamp"] = Int64(Date().timeIntervalSince1970 * 1000)
        eventSink?(data)
    }
}

/// Handler for scanned devices events
class GarminScannedDevicesHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func sendScannedDevices(_ devices: [[String: Any]]) {
        eventSink?(devices)
    }
}

/// Handler for real-time data events
class GarminRealTimeDataHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func sendRealTimeData(_ data: [String: Any]) {
        eventSink?(data)
    }
}

/// Handler for sync progress events
class GarminSyncProgressHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func sendSyncProgress(progress: Double, direction: String, deviceId: Int) {
        eventSink?([
            "progress": progress,
            "direction": direction,
            "deviceId": deviceId
        ])
    }
}
