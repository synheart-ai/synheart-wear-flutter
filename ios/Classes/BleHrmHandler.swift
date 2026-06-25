import Flutter
import CoreBluetooth

/// Native iOS handler for BLE Heart Rate Monitor operations.
///
/// Registers MethodChannel (`synheart_wear/ble_hrm/method`) and
/// EventChannel (`synheart_wear/ble_hrm/events`) with the Flutter engine.
public class BleHrmHandler: NSObject {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var discoveredPeripherals: [CBPeripheral] = []

    private var scanResult: FlutterResult?
    private var connectResult: FlutterResult?
    private var permissionResult: FlutterResult?
    private var scanTimer: Timer?
    private var sessionId: String?

    /// Deferred connect request, held when `connect()` is invoked before
    /// `CBCentralManager` has finished initializing. Resolved when the
    /// state machine reaches `.poweredOn` (or fails with a clear error
    /// on `.poweredOff` / `.unauthorized`). Without this, the first
    /// auto-reconnect attempt after a cold launch would always fail
    /// with `DEVICE_NOT_FOUND` — the manager was nil so
    /// `retrievePeripherals` returned nil.
    private struct PendingConnect {
        let deviceId: String
        let sessionId: String?
        let result: FlutterResult
    }
    private var pendingConnect: PendingConnect?

    /// Mid-session reconnect state. When CoreBluetooth drops a live link
    /// (interference, brief out-of-range, iOS reclaiming the radio) we keep a
    /// strong reference to the `CBPeripheral` and ask iOS to reconnect — it
    /// holds that pending connection indefinitely and reattaches silently when
    /// the strap is back in range, so HR samples just pause and resume on the
    /// same event sink. We bound the wait with a give-up timer; only when it
    /// elapses do we surface `DISCONNECTED` to Dart (which then does a full
    /// scan+reconnect, and the stall UI takes over). Previously a single drop
    /// killed the session because nothing re-issued the connect.
    private var reconnectPeripheral: CBPeripheral?
    private var reconnectGiveUpTimer: Timer?
    private var isReconnecting = false
    private let reconnectGiveUpWindow: TimeInterval = 30.0

    // Standard BLE Heart Rate Service UUID
    private let heartRateServiceUUID = CBUUID(string: "180D")
    // Heart Rate Measurement Characteristic UUID
    private let heartRateMeasurementUUID = CBUUID(string: "2A37")

