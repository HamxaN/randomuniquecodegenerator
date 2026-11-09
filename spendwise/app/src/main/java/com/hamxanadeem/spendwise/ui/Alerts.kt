package com.hamxanadeem.spendwise.ui

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.core.BudgetState
import com.hamxanadeem.spendwise.core.BudgetStatus
import com.hamxanadeem.spendwise.core.Insights
import com.hamxanadeem.spendwise.data.Store

/** A heads-up when a budget nears or passes its limit. */
object Alerts {
    private const val CHANNEL = "budgets"

    fun createChannel(context: Context) {
        val ch = NotificationChannel(CHANNEL, context.getString(R.string.alerts_channel), NotificationManager.IMPORTANCE_DEFAULT)
        ch.description = context.getString(R.string.alerts_channel_desc)
        context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(ch)
    }

    /** The message to show when a save moved a budget into a worse state, or null. */
    fun message(context: Context, before: BudgetStatus?, after: BudgetStatus?): String? {
        if (before == null || after == null || after.state.ordinal <= before.state.ordinal) return null
        val name = after.category.name
        return when (after.state) {
            BudgetState.OVER -> context.getString(R.string.alert_over, name, Ui.money(context, -after.remaining))
            BudgetState.WARNING -> context.getString(R.string.alert_warning, name, Insights.pct(after.fraction), Ui.money(context, after.remaining))
            else -> null
        }
    }

    fun notify(context: Context, text: String) {
        if (!Store.alertsEnabled(context)) return
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_TAB, R.id.tab_budgets)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(context.getString(R.string.alert_title))
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(text.hashCode(), n)
        } catch (_: SecurityException) {
        }
    }
}
