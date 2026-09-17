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
import java.util.concurrent.atomic.AtomicBoolean

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
        // Measurement-data service of Polar chest straps (accelerometer, ECG).
        private val PMD_SERVICE_UUID: UUID = UUID.fromString("fb005c80-02e7-f387-1cad-8acd2d8df0c8")
        private val PMD_CONTROL_UUID: UUID = UUID.fromString("fb005c81-02e7-f387-1cad-8acd2d8df0c8")
        private val PMD_DATA_UUID: UUID = UUID.fromString("fb005c82-02e7-f387-1cad-8acd2d8df0c8")

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
    private var motionEnabled = false
    private var motionRateHz = 50
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
                motionEnabled = call.argument<Boolean>("enableMotion") ?: false
                motionRateHz = call.argument<Int>("motionSampleRateHz") ?: 50
                connect(deviceId, result)
            }
            "disconnect" -> disconnect(result)
            "isConnected" -> result.success(connectedGatt != null)
            "getBondedHrDevices" -> getBondedHrDevices(result)
            "warmAdapter" -> {
                // Touching the adapter forces the BLUETOOTH_SERVICE binder up so
                // the Garmin SDK doesn't race a cold stack on first use.
                bluetoothAdapter
                result.success(null)
            }
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

    // MARK: - Bonded Devices

    private fun getBondedHrDevices(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Bluetooth is not available or off", null)
            return
        }
        try {
            val bonded = adapter.bondedDevices ?: emptySet()
            val hrDevices = bonded
                .filter { device ->
                    val uuids = device.uuids?.map { it.uuid } ?: emptyList()
                    uuids.contains(HR_SERVICE_UUID) ||
                    device.name?.contains("Polar", ignoreCase = true) == true ||
                    device.name?.contains("Garmin", ignoreCase = true) == true ||
                    device.name?.contains("Wahoo", ignoreCase = true) == true ||
                    device.name?.contains("HRM", ignoreCase = true) == true ||
                    device.name?.contains("WHOOP", ignoreCase = true) == true
                }
                .map { device ->
                    mapOf(
                        "deviceId" to device.address,
                        "name" to (device.name ?: "Unknown"),
                        "rssi" to 0
                    )
                }
            result.success(hrDevices)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Bluetooth permission denied: ${e.message}", null)
        }
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

        // Flutter's MethodChannel.Result can only be replied to ONCE.
        // The timeout below completes the scan with success, while
        // onScanFailed completes it with an error. Async scan-registration
        // failures (e.g. SCAN_FAILED_APPLICATION_REGISTRATION_FAILED) arrive
        // after startScan() returns, so without a guard both paths can fire and
        // crash the process with IllegalStateException: Reply already submitted.
        val resultSubmitted = AtomicBoolean(false)
        // Set once the timeout is scheduled so onScanFailed can cancel it.
        var timeoutRunnable: Runnable? = null

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
                if (!resultSubmitted.compareAndSet(false, true)) return
                timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
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

        val completeRunnable = Runnable {
            if (!resultSubmitted.compareAndSet(false, true)) return@Runnable
            try {
                scanner.stopScan(scanCallback)
            } catch (_: SecurityException) {}
            result.success(devices)
        }
        timeoutRunnable = completeRunnable
        mainHandler.postDelayed(completeRunnable, timeoutMs.toLong())
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
            // Flutter's MethodChannel.Result can only be replied to ONCE.
            // onConnectionStateChange fires repeatedly across a device's
            // lifetime (every subsequent disconnect, status update after
            // the initial connect was already acknowledged), so guard the
            // reply — secondary callbacks would otherwise crash the process
            // with java.lang.IllegalStateException: Reply already submitted.
            private var resultSubmitted = false
            private fun replyOnce(action: (MethodChannel.Result) -> Unit) {
                if (resultSubmitted) return
                resultSubmitted = true
                mainHandler.post { action(result) }
            }

            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    connectedGatt = gatt
                    reconnectAttempts = 0
                    // Hold the process up while streaming so backgrounding the
                    // app doesn't kill the GATT connection.
                    BleStreamingForegroundController.start(context)
                    replyOnce { it.success(null) }
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
                        replyOnce {
                            it.error("SUBSCRIBE_FAILED", "Connection failed (status=$status)", null)
                        }
                    }
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) return
                val service = gatt.getService(HR_SERVICE_UUID) ?: return
                val characteristic = service.getCharacteristic(HR_MEASUREMENT_UUID) ?: return

                try {
                    requestLowLatency(gatt)
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
            override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) motionOnDescriptorWrite(gatt, descriptor)
            }

            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                if (characteristic.uuid != HR_MEASUREMENT_UUID) {
                    motionOnCharacteristicChanged(characteristic.uuid, value)
                    return
                }
                val sample = parseHeartRateMeasurement(value, gatt.device)
                mainHandler.post { eventSink?.success(sample) }
            }

            // Pre-API 33 fallback (deprecated but needed for older devices)
            @Deprecated("Deprecated in API 33", ReplaceWith("onCharacteristicChanged(gatt, characteristic, value)"))
            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                @Suppress("DEPRECATION")
                val data = characteristic.value ?: return
                if (characteristic.uuid != HR_MEASUREMENT_UUID) {
                    motionOnCharacteristicChanged(characteristic.uuid, data)
                    return
                }
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

    // MARK: - Motion (measurement-data service)

    // The strap's accelerometer lives on a vendor service beside the standard
    // heart-rate service. GATT operations must be serialised, so the set-up
    // runs as a chain of descriptor writes: once the heart-rate subscription
    // is acknowledged, enable indications on the control point, then
    // notifications on the data characteristic, then write the start command.
    private fun motionOnDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor) {
        if (!motionEnabled) return
        val svc = gatt.getService(PMD_SERVICE_UUID) ?: return
        when (descriptor.characteristic.uuid) {
            HR_MEASUREMENT_UUID -> {
                val control = svc.getCharacteristic(PMD_CONTROL_UUID) ?: return
                enableCccd(gatt, control, BluetoothGattDescriptor.ENABLE_INDICATION_VALUE)
            }
            PMD_CONTROL_UUID -> {
                val data = svc.getCharacteristic(PMD_DATA_UUID) ?: return
                enableCccd(gatt, data, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            }
            PMD_DATA_UUID -> {
                val control = svc.getCharacteristic(PMD_CONTROL_UUID) ?: return
                writeCharacteristic(gatt, control, startAccelCommand(motionRateHz))
            }
        }
    }

    private fun motionOnCharacteristicChanged(uuid: UUID, value: ByteArray) {
        val type = when (uuid) {
            PMD_DATA_UUID -> "pmd_data"
            PMD_CONTROL_UUID -> "pmd_control"
            else -> return
        }
        val event = mapOf(
            "type" to type,
            "bytes" to value,
            "arrivalMs" to System.currentTimeMillis()
        )
        mainHandler.post { eventSink?.success(event) }
    }

    private fun enableCccd(gatt: BluetoothGatt, ch: BluetoothGattCharacteristic, value: ByteArray) {
        try {
            gatt.setCharacteristicNotification(ch, true)
            val descriptor = ch.getDescriptor(CCCD_UUID) ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeDescriptor(descriptor, value)
            } else {
                @Suppress("DEPRECATION")
                descriptor.value = value
                @Suppress("DEPRECATION")
                gatt.writeDescriptor(descriptor)
            }
        } catch (_: SecurityException) {}
    }

    private fun writeCharacteristic(gatt: BluetoothGatt, ch: BluetoothGattCharacteristic, bytes: ByteArray) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeCharacteristic(ch, bytes, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
            } else {
                @Suppress("DEPRECATION")
                ch.value = bytes
                ch.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                @Suppress("DEPRECATION")
                gatt.writeCharacteristic(ch)
            }
        } catch (_: SecurityException) {}
    }

    // Start accelerometer: op 0x02, type 0x02; settings sample rate (Hz,
    // uint16), resolution 16 bit, range 8 g.
    private fun startAccelCommand(rateHz: Int): ByteArray = byteArrayOf(
        0x02, 0x02,
        0x00, 0x01, (rateHz and 0xff).toByte(), ((rateHz shr 8) and 0xff).toByte(),
        0x01, 0x01, 0x10, 0x00,
        0x02, 0x01, 0x08, 0x00
    )

    // MARK: - Reconnect

    private fun scheduleReconnect() {
        if (reconnectAttempts >= maxReconnectAttempts) {
            // Streaming is truly over — release the keep-alive.
            BleStreamingForegroundController.stop(context)
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
                            // Re-assert the keep-alive (process may have been
                            // killed and restarted between attempts).
                            BleStreamingForegroundController.start(context)
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
                            requestLowLatency(gatt)
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

                    override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {

                        if (status == BluetoothGatt.GATT_SUCCESS) motionOnDescriptorWrite(gatt, descriptor)

                    }


                    override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {

                        if (characteristic.uuid != HR_MEASUREMENT_UUID) {

                            motionOnCharacteristicChanged(characteristic.uuid, value)

                            return

                        }
                        val sample = parseHeartRateMeasurement(value, gatt.device)
                        mainHandler.post { eventSink?.success(sample) }
                    }

                    @Deprecated("Deprecated in API 33")
                    override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                        @Suppress("DEPRECATION")
                        val data = characteristic.value ?: return
                        if (characteristic.uuid != HR_MEASUREMENT_UUID) {
                            motionOnCharacteristicChanged(characteristic.uuid, data)
                            return
                        }
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
        BleStreamingForegroundController.stop(context)
        result.success(null)
    }

    // MARK: - Parse HR Measurement

    /**
     * Ask for a low-latency connection interval before enabling HR notifications.
     *
     * Chest straps that report RR intervals send one notification per heartbeat.
     * On the platform's default (balanced) interval the link cannot always carry
     * a notification per beat once heart rate climbs past roughly 70 bpm, and the
     * strap drops the beats it could not send rather than queueing them. The HR
     * value stays plausible, so the loss is invisible downstream; only the RR
     * series is short. A high-priority interval keeps up with any human heart
     * rate. Best-effort: the call is advisory and the stack may decline.
     */
    private fun requestLowLatency(gatt: BluetoothGatt) {
        try {
            gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH)
        } catch (_: SecurityException) {
            // Missing BLUETOOTH_CONNECT at this point would already have failed connectGatt.
        }
    }

    private fun parseHeartRateMeasurement(data: ByteArray, device: BluetoothDevice): Map<String, Any> {
        // A malformed or truncated notification (e.g. BLE corruption or a
        // misbehaving strap) can be shorter than the spec requires. Indexing
        // past the end throws ArrayIndexOutOfBoundsException and crashes the
        // process, so bail out and report no usable sample when the buffer is
        // too short to hold the flags byte plus at least one BPM byte.
        if (data.size < 2) {
            return makeSample(0.0, emptyList(), device)
        }

        val flags = data[0].toInt() and 0xFF
        val is16Bit = (flags and 0x01) != 0
        val hasRR = (flags and 0x10) != 0

        var offset = 1
        val bpm: Double
        if (is16Bit) {
            // Need two bytes for a 16-bit BPM; skip the read if truncated.
            if (offset + 1 >= data.size) {
                return makeSample(0.0, emptyList(), device)
            }
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

        return makeSample(bpm, rrIntervals, device)
    }

    private fun makeSample(bpm: Double, rrIntervals: List<Double>, device: BluetoothDevice): Map<String, Any> {
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