    public static func register(with registrar: FlutterPluginRegistrar) {
        let handler = BleHrmHandler()

        handler.methodChannel = FlutterMethodChannel(
            name: "synheart_wear/ble_hrm/method",
            binaryMessenger: registrar.messenger()
        )
        handler.methodChannel?.setMethodCallHandler(handler.handleMethodCall)

        handler.eventChannel = FlutterEventChannel(
            name: "synheart_wear/ble_hrm/events",
            binaryMessenger: registrar.messenger()
        )
        handler.eventChannel?.setStreamHandler(handler)
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "scan":
            let args = call.arguments as? [String: Any] ?? [:]
            let timeoutMs = args["timeoutMs"] as? Int ?? 5000
            let namePrefix = args["namePrefix"] as? String
            scan(timeoutMs: timeoutMs, namePrefix: namePrefix, result: result)
        case "connect":
            let args = call.arguments as? [String: Any] ?? [:]
            guard let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "DEVICE_NOT_FOUND", message: "deviceId is required", details: nil))
                return
            }
            let sid = args["sessionId"] as? String
            connect(deviceId: deviceId, sessionId: sid, result: result)
        case "disconnect":
            disconnect(result: result)
        case "isConnected":
            result(connectedPeripheral?.state == .connected)
        case "requestPermission":
            requestPermission(result: result)
        case "warmAdapter":
            warmAdapter(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Instantiate CBCentralManager so subsequent BLE consumers (Garmin SDK)
    // don't race the CoreBluetooth stack coming up.
    private func warmAdapter(result: @escaping FlutterResult) {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        result(nil)
    }

    // MARK: - Permission

    private func requestPermission(result: @escaping FlutterResult) {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }

        switch centralManager?.state {
        case .poweredOn:
            result("granted")
        case .unauthorized:
            result("denied")
        default:
            // Still initializing — store callback, resolved in centralManagerDidUpdateState
            permissionResult = result
        }
    }

    // MARK: - Scan

    private func scan(timeoutMs: Int, namePrefix: String?, result: @escaping FlutterResult) {
        // Ensure Bluetooth is on
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }

        guard centralManager?.state == .poweredOn else {
            if centralManager?.state == .unauthorized {
                result(FlutterError(code: "PERMISSION_DENIED", message: "Bluetooth permission denied", details: nil))
            } else if centralManager?.state == .poweredOff {
                result(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is turned off", details: nil))
            } else {
                // Manager might still be initializing — store result and wait
                scanResult = result
                discoveredPeripherals.removeAll()
                return
            }
            return
        }

        discoveredPeripherals.removeAll()
        scanResult = result

        centralManager?.scanForPeripherals(withServices: [heartRateServiceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])

        let timeout = Double(timeoutMs) / 1000.0
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.finishScan(namePrefix: namePrefix)
        }
    }

    private func finishScan(namePrefix: String?) {
        centralManager?.stopScan()

        // Merge: advertising devices + already-connected peripherals with HR service
        var seenIds = Set<UUID>()

        // 1. Devices found during active scan
        for p in discoveredPeripherals {
            seenIds.insert(p.identifier)
        }

        // 2. Peripherals already connected to the system (e.g. Polar H10 paired via another app)
        //    Store them in discoveredPeripherals so connect() can find them later.
        if let connected = centralManager?.retrieveConnectedPeripherals(withServices: [heartRateServiceUUID]) {
            for p in connected {
                if seenIds.insert(p.identifier).inserted {
                    discoveredPeripherals.append(p)
                    if peripheralRSSI[p.identifier] == nil {
                        peripheralRSSI[p.identifier] = -50
                    }
                }
            }
        }

        var allPeripherals = discoveredPeripherals
        if let prefix = namePrefix {
            allPeripherals = allPeripherals.filter { ($0.name ?? "").hasPrefix(prefix) }
        }

        let devices: [[String: Any]] = allPeripherals.map { p in
            return [
                "deviceId": p.identifier.uuidString,
                "name": p.name ?? "",
                "rssi": peripheralRSSI[p.identifier] ?? -70
            ]
        }

        scanResult?(devices)
        scanResult = nil
    }

    // MARK: - Connect

    private func connect(deviceId: String, sessionId: String?, result: @escaping FlutterResult) {
        self.sessionId = sessionId

        guard UUID(uuidString: deviceId) != nil else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Invalid device ID", details: nil))
            return
        }

        // Lazily initialise the central manager — required for the
        // auto-reconnect path the Dart side fires at app startup, where
        // this is the first BLE call and `centralManager` has never
        // been created yet. Mirrors what `scan()` does for the same
        // reason.
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }

        // Manager may still be in `.unknown` / `.resetting` — typical
        // on cold start. Stash the request and let
        // `centralManagerDidUpdateState` finish it once the radio is
        // `.poweredOn`. Without this, the cold-start auto-reconnect
        // always failed with `DEVICE_NOT_FOUND` because
        // `retrievePeripherals` on a not-yet-powered manager returns
        // nothing.
        guard centralManager?.state == .poweredOn else {
            if centralManager?.state == .poweredOff {
                result(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is turned off", details: nil))
                return
            }
            if centralManager?.state == .unauthorized {
                result(FlutterError(code: "PERMISSION_DENIED", message: "Bluetooth permission denied", details: nil))
                return
            }
            // .unknown / .resetting — wait for the next state update.
            pendingConnect = PendingConnect(deviceId: deviceId, sessionId: sessionId, result: result)
            return
        }

        performConnect(deviceId: deviceId, result: result)
    }

    /// Actually look up the peripheral by UUID and request a connection.
    /// Caller must ensure `centralManager` is initialised and powered on.
    private func performConnect(deviceId: String, result: @escaping FlutterResult) {
        guard let uuid = UUID(uuidString: deviceId) else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Invalid device ID", details: nil))
            return
        }

        // Look in discovered peripherals, then known peripherals, then system-connected
        var target = discoveredPeripherals.first(where: { $0.identifier == uuid })
            ?? centralManager?.retrievePeripherals(withIdentifiers: [uuid]).first

        if target == nil {
            // Try retrieving from system-connected peripherals with HR service
            target = centralManager?.retrieveConnectedPeripherals(withServices: [heartRateServiceUUID])
                .first(where: { $0.identifier == uuid })
        }

        guard let peripheral = target else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device not found", details: nil))
            return
        }

        // Keep a strong reference
        if !discoveredPeripherals.contains(where: { $0.identifier == uuid }) {
            discoveredPeripherals.append(peripheral)
        }

        // If already connected, skip connect and go straight to service discovery
        if peripheral.state == .connected {
            connectedPeripheral = peripheral
            peripheral.delegate = self
            peripheral.discoverServices([heartRateServiceUUID])
            result(nil)
            return
        }

        connectResult = result
        centralManager?.connect(peripheral, options: nil)
    }

    // MARK: - Disconnect

    private func disconnect(result: @escaping FlutterResult) {
        // Explicit teardown (session end / user "Try again") cancels any
        // in-flight auto-reconnect — including a pending connect whose
        // peripheral is no longer the live `connectedPeripheral` — so iOS
        // doesn't silently reattach afterwards.
        cancelReconnect(cancelPending: true)
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        result(nil)
    }

    /// Tear down auto-reconnect bookkeeping. When `cancelPending` is true the
    /// pending CoreBluetooth connection is also cancelled (give-up path); on
    /// explicit disconnect the caller cancels the live peripheral itself.
    private func cancelReconnect(cancelPending: Bool) {
        reconnectGiveUpTimer?.invalidate()
        reconnectGiveUpTimer = nil
        isReconnecting = false
        if cancelPending, let p = reconnectPeripheral {
            centralManager?.cancelPeripheralConnection(p)
        }
        reconnectPeripheral = nil
    }

    // MARK: - RSSI tracking

    private var peripheralRSSI: [UUID: Int] = [:]
}

