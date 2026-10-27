package com.hamxanadeem.penguinslide.data

import android.content.Context
import androidx.core.content.edit
import com.hamxanadeem.penguinslide.core.Progress

/** Saves fish, skins and records on the device. */
class ProgressStore(context: Context) {

    private val prefs = context.applicationContext.getSharedPreferences("progress", Context.MODE_PRIVATE)

    fun load(): Progress {
        val d = Progress()
        return Progress(
            fish = prefs.getInt("fish", d.fish),
            ownedSkins = prefs.getStringSet("owned_skins", null)?.toSet() ?: d.ownedSkins,
            selectedSkin = prefs.getString("selected_skin", null) ?: d.selectedSkin,
            bestScore = prefs.getInt("best_score", d.bestScore),
            bestDistance = prefs.getInt("best_distance", d.bestDistance),
        )
    }

    fun save(progress: Progress) {
        prefs.edit {
            putInt("fish", progress.fish)
            putStringSet("owned_skins", progress.ownedSkins.toSet())
            putString("selected_skin", progress.selectedSkin)
            putInt("best_score", progress.bestScore)
            putInt("best_distance", progress.bestDistance)
        }
    }
}
