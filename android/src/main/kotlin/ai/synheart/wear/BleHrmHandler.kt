package ai.synheart.wear

import android.bluetooth.*
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.util.UUID

/**
 * Native Android handler for BLE Heart Rate Monitor operations.
 *
 * Registers MethodChannel (`synheart_wear/ble_hrm/method`) and
 * EventChannel (`synheart_wear/ble_hrm/events`) with the Flutter engine.
 */
class BleHrmHandler(private val context: Context) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private val HR_SERVICE_UUID: UUID = UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
        private val HR_MEASUREMENT_UUID: UUID = UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
        private val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        fun registerWith(binding: FlutterPlugin.FlutterPluginBinding) {
            val handler = BleHrmHandler(binding.applicationContext)

            val methodChannel = MethodChannel(binding.binaryMessenger, "synheart_wear/ble_hrm/method")
            methodChannel.setMethodCallHandler(handler)

            val eventChannel = EventChannel(binding.binaryMessenger, "synheart_wear/ble_hrm/events")
            eventChannel.setStreamHandler(handler)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var connectedGatt: BluetoothGatt? = null
    private var sessionId: String? = null
    private var lastDeviceId: String? = null
    private var reconnectRunnable: Runnable? = null
    private var reconnectAttempts = 0
    private val maxReconnectAttempts = 5
    private val reconnectDelayMs = 3000L

    private val bluetoothAdapter: BluetoothAdapter?
        get() = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    // MARK: - MethodChannel

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scan" -> {
                val timeoutMs = call.argument<Int>("timeoutMs") ?: 5000
                val namePrefix = call.argument<String>("namePrefix")
                scan(timeoutMs, namePrefix, result)
            }
            "connect" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId == null) {
                    result.error("DEVICE_NOT_FOUND", "deviceId is required", null)
                    return
                }
                sessionId = call.argument<String>("sessionId")
                connect(deviceId, result)
            }
            "disconnect" -> disconnect(result)
            "isConnected" -> result.success(connectedGatt != null)
            else -> result.notImplemented()
        }
    }

    // MARK: - EventChannel

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // MARK: - Scan

    private fun scan(timeoutMs: Int, namePrefix: String?, result: MethodChannel.Result) {
        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            result.error(
                if (adapter == null) "BLUETOOTH_OFF" else "BLUETOOTH_OFF",
                "Bluetooth is not available or is turned off",
                null
            )
            return
        }

        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            result.error("BLUETOOTH_OFF", "BLE scanner not available", null)
            return
        }

        val devices = mutableListOf<Map<String, Any>>()
        val seenIds = mutableSetOf<String>()

        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, sr: ScanResult) {
                val id = sr.device.address
                if (seenIds.contains(id)) return
                seenIds.add(id)

                val name = sr.device.name ?: sr.scanRecord?.deviceName ?: ""
                if (namePrefix != null && !name.startsWith(namePrefix)) return

                devices.add(
                    mapOf(
                        "deviceId" to id,
                        "name" to name,
                        "rssi" to sr.rssi
                    )
                )
            }

            override fun onScanFailed(errorCode: Int) {
                result.error("PERMISSION_DENIED", "BLE scan failed with error code: $errorCode", null)
            }
        }

        val filters = listOf(
            ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(HR_SERVICE_UUID))
                .build()
        )
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        try {
            scanner.startScan(filters, settings, scanCallback)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Bluetooth permission denied: ${e.message}", null)
            return
        }

        mainHandler.postDelayed({
            try {
                scanner.stopScan(scanCallback)
            } catch (_: SecurityException) {}
            result.success(devices)
        }, timeoutMs.toLong())
    }

    // MARK: - Connect

    private fun connect(deviceId: String, result: MethodChannel.Result) {
        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Bluetooth is not available", null)
            return
        }

        val device: BluetoothDevice
        try {
            device = adapter.getRemoteDevice(deviceId)
        } catch (e: IllegalArgumentException) {
            result.error("DEVICE_NOT_FOUND", "Invalid device address: $deviceId", null)
            return
        }

        val gattCallback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    connectedGatt = gatt
                    reconnectAttempts = 0
                    mainHandler.post { result.success(null) }
                    try {
                        gatt.discoverServices()
                    } catch (_: SecurityException) {}
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    val wasConnected = connectedGatt != null
                    connectedGatt = null
                    try { gatt.close() } catch (_: Exception) {}

                    if (wasConnected && lastDeviceId != null && eventSink != null) {
                        // Auto-reconnect if we were streaming and got disconnected
                        scheduleReconnect()
                    } else if (!wasConnected) {
                        mainHandler.post {
                            result.error("SUBSCRIBE_FAILED", "Connection failed (status=$status)", null)
                        }
                    }
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) return
                val service = gatt.getService(HR_SERVICE_UUID) ?: return
                val characteristic = service.getCharacteristic(HR_MEASUREMENT_UUID) ?: return

                try {
                    gatt.setCharacteristicNotification(characteristic, true)
                    val descriptor = characteristic.getDescriptor(CCCD_UUID)
                    if (descriptor != null) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            gatt.writeDescriptor(descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                        } else {
                            @Suppress("DEPRECATION")
                            descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                            @Suppress("DEPRECATION")
                            gatt.writeDescriptor(descriptor)
                        }
                    }
                } catch (e: SecurityException) {
                    mainHandler.post {
                        eventSink?.error("PERMISSION_DENIED", "Bluetooth permission denied", null)
                    }
                }
            }

            // API 33+ callback (non-deprecated)
            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                if (characteristic.uuid != HR_MEASUREMENT_UUID) return
                val sample = parseHeartRateMeasurement(value, gatt.device)
                mainHandler.post { eventSink?.success(sample) }
            }

            // Pre-API 33 fallback (deprecated but needed for older devices)
            @Deprecated("Deprecated in API 33", ReplaceWith("onCharacteristicChanged(gatt, characteristic, value)"))
            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                if (characteristic.uuid != HR_MEASUREMENT_UUID) return
                @Suppress("DEPRECATION")
                val data = characteristic.value ?: return
                val sample = parseHeartRateMeasurement(data, gatt.device)
                mainHandler.post { eventSink?.success(sample) }
            }
        }

        lastDeviceId = deviceId
        try {
            device.connectGatt(context, false, gattCallback)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Bluetooth permission denied: ${e.message}", null)
        }
    }

    // MARK: - Reconnect

    private fun scheduleReconnect() {
        if (reconnectAttempts >= maxReconnectAttempts) {
            mainHandler.post {
                eventSink?.error("DISCONNECTED", "Device disconnected after $maxReconnectAttempts reconnect attempts", null)
            }
            return
        }

        reconnectAttempts++
        reconnectRunnable?.let { mainHandler.removeCallbacks(it) }
        reconnectRunnable = Runnable {
            val devId = lastDeviceId ?: return@Runnable
            val adapter = bluetoothAdapter ?: return@Runnable
            if (!adapter.isEnabled) return@Runnable

            try {
                val device = adapter.getRemoteDevice(devId)
                device.connectGatt(context, false, object : BluetoothGattCallback() {
                    override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                        if (newState == BluetoothProfile.STATE_CONNECTED) {
                            connectedGatt = gatt
                            reconnectAttempts = 0
                            try { gatt.discoverServices() } catch (_: SecurityException) {}
                        } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                            try { gatt.close() } catch (_: Exception) {}
                            scheduleReconnect()
                        }
                    }

                    override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                        if (status != BluetoothGatt.GATT_SUCCESS) return
                        val service = gatt.getService(HR_SERVICE_UUID) ?: return
                        val characteristic = service.getCharacteristic(HR_MEASUREMENT_UUID) ?: return
                        try {
                            gatt.setCharacteristicNotification(characteristic, true)
                            val descriptor = characteristic.getDescriptor(CCCD_UUID)
                            if (descriptor != null) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    gatt.writeDescriptor(descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                                } else {
                                    @Suppress("DEPRECATION")
                                    descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                    @Suppress("DEPRECATION")
                                    gatt.writeDescriptor(descriptor)
                                }
                            }
                        } catch (_: SecurityException) {}
                    }

                    override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                        if (characteristic.uuid != HR_MEASUREMENT_UUID) return
                        val sample = parseHeartRateMeasurement(value, gatt.device)
                        mainHandler.post { eventSink?.success(sample) }
                    }

                    @Deprecated("Deprecated in API 33")
                    override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                        if (characteristic.uuid != HR_MEASUREMENT_UUID) return
                        @Suppress("DEPRECATION")
                        val data = characteristic.value ?: return
                        val sample = parseHeartRateMeasurement(data, gatt.device)
                        mainHandler.post { eventSink?.success(sample) }
                    }
                })
            } catch (_: SecurityException) {
                scheduleReconnect()
            } catch (_: IllegalArgumentException) {}
        }
        mainHandler.postDelayed(reconnectRunnable!!, reconnectDelayMs)
    }

    // MARK: - Disconnect

    private fun disconnect(result: MethodChannel.Result) {
        reconnectRunnable?.let { mainHandler.removeCallbacks(it) }
        reconnectRunnable = null
        reconnectAttempts = 0
        lastDeviceId = null
        try {
            connectedGatt?.disconnect()
            connectedGatt?.close()
        } catch (_: SecurityException) {}
        connectedGatt = null
        result.success(null)
    }

    // MARK: - Parse HR Measurement

    private fun parseHeartRateMeasurement(data: ByteArray, device: BluetoothDevice): Map<String, Any> {
        val flags = data[0].toInt() and 0xFF
        val is16Bit = (flags and 0x01) != 0
        val hasRR = (flags and 0x10) != 0

        var offset = 1
        val bpm: Double
        if (is16Bit) {
            bpm = ((data[offset].toInt() and 0xFF) or ((data[offset + 1].toInt() and 0xFF) shl 8)).toDouble()
            offset += 2
        } else {
            bpm = (data[offset].toInt() and 0xFF).toDouble()
            offset += 1
        }

        // Skip Energy Expended if present
        val hasEE = (flags and 0x08) != 0
        if (hasEE) offset += 2

        // Parse RR intervals (1/1024 sec -> ms)
        val rrIntervals = mutableListOf<Double>()
        if (hasRR) {
            while (offset + 1 < data.size) {
                val rrRaw = (data[offset].toInt() and 0xFF) or ((data[offset + 1].toInt() and 0xFF) shl 8)
                rrIntervals.add(rrRaw.toDouble() / 1024.0 * 1000.0)
                offset += 2
            }
        }

        val deviceName: String = try {
            device.name ?: ""
        } catch (_: SecurityException) { "" }

        return mapOf(
            "tsMs" to System.currentTimeMillis(),
            "bpm" to bpm,
            "source" to "ble_hrm",
            "deviceId" to device.address,
            "deviceName" to deviceName,
            "sessionId" to (sessionId ?: ""),
            "rrIntervalsMs" to rrIntervals
        )
    }
}
