package com.hamxanadeem.idlebakery.data

import android.content.Context
import androidx.core.content.edit
import com.hamxanadeem.idlebakery.core.Bakery

class BakeryStore(context: Context) {

    private val prefs = context.applicationContext.getSharedPreferences("bakery", Context.MODE_PRIVATE)

    fun load(): Bakery = prefs.getString("state", null)?.let { Bakery.decode(it) } ?: Bakery()

    /** Saves the bakery and stamps the time, for offline earnings. */
    fun save(bakery: Bakery, now: Long) {
        bakery.lastSeen = now
        prefs.edit { putString("state", bakery.encode()) }
    }
}
