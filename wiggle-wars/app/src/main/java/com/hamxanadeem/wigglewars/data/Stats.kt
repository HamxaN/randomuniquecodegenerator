package com.hamxanadeem.wigglewars.data

import android.content.Context
import androidx.core.content.edit

/** Lifetime results, shown on the menu. */
class Stats(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("stats", Context.MODE_PRIVATE)

    var wins: Int
        get() = prefs.getInt("wins", 0)
        set(value) = prefs.edit { putInt("wins", value) }

    var matches: Int
        get() = prefs.getInt("matches", 0)
        set(value) = prefs.edit { putInt("matches", value) }
}
