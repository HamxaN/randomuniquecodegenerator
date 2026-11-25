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

    const val AI_OFF = "off"
    const val AI_KEY = "key"
    const val AI_SERVER = "server"

    /**
     * How this user finds clips: [AI_KEY] (Claude with their own key), [AI_SERVER]
     * (Claude through a ClipCraft server) or [AI_OFF] (no Claude, all on the phone).
     * Each user (each phone) chooses for themselves.
     */
    fun aiMode(c: Context): String = p(c).getString("ai_mode", null)
        ?: when {
            // Older installs: keep whatever they had set up.
            p(c).getBoolean("use_server", false) -> AI_SERVER
            apiKey(c).isNotBlank() -> AI_KEY
            else -> AI_OFF
        }

    fun setAiMode(c: Context, v: String) = p(c).edit { putString("ai_mode", v) }

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

    /** Internal testing: allow YouTube/TikTok/Instagram links (clips from them can't be posted). */
    fun allowPlatformLinks(c: Context): Boolean = p(c).getBoolean("platform_links", false)
    fun setAllowPlatformLinks(c: Context, v: Boolean) = p(c).edit { putBoolean("platform_links", v) }

    /** True when Claude is switched on and has what it needs. */
    fun aiReady(c: Context): Boolean = when (aiMode(c)) {
        AI_KEY -> apiKey(c).isNotBlank()
        AI_SERVER -> serverUrl(c).isNotBlank()
        else -> false
    }
}
