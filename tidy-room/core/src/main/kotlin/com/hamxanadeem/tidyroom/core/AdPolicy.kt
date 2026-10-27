package com.hamxanadeem.tidyroom.core

/** Decides when an interstitial may be shown after a round, so ads never feel spammy. */
class AdPolicy(
    /** At most one interstitial per this many finished rounds. */
    val gamesBetweenInterstitials: Int = 2,
    /** Minimum time between two interstitials. */
    val minMillisBetweenInterstitials: Long = 120_000L,
    /** No interstitials until the player has finished this many rounds. */
    val graceGames: Int = 2,
) {
    fun shouldShowInterstitial(
        gamesPlayed: Int,
        gamesSinceInterstitial: Int,
        nowMillis: Long,
        lastShownMillis: Long?,
    ): Boolean =
        gamesPlayed >= graceGames &&
            gamesSinceInterstitial >= gamesBetweenInterstitials &&
            (lastShownMillis == null || nowMillis - lastShownMillis >= minMillisBetweenInterstitials)
}