// MARK: - FlutterStreamHandler

extension BleHrmHandler: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

// MARK: - CBCentralManagerDelegate

extension BleHrmHandler: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Resolve pending permission request
            if let permResult = permissionResult {
                permResult("granted")
                permissionResult = nil
            }
            // If we have a pending scan, start it now
            if scanResult != nil {
                discoveredPeripherals.removeAll()
                central.scanForPeripherals(withServices: [heartRateServiceUUID], options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: false
                ])
                scanTimer?.invalidate()
                scanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                    self?.finishScan(namePrefix: nil)
                }
            }
            // If we have a pending connect (cold-start auto-reconnect),
            // finish it now that the radio is ready.
            if let pending = pendingConnect {
                pendingConnect = nil
                self.sessionId = pending.sessionId
                performConnect(deviceId: pending.deviceId, result: pending.result)
            }
        case .poweredOff:
            permissionResult?("denied")
            permissionResult = nil
            scanResult?(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is turned off", details: nil))
            scanResult = nil
            if let pending = pendingConnect {
                pendingConnect = nil
                pending.result(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is turned off", details: nil))
            }
        case .unauthorized:
            permissionResult?("denied")
            permissionResult = nil
            scanResult?(FlutterError(code: "PERMISSION_DENIED", message: "Bluetooth permission denied", details: nil))
            scanResult = nil
            if let pending = pendingConnect {
                pendingConnect = nil
                pending.result(FlutterError(code: "PERMISSION_DENIED", message: "Bluetooth permission denied", details: nil))
            }
        default:
            break
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            peripheralRSSI[peripheral.identifier] = RSSI.intValue
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Successful auto-reconnect: clear the give-up timer. Re-running service
        // discovery below re-subscribes the HR notification, so samples resume
        // on the existing event sink with no Dart-visible error.
        if isReconnecting && peripheral.identifier == reconnectPeripheral?.identifier {
            cancelReconnect(cancelPending: false)
        }
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([heartRateServiceUUID])
        connectResult?(nil)
        connectResult = nil
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // A failed attempt during auto-reconnect isn't terminal — re-issue the
        // pending connect and let the give-up timer decide when to surface it.
        if isReconnecting && peripheral.identifier == reconnectPeripheral?.identifier {
            central.connect(peripheral, options: nil)
            return
        }
        connectResult?(FlutterError(code: "SUBSCRIBE_FAILED", message: error?.localizedDescription ?? "Connection failed", details: nil))
        connectResult = nil
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == connectedPeripheral?.identifier else { return }
        connectedPeripheral = nil

        // Only attempt transparent reconnect inside an active session and with
        // the radio up; otherwise fall through to the terminal notification.
        guard sessionId != nil, central.state == .poweredOn, !isReconnecting else {
            eventSink?(FlutterError(code: "DISCONNECTED", message: "Device disconnected", details: nil))
            return
        }

        isReconnecting = true
        reconnectPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil) // pending connect; reattaches when in range
        reconnectGiveUpTimer?.invalidate()
        reconnectGiveUpTimer = Timer.scheduledTimer(
            withTimeInterval: reconnectGiveUpWindow, repeats: false
        ) { [weak self] _ in
            self?.failReconnect()
        }
    }

    /// Auto-reconnect window elapsed without the strap coming back. Cancel the
    /// pending connect and surface a terminal disconnect so Dart can do a full
    /// scan+reconnect and the stall UI can take over.
    private func failReconnect() {
        guard isReconnecting else { return }
        cancelReconnect(cancelPending: true)
        eventSink?(FlutterError(code: "DISCONNECTED", message: "Device disconnected", details: nil))
    }
}

