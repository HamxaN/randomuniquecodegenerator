package com.hamxanadeem.clipcraft.data

import android.content.Context
import androidx.core.content.edit

/** App settings, stored on this phone only. */
object Settings {
    private fun p(c: Context) = c.applicationContext.getSharedPreferences("clipcraft", Context.MODE_PRIVATE)

    // The API key lives in its own file, which is left out of backups.
    private fun secret(c: Context) = c.applicationContext.getSharedPreferences("clipcraft_secret", Context.MODE_PRIVATE)

    fun apiKey(c: Context): String = secret(c).getString("api_key", "") ?: ""
    fun setApiKey(c: Context, v: String) = secret(c).edit { putString("api_key", v.trim()) }

    fun language(c: Context): String = p(c).getString("lang", "en") ?: "en"
    fun setLanguage(c: Context, v: String) = p(c).edit { putString("lang", v) }

    fun clipCount(c: Context): Int = p(c).getInt("count", 5)
    fun setClipCount(c: Context, v: Int) = p(c).edit { putInt("count", v) }

    fun notes(c: Context): String = p(c).getString("notes", "") ?: ""
    fun setNotes(c: Context, v: String) = p(c).edit { putString("notes", v) }

    fun privacy(c: Context): String = p(c).getString("privacy", "private") ?: "private"
    fun setPrivacy(c: Context, v: String) = p(c).edit { putString("privacy", v) }

    fun captions(c: Context): Boolean = p(c).getBoolean("captions", true)
    fun setCaptions(c: Context, v: Boolean) = p(c).edit { putBoolean("captions", v) }

    fun hook(c: Context): Boolean = p(c).getBoolean("hook", true)
    fun setHook(c: Context, v: Boolean) = p(c).edit { putBoolean("hook", v) }

    fun captionColor(c: Context): Int = p(c).getInt("cap_color", 0xFFFFD21A.toInt())
    fun setCaptionColor(c: Context, v: Int) = p(c).edit { putInt("cap_color", v) }
}
