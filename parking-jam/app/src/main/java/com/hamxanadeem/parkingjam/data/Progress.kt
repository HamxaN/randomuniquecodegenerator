package com.hamxanadeem.parkingjam.data

import android.content.Context
import androidx.core.content.edit

/** The level reached, coins and stars, saved on the device. */
class Progress(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("progress", Context.MODE_PRIVATE)

    var level: Int
        get() = prefs.getInt("level", 1)
        set(value) = prefs.edit { putInt("level", value) }

    var coins: Int
        get() = prefs.getInt("coins", 0)
        set(value) = prefs.edit { putInt("coins", value.coerceAtLeast(0)) }

    var stars: Int
        get() = prefs.getInt("stars", 0)
        set(value) = prefs.edit { putInt("stars", value) }
}