// MARK: - CBPeripheralDelegate

extension BleHrmHandler: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            eventSink?(FlutterError(code: "SUBSCRIBE_FAILED", message: error!.localizedDescription, details: nil))
            return
        }
        for service in peripheral.services ?? [] {
            if service.uuid == heartRateServiceUUID {
                peripheral.discoverCharacteristics([heartRateMeasurementUUID], for: service)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            eventSink?(FlutterError(code: "SUBSCRIBE_FAILED", message: error!.localizedDescription, details: nil))
            return
        }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == heartRateMeasurementUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == heartRateMeasurementUUID,
              let data = characteristic.value else { return }

        let sample = parseHeartRateMeasurement(data, peripheral: peripheral)
        eventSink?(sample)
    }

    /// Parse the BLE Heart Rate Measurement characteristic value per Bluetooth SIG spec.
    private func parseHeartRateMeasurement(_ data: Data, peripheral: CBPeripheral) -> [String: Any] {
        // A malformed or truncated notification (e.g. BLE corruption or a
        // misbehaving strap) can be shorter than the spec requires. Reading
        // past the end of `Data` traps and crashes the host process, so bail
        // out and report no usable sample when the buffer is too short to hold
        // the flags byte plus at least one BPM byte.
        guard data.count >= 2 else {
            return makeSample(bpm: 0, rrIntervals: [], peripheral: peripheral)
        }

        let flags = data[0]
        let is16Bit = (flags & 0x01) != 0
        let hasRR = (flags & 0x10) != 0

        var offset = 1
        let bpm: Double
        if is16Bit {
            // Need two bytes for a 16-bit BPM; skip the read if truncated.
            guard offset + 1 < data.count else {
                return makeSample(bpm: 0, rrIntervals: [], peripheral: peripheral)
            }
            bpm = Double(UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
            offset += 2
        } else {
            bpm = Double(data[offset])
            offset += 1
        }

        // Skip Energy Expended if present
        let hasEE = (flags & 0x08) != 0
        if hasEE { offset += 2 }

        // Parse RR intervals (1/1024 seconds -> ms)
        var rrIntervals: [Double] = []
        if hasRR {
            while offset + 1 < data.count {
                let rrRaw = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                rrIntervals.append(Double(rrRaw) / 1024.0 * 1000.0)
                offset += 2
            }
        }

        return makeSample(bpm: bpm, rrIntervals: rrIntervals, peripheral: peripheral)
    }

    private func makeSample(bpm: Double, rrIntervals: [Double], peripheral: CBPeripheral) -> [String: Any] {
        return [
            "tsMs": Int(Date().timeIntervalSince1970 * 1000),
            "bpm": bpm,
            "source": "ble_hrm",
            "deviceId": peripheral.identifier.uuidString,
            "deviceName": peripheral.name ?? "",
            "sessionId": sessionId ?? "",
            "rrIntervalsMs": rrIntervals,
        ]
    }
}
