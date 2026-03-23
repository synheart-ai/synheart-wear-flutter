package com.synheart.wear.garmin

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Stub Garmin SDK bridge for Android.
/// Garmin Connect IQ companion functionality is iOS-only for now;
/// this class registers the channel so Dart calls receive graceful errors.
class GarminSDKBridge : MethodChannel.MethodCallHandler {

    companion object {
        fun registerWith(binding: FlutterPlugin.FlutterPluginBinding) {
            val channel = MethodChannel(
                binding.binaryMessenger,
                "synheart_wear/garmin_sdk"
            )
            channel.setMethodCallHandler(GarminSDKBridge())
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        result.error(
            "UNAVAILABLE",
            "Garmin SDK bridge is not available on Android",
            null
        )
    }
}
