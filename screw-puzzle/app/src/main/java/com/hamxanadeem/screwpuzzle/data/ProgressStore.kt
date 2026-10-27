package com.hamxanadeem.screwpuzzle.data

import android.content.Context
import androidx.core.content.edit
import com.hamxanadeem.screwpuzzle.core.Progress

class ProgressStore(context: Context) {

    private val prefs = context.applicationContext.getSharedPreferences("progress", Context.MODE_PRIVATE)

    fun load() = Progress(level = prefs.getInt("level", 1), coins = prefs.getInt("coins", 0))

    fun save(progress: Progress) = prefs.edit {
        putInt("level", progress.level)
        putInt("coins", progress.coins)
    }
}
