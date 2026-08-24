package com.shinrinyoku.glimpse

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * A single silent foreground service that protects user-initiated share
 * enrichment from aggressive OEM background process termination.
 */
class EnrichmentKeepAliveService : Service() {
    private val activeProcessingIds = linkedSetOf<String>()
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val processingId = intent?.getStringExtra(EXTRA_PROCESSING_ID)
        when (intent?.action) {
            ACTION_FINISH -> {
                if (processingId != null) activeProcessingIds.remove(processingId)
                if (activeProcessingIds.isEmpty()) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                } else {
                    startForeground(NOTIFICATION_ID, buildNotification())
                }
            }
            else -> {
                if (processingId != null) activeProcessingIds.add(processingId)
                ensureWakeLock()
                startForeground(NOTIFICATION_ID, buildNotification())
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        super.onDestroy()
    }

    private fun ensureWakeLock() {
        if (wakeLock?.isHeld == true) return
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Glimpse:ShareEnrichment",
        ).also { it.acquire(MAX_WAKE_LOCK_MILLIS) }
    }

    private fun buildNotification(): android.app.Notification {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.background_enrichment_channel),
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = getString(R.string.background_enrichment_channel_description)
                    setSound(null, null)
                    enableVibration(false)
                },
            )
        }

        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = openIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(getString(R.string.background_enrichment_title))
            .setContentText(getString(R.string.background_enrichment_body))
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setShowWhen(false)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_DEFERRED)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "glimpse_background_enrichment"
        private const val NOTIFICATION_ID = 0x10000001
        private const val ACTION_START = "com.shinrinyoku.glimpse.enrichment.START"
        private const val ACTION_FINISH = "com.shinrinyoku.glimpse.enrichment.FINISH"
        private const val EXTRA_PROCESSING_ID = "processing_id"
        private const val MAX_WAKE_LOCK_MILLIS = 10 * 60 * 1000L

        fun start(context: Context, processingId: String) {
            val intent = Intent(context, EnrichmentKeepAliveService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_PROCESSING_ID, processingId)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun finish(context: Context, processingId: String) {
            context.startService(
                Intent(context, EnrichmentKeepAliveService::class.java).apply {
                    action = ACTION_FINISH
                    putExtra(EXTRA_PROCESSING_ID, processingId)
                },
            )
        }
    }
}
