package com.hamxanadeem.wigglewars.data

import android.content.Context
import androidx.core.content.edit

/** Sound, vibration and ad-pacing values saved on the device. */
class Settings(context: Context) {

    private val prefs = context.applicationContext.getSharedPreferences("settings", Context.MODE_PRIVATE)

    var soundOn: Boolean
        get() = prefs.getBoolean("sound_on", true)
        set(value) = prefs.edit { putBoolean("sound_on", value) }

    var vibrationOn: Boolean
        get() = prefs.getBoolean("vibration_on", true)
        set(value) = prefs.edit { putBoolean("vibration_on", value) }

    var roundsPlayed: Int
        get() = prefs.getInt("rounds_played", 0)
        set(value) = prefs.edit { putInt("rounds_played", value) }

    /** Last arena picked in the setup screen; empty for random. */
    var arena: String
        get() = prefs.getString("arena", "") ?: ""
        set(value) = prefs.edit { putString("arena", value) }

    var weaponSet: String
        get() = prefs.getString("weapon_set", "") ?: ""
        set(value) = prefs.edit { putString("weapon_set", value) }

    var roundsSinceInterstitial: Int
        get() = prefs.getInt("rounds_since_interstitial", 0)
        set(value) = prefs.edit { putInt("rounds_since_interstitial", value) }
}
