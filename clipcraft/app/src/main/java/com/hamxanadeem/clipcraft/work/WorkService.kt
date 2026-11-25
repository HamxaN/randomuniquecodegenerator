package com.hamxanadeem.clipcraft.work

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.hamxanadeem.clipcraft.R
import com.hamxanadeem.clipcraft.ui.MainActivity

/**
 * Keeps ClipCraft running while it transcribes, renders and uploads, so work carries on
 * when you leave the app or lock the screen. It shows a progress notification and
 * stops itself when the queue is empty.
 */
class WorkService : Service() {

    companion object {
        const val CHANNEL = "work"
        const val ID = 41

        fun channel(c: Context) {
            val ch = NotificationChannel(CHANNEL, c.getString(R.string.channel_work), NotificationManager.IMPORTANCE_LOW)
            c.getSystemService(NotificationManager::class.java)?.createNotificationChannel(ch)
        }

        fun notification(c: Context, text: String, progress: Int): Notification {
            val open = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            return NotificationCompat.Builder(c, CHANNEL)
                .setSmallIcon(R.drawable.ic_cut)
                .setContentTitle(c.getString(R.string.app_name))
                .setContentText(text)
                .setOnlyAlertOnce(true)
                .setOngoing(true)
                .setContentIntent(open)
                .setProgress(100, progress.coerceIn(0, 100), progress < 0)
                .build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        channel(this)
        ServiceCompat.startForeground(this, ID, notification(this, getString(R.string.working), -1),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        if (Engine.idle()) stopSelf()
        return START_NOT_STICKY
    }
}
