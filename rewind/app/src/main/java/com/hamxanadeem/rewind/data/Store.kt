package com.hamxanadeem.rewind.data

import android.content.Context
import androidx.core.content.edit
import com.hamxanadeem.rewind.core.Progress

/** Saved progress and settings, on this phone. */
object Store {
    private fun p(c: Context) = c.applicationContext.getSharedPreferences("rewind", Context.MODE_PRIVATE)

    fun progress(c: Context): Progress = Progress.decode(p(c).getString("progress", null))
    fun save(c: Context, progress: Progress) = p(c).edit { putString("progress", progress.encode()) }

    fun sound(c: Context): Boolean = p(c).getBoolean("sound", true)
    fun setSound(c: Context, v: Boolean) = p(c).edit { putBoolean("sound", v) }

    /** Bought "Remove ads" (banners and interstitials; rewarded ads stay optional). */
    fun adsRemoved(c: Context): Boolean = p(c).getBoolean("no_ads", false)
    fun setAdsRemoved(c: Context, v: Boolean) = p(c).edit { putBoolean("no_ads", v) }

    fun seenTutorial(c: Context): Boolean = p(c).getBoolean("tutorial", false)
    fun setSeenTutorial(c: Context) = p(c).edit { putBoolean("tutorial", true) }
}
