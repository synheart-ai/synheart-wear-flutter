package com.synheart.wear

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.synheart.wear.garmin.GarminSDKBridge

class SynheartWearPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var applicationContext: android.content.Context? = null
    private val SAMSUNG_HEALTH_PACKAGE = "com.samsung.shealth"
    private var garminBridge: GarminSDKBridge? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel =
                MethodChannel(flutterPluginBinding.binaryMessenger, "synheart_wear/android_health")
        channel.setMethodCallHandler(this)

        // Register Garmin SDK bridge
        GarminSDKBridge.registerWith(flutterPluginBinding)

        // Register BLE HRM handler
        BleHrmHandler.registerWith(flutterPluginBinding)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = applicationContext
        if (context == null) {
            result.error("UNAVAILABLE", "Application context not available", null)
            return
        }

        when (call.method) {
            "isSamsungHealthInstalled" -> {
                result.success(isSamsungHealthInstalled(context))
            }
            "openSamsungHealthSettings" -> {
                try {
                    openSamsungHealthSettings(context)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Cannot open Samsung Health: ${e.message}", null)
                }
            }
            "getAndroidVersion" -> {
                result.success(android.os.Build.VERSION.SDK_INT)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isSamsungHealthInstalled(context: android.content.Context): Boolean {
        return try {
            context.packageManager.getPackageInfo(SAMSUNG_HEALTH_PACKAGE, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun openSamsungHealthSettings(context: android.content.Context) {
        try {
            // Try to open Samsung Health app directly
            val intent = context.packageManager.getLaunchIntentForPackage(SAMSUNG_HEALTH_PACKAGE)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            } else {
                // Fallback: Open app in Play Store
                try {
                    context.startActivity(
                            Intent(
                                    Intent.ACTION_VIEW,
                                    Uri.parse("market://details?id=$SAMSUNG_HEALTH_PACKAGE")
                            )
                    )
                } catch (e: Exception) {
                    context.startActivity(
                            Intent(
                                    Intent.ACTION_VIEW,
                                    Uri.parse(
                                            "https://play.google.com/store/apps/details?id=$SAMSUNG_HEALTH_PACKAGE"
                                    )
                            )
                    )
                }
            }
        } catch (e: Exception) {
            throw e
        }
    }
}
