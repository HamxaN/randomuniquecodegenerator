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

    /** Caption look: karaoke, boxed or clean. */
    fun captionStyle(c: Context): String = p(c).getString("cap_style", "karaoke") ?: "karaoke"
    fun setCaptionStyle(c: Context, v: String) = p(c).edit { putString("cap_style", v) }

    /** Caption height: low, middle or top. */
    fun captionPosition(c: Context): String = p(c).getString("cap_pos", "low") ?: "low"
    fun setCaptionPosition(c: Context, v: String) = p(c).edit { putString("cap_pos", v) }

    /** Caption writing system, a [com.hamxanadeem.clipcraft.core.Script] name. */
    fun script(c: Context): String = p(c).getString("script", "AS_SPOKEN") ?: "AS_SPOKEN"
    fun setScript(c: Context, v: String) = p(c).edit { putString("script", v) }

    fun reframe(c: Context): Boolean = p(c).getBoolean("reframe", true)
    fun setReframe(c: Context, v: Boolean) = p(c).edit { putBoolean("reframe", v) }

    fun useServer(c: Context): Boolean = p(c).getBoolean("use_server", false)
    fun setUseServer(c: Context, v: Boolean) = p(c).edit { putBoolean("use_server", v) }

    fun serverUrl(c: Context): String = p(c).getString("server_url", "") ?: ""
    fun setServerUrl(c: Context, v: String) = p(c).edit { putString("server_url", v.trim()) }

    fun serverToken(c: Context): String = secret(c).getString("server_token", "") ?: ""
    fun setServerToken(c: Context, v: String) = secret(c).edit { putString("server_token", v.trim()) }

    /** A random id the server uses for its per-device daily limit. */
    fun deviceId(c: Context): String {
        val id = p(c).getString("device", null)
        if (id != null) return id
        val n = java.util.UUID.randomUUID().toString()
        p(c).edit { putString("device", n) }
        return n
    }

    /** True when there's a way to ask the AI: the user's own key or a ClipCraft server. */
    fun aiReady(c: Context): Boolean = if (useServer(c)) serverUrl(c).isNotBlank() else apiKey(c).isNotBlank()
}
