import Flutter
import Foundation

/// Protocol the companion-repo overlay class conforms to.
///
/// The real implementation lives in `synheart-wear-garmin-companion` and is
/// symlinked into `ios/Classes/Garmin/Impl/GarminSDKBridgeImpl.swift` at build
/// time via `make link-garmin`. That overlay class imports the licensed
/// Garmin Companion SDK; this open-source tree has zero textual reference to
/// any Garmin SDK symbol.
///
/// The overlay class is discovered at runtime via `NSClassFromString` so OSS
/// doesn't even mention `GarminSDKBridgeImpl` by type — the string below is
/// the only coupling.
@objc public protocol GarminSDKBridgeImplProtocol: AnyObject {
    init()
    func configure(
        connectionStateHandler: GarminConnectionStateHandler,
        scannedDevicesHandler: GarminScannedDevicesHandler,
        realTimeDataHandler: GarminRealTimeDataHandler,
        syncProgressHandler: GarminSyncProgressHandler
    )
    func handle(call: FlutterMethodCall, result: @escaping FlutterResult)
}

/// Public entry point for the Garmin method/event channels.
///
/// This class is a thin shell — it registers the Flutter channels, owns the
/// four pure-Swift event-channel handlers, and dispatches method calls to an
/// overlay implementation if one is present at runtime. Without the overlay
/// every method returns `UNAVAILABLE` (matching the Android stub behaviour).
///
/// ZERO Garmin SDK symbols are referenced here. To enable real-time streaming
/// the developer runs `make link-garmin`, which drops
/// `GarminSDKBridgeImpl.swift` into `ios/Classes/Garmin/Impl/` as a symlink
/// into the licensed companion repo (`synheart-wear-garmin-companion`).
public class GarminSDKBridge: NSObject {
    private var methodChannel: FlutterMethodChannel?
    private var connectionStateChannel: FlutterEventChannel?
    private var scannedDevicesChannel: FlutterEventChannel?
    private var realTimeDataChannel: FlutterEventChannel?
    private var syncProgressChannel: FlutterEventChannel?

    private let connectionStateHandler = GarminConnectionStateHandler()
    private let scannedDevicesHandler = GarminScannedDevicesHandler()
    private let realTimeDataHandler = GarminRealTimeDataHandler()
    private let syncProgressHandler = GarminSyncProgressHandler()

    /// Optional impl supplied by the overlay. `nil` in OSS builds; populated
    /// when `GarminSDKBridgeImpl` is present in the compiled target.
    private var impl: GarminSDKBridgeImplProtocol?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = GarminSDKBridge()
        instance.setupChannels(registrar: registrar)
        instance.attachImplIfAvailable()
    }

    private func setupChannels(registrar: FlutterPluginRegistrar) {
        methodChannel = FlutterMethodChannel(
            name: "synheart_wear/garmin_sdk",
            binaryMessenger: registrar.messenger()
        )
        methodChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        connectionStateChannel = FlutterEventChannel(
            name: "synheart_wear/garmin_sdk/connection_state",
            binaryMessenger: registrar.messenger()
        )
        connectionStateChannel?.setStreamHandler(connectionStateHandler)

        scannedDevicesChannel = FlutterEventChannel(
            name: "synheart_wear/garmin_sdk/scanned_devices",
            binaryMessenger: registrar.messenger()
        )
        scannedDevicesChannel?.setStreamHandler(scannedDevicesHandler)

        realTimeDataChannel = FlutterEventChannel(
            name: "synheart_wear/garmin_sdk/real_time_data",
            binaryMessenger: registrar.messenger()
        )
        realTimeDataChannel?.setStreamHandler(realTimeDataHandler)

        syncProgressChannel = FlutterEventChannel(
            name: "synheart_wear/garmin_sdk/sync_progress",
            binaryMessenger: registrar.messenger()
        )
        syncProgressChannel?.setStreamHandler(syncProgressHandler)
    }

    /// Runtime-only lookup: no textual mention of the overlay class name
    /// beyond this single string. If the overlay isn't linked in, every
    /// method call falls through to the `UNAVAILABLE` branch below.
    private func attachImplIfAvailable() {
        guard
            let implClass = NSClassFromString("GarminSDKBridgeImpl") as? NSObject.Type,
            let candidate = implClass.init() as? GarminSDKBridgeImplProtocol
        else {
            return
        }
        candidate.configure(
            connectionStateHandler: connectionStateHandler,
            scannedDevicesHandler: scannedDevicesHandler,
            realTimeDataHandler: realTimeDataHandler,
            syncProgressHandler: syncProgressHandler
        )
        impl = candidate
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let impl = impl {
            impl.handle(call: call, result: result)
            return
        }

        switch call.method {
        case "isAvailable":
            result(false)
        case "isInitialized":
            result(false)
        default:
            result(FlutterError(
                code: "UNAVAILABLE",
                message: "Garmin SDK bridge is not available on iOS — install the companion overlay to enable RTS",
                details: nil
            ))
        }
    }
}
