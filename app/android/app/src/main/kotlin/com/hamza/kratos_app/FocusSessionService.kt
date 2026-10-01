package com.hamza.kratos_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat

class FocusSessionService : Service() {

    companion object {
        const val CHANNEL_ID = "kratos_focus_session"
        const val CHANNEL_NAME = "KRATOS Focus Session"
        const val NOTIFICATION_ID = 9001

        const val ACTION_START = "com.hamza.kratos.START_SERVICE"
        const val ACTION_UPDATE = "com.hamza.kratos.UPDATE_SERVICE"
        const val ACTION_PAUSE_DIRECT = "com.hamza.kratos.PAUSE_DIRECT"
        const val ACTION_RESUME_DIRECT = "com.hamza.kratos.RESUME_DIRECT"
        const val ACTION_STOP = "com.hamza.kratos.STOP_SERVICE"

        const val EXTRA_SESSION_ID = "sessionId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_LIFE_AREA = "lifeAreaName"
        const val EXTRA_IS_PAUSED = "isPaused"

        var isRunning: Boolean = false
            private set

        fun startService(context: Context, sessionId: String, title: String, lifeArea: String) {
            val intent = Intent(context, FocusSessionService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_SESSION_ID, sessionId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_LIFE_AREA, lifeArea)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun pauseService(context: Context) {
            val intent = Intent(context, FocusSessionService::class.java).apply {
                action = ACTION_PAUSE_DIRECT
            }
            context.startService(intent)
        }

        fun resumeService(context: Context) {
            val intent = Intent(context, FocusSessionService::class.java).apply {
                action = ACTION_RESUME_DIRECT
            }
            context.startService(intent)
        }

        fun stopService(context: Context) {
            val intent = Intent(context, FocusSessionService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var currentTitle: String = "Focus Session"
    private var currentLifeArea: String = ""
    private var isPaused: Boolean = false
    private var baseTimeUptime: Long = 0L
    private var elapsedBeforePauseMs: Long = 0L

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                isRunning = true
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: "Focus Session"
                currentLifeArea = intent.getStringExtra(EXTRA_LIFE_AREA) ?: ""
                isPaused = false
                elapsedBeforePauseMs = 0L
                baseTimeUptime = SystemClock.elapsedRealtime()

                val notification = buildNotification()
                startForeground(NOTIFICATION_ID, notification)
            }
            ACTION_PAUSE_DIRECT -> {
                if (!isPaused) {
                    isPaused = true
                    elapsedBeforePauseMs = SystemClock.elapsedRealtime() - baseTimeUptime
                    updateNotification()
                }
            }
            ACTION_RESUME_DIRECT -> {
                if (isPaused) {
                    isPaused = false
                    baseTimeUptime = SystemClock.elapsedRealtime() - elapsedBeforePauseMs
                    updateNotification()
                }
            }
            ACTION_UPDATE -> {
                val pausedFromIntent = intent.getBooleanExtra(EXTRA_IS_PAUSED, isPaused)
                if (pausedFromIntent != isPaused) {
                    if (pausedFromIntent) {
                        isPaused = true
                        elapsedBeforePauseMs = SystemClock.elapsedRealtime() - baseTimeUptime
                    } else {
                        isPaused = false
                        baseTimeUptime = SystemClock.elapsedRealtime() - elapsedBeforePauseMs
                    }
                    updateNotification()
                }
            }
            ACTION_STOP -> {
                isRunning = false
                stopForeground(true)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Ongoing user-visible focus tracking, stopwatch and Now Bar controls"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(false)
                setSound(null, null)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun formatElapsed(ms: Long): String {
        val totalSec = ms / 1000
        val m = (totalSec / 60)
        val s = (totalSec % 60)
        return String.format("%02d:%02d", m, s)
    }

    private fun buildNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Action 1: Toggle Pause / Resume
        val toggleAction = if (isPaused) "com.hamza.kratos.ACTION_RESUME" else "com.hamza.kratos.ACTION_PAUSE"
        val toggleTitle = if (isPaused) "Resume ▶" else "Pause ⏸"
        val toggleIcon = if (isPaused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause
        val toggleIntent = Intent(this, FocusNotificationReceiver::class.java).apply {
            action = toggleAction
        }
        val togglePendingIntent = PendingIntent.getBroadcast(
            this,
            1,
            toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Action 2: Complete Session
        val completeIntent = Intent(this, FocusNotificationReceiver::class.java).apply {
            action = "com.hamza.kratos.ACTION_COMPLETE"
        }
        val completePendingIntent = PendingIntent.getBroadcast(
            this,
            2,
            completeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(if (isPaused) "⏸ Paused: $currentTitle" else "⚡ Focus: $currentTitle")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // CATEGORY_STOPWATCH is recognized by Samsung One UI for the Now Bar and Status Bar Pill!
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setContentIntent(openAppPendingIntent)
            .addAction(toggleIcon, toggleTitle, togglePendingIntent)
            .addAction(android.R.drawable.checkbox_on_background, "Done ✓", completePendingIntent)

        if (!isPaused) {
            // Live ticking Chronometer handled directly by the Android & Samsung OS
            builder.setShowWhen(true)
                .setUsesChronometer(true)
                .setWhen(System.currentTimeMillis() - (SystemClock.elapsedRealtime() - baseTimeUptime))
                .setContentText(if (currentLifeArea.isNotEmpty()) "$currentLifeArea • Active Session" else "Focus Session in Progress")
        } else {
            // Paused state: show static elapsed time
            val pausedStr = formatElapsed(elapsedBeforePauseMs)
            builder.setShowWhen(false)
                .setUsesChronometer(false)
                .setContentText(if (currentLifeArea.isNotEmpty()) "$currentLifeArea • Paused at $pausedStr" else "Paused at $pausedStr")
        }

        return builder.build()
    }
}
