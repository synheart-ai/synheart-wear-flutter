package ai.synheart.wear.garmin

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Stub Garmin SDK bridge for Android.
///
/// In the open-source build this class only registers the method channel
/// so Dart-side calls receive a graceful "UNAVAILABLE" error instead of a
/// MissingPluginException. The real bridge (which depends on the licensed
/// Garmin Health SDK) lives in the private `synheart-wear-garmin-companion`
/// repository and replaces this file when `make build-with-garmin` is run.
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
            "Garmin SDK bridge is not available on Android — install the companion overlay to enable RTS",
            null
        )
    }
}
