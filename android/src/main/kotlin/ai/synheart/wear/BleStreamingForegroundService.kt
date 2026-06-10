package ai.synheart.wear

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps the host process alive while a BLE heart-rate
 * monitor (chest strap / generic HRM) is connected and streaming.
 *
 * Garmin's Companion SDK runs its own foreground service for its streaming, so
 * this covers ONLY the generic [BleHrmHandler] GATT path, which otherwise runs
 * inside the plugin with no service — leaving Android free to kill the process
 * (and drop the BLE connection) the moment the app is backgrounded.
 *
 * The service does no work itself: it only holds the process up so the GATT
 * callbacks keep delivering HR samples into the Dart `EventChannel`. It is
 * started on a successful connect and stopped on disconnect / reconnect
 * give-up / stream cancel — see [BleStreamingForegroundController].
 *
 * Requires the host app to declare FOREGROUND_SERVICE,
 * FOREGROUND_SERVICE_DATA_SYNC and POST_NOTIFICATIONS in its manifest (Life
 * already does).
 */
class BleStreamingForegroundService : Service() {

    companion object {
        private const val TAG = "BleStreamFgService"
        private const val NOTIFICATION_ID = 0xB1E_5E55.toInt()
        private const val CHANNEL_ID = "synheart_ble_streaming"
        private const val CHANNEL_NAME = "Heart-rate monitor"
        private const val CHANNEL_DESC =
            "Active while a connected heart-rate monitor is streaming to Synheart."

        const val ACTION_START = "ai.synheart.wear.action.START_BLE_STREAMING"
        const val ACTION_STOP = "ai.synheart.wear.action.STOP_BLE_STREAMING"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                Log.d(TAG, "ACTION_STOP — stopping foreground service")
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                Log.d(TAG, "ACTION_START — entering foreground")
                startForegroundCompat(buildNotification())
            }
        }
        // The BleHrmHandler owns the lifecycle and re-issues START on the next
        // connect, so don't auto-restart if the system kills us.
        return START_NOT_STICKY
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = CHANNEL_DESC
            setShowBadge(false)
            enableLights(false)
            enableVibration(false)
        }
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        // Tapping the notification reopens the host app via its launcher intent
        // (the plugin can't reference the host Activity class directly). Use
        // SINGLE_TOP only — never CLEAR_TOP — so merely posting the
        // notification doesn't yank the host task to the foreground.
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentIntent = launch?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Heart-rate monitor connected")
            .setContentText("Streaming heart rate to Synheart")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .apply { if (contentIntent != null) setContentIntent(contentIntent) }
            .build()
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+: sensor data flowing monitor → phone → SDK is a
            // dataSync workload (no privileged health/connectedDevice type).
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }
}

/**
 * Start/stop entry-points for the BLE streaming foreground service. Idempotent
 * and crash-safe — failures (e.g. the host app lacks the foreground-service
 * permission, or a background-start restriction) are logged, never thrown, so
 * BLE streaming still proceeds without the keep-alive.
 */
object BleStreamingForegroundController {
    private const val TAG = "BleStreamFgService"
    private const val SERVICE_CLASS =
        "ai.synheart.wear.BleStreamingForegroundService"

    fun start(context: Context) {
        val intent = Intent().apply {
            setClassName(context.packageName, SERVICE_CLASS)
            action = BleStreamingForegroundService.ACTION_START
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (e: Exception) {
            Log.w(TAG, "start() failed: ${e.message}")
        }
    }

    fun stop(context: Context) {
        val intent = Intent().apply {
            setClassName(context.packageName, SERVICE_CLASS)
            action = BleStreamingForegroundService.ACTION_STOP
        }
        try {
            // Plain startService for STOP — startForegroundService would
            // require a startForeground() call within 5s, but STOP tears down.
            context.startService(intent)
        } catch (e: Exception) {
            Log.w(TAG, "stop() failed: ${e.message}")
        }
    }
}
