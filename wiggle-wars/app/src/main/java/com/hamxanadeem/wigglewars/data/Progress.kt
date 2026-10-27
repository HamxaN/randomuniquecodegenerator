package com.hamxanadeem.wigglewars.data

import android.content.Context
import androidx.core.content.edit
import com.hamxanadeem.wigglewars.core.Campaign
import com.hamxanadeem.wigglewars.core.Upgrade
import com.hamxanadeem.wigglewars.core.Weapon

/** Campaign stars, coins, bought upgrades and the tutorial, saved on the device. */
class Progress(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("progress", Context.MODE_PRIVATE)

    var coins: Int
        get() = prefs.getInt("coins", 0)
        set(value) = prefs.edit { putInt("coins", value.coerceAtLeast(0)) }

    var tutorialDone: Boolean
        get() = prefs.getBoolean("tutorial_done", false)
        set(value) = prefs.edit { putBoolean("tutorial_done", value) }

    var fastForward: Boolean
        get() = prefs.getBoolean("fast_forward", false)
        set(value) = prefs.edit { putBoolean("fast_forward", value) }

    fun stars(mission: Int): Int = prefs.getInt("stars_$mission", 0)

    fun setStars(mission: Int, stars: Int) {
        if (stars > stars(mission)) prefs.edit { putInt("stars_$mission", stars) }
    }

    val totalStars: Int get() = Campaign.missions.sumOf { stars(it.number) }

    /** A mission can be played once the one before it has been won. */
    fun unlocked(mission: Int): Boolean = mission == 1 || stars(mission - 1) > 0

    fun level(upgrade: Upgrade): Int = prefs.getInt("upgrade_${upgrade.weapon.name}", 0)

    /** Spends coins on one more level of [upgrade]. Returns false if it can't be bought. */
    fun buy(upgrade: Upgrade): Boolean {
        val level = level(upgrade)
        if (level >= upgrade.max || coins < upgrade.price) return false
        coins -= upgrade.price
        prefs.edit { putInt("upgrade_${upgrade.weapon.name}", level + 1) }
        return true
    }

    /** Extra starting ammo from bought upgrades. */
    fun bonusAmmo(): Map<Weapon, Int> = Campaign.upgrades.associate { it.weapon to level(it) }.filterValues { it > 0 }
}
