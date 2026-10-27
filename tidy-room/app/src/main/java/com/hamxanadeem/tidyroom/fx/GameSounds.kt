package com.hamxanadeem.tidyroom.fx

import android.content.Context
import com.hamxanadeem.tidyroom.core.ToneSynth
import com.hamxanadeem.tidyroom.core.ToneSynth.Note

object GameSounds {
    const val PICK = "pick"
    const val PLACE = "place"
    const val MISS = "miss"
    const val TIDY = "tidy"
    const val TAP = "tap"
    const val COIN = "coin"

    fun init(context: Context) = Sounds.init(
        context,
        mapOf(
            PICK to { ToneSynth.wav(listOf(Note(660.0, 40, 0.25), Note(880.0, 40, 0.2)), gapMillis = 20) },
            PLACE to { ToneSynth.wav(listOf(Note(784.0, 60, 0.35), Note(1174.7, 120, 0.3)), gapMillis = 40) },
            MISS to { ToneSynth.wav(listOf(Note(311.1, 90, 0.35), Note(261.6, 140, 0.3)), gapMillis = 50) },
            TIDY to { ToneSynth.wav(listOf(Note(523.25, 110), Note(659.25, 110), Note(783.99, 110), Note(1046.5, 160), Note(1318.5, 360)), gapMillis = 100) },
            TAP to { ToneSynth.wav(listOf(Note(1046.5, 45, 0.3))) },
            COIN to { ToneSynth.wav(listOf(Note(1318.5, 60, 0.35), Note(1975.5, 120, 0.3)), gapMillis = 50) },
        ),
    )
}
