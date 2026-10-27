package com.hamxanadeem.neonrunner.data

import android.content.Context
import androidx.core.content.edit

/** Best score, banked orbs and owned skins, saved on the device. */
class Progress(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("progress", Context.MODE_PRIVATE)

    var best: Int
        get() = prefs.getInt("best", 0)
        set(value) = prefs.edit { putInt("best", value) }

    var orbs: Int
        get() = prefs.getInt("orbs", 0)
        set(value) = prefs.edit { putInt("orbs", value.coerceAtLeast(0)) }

    var skin: String
        get() = prefs.getString("skin", "cyan") ?: "cyan"
        set(value) = prefs.edit { putString("skin", value) }

    var tutorialDone: Boolean
        get() = prefs.getBoolean("tutorial_done", false)
        set(value) = prefs.edit { putBoolean("tutorial_done", value) }

    fun owns(id: String): Boolean = id == "cyan" || prefs.getBoolean("owns_$id", false)

    fun unlock(id: String) = prefs.edit { putBoolean("owns_$id", true) }
}
