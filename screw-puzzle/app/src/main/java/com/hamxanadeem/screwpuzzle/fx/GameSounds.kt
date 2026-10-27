package com.hamxanadeem.screwpuzzle.fx

import android.content.Context
import com.hamxanadeem.screwpuzzle.core.ToneSynth
import com.hamxanadeem.screwpuzzle.core.ToneSynth.Note

object GameSounds {
    const val UNSCREW = "unscrew"
    const val CLINK = "clink"
    const val TRAY = "tray"
    const val BLOCKED = "blocked"
    const val PLATE = "plate"
    const val BOX = "box"
    const val WIN = "win"
    const val STUCK = "stuck"
    const val TAP = "tap"

    fun init(context: Context) = Sounds.init(
        context,
        mapOf(
            UNSCREW to { ToneSynth.wav((0 until 6).map { Note(1200.0 + it * 140, 35, 0.25) }, gapMillis = 22) },
            CLINK to { ToneSynth.wav(listOf(Note(2093.0, 90, 0.4), Note(3136.0, 120, 0.2)), gapMillis = 15) },
            TRAY to { ToneSynth.wav(listOf(Note(880.0, 90, 0.4))) },
            BLOCKED to { ToneSynth.wav(listOf(Note(196.0, 90, 0.6), Note(185.0, 120, 0.6)), gapMillis = 70) },
            PLATE to { ToneSynth.wav((0 until 5).map { Note(700.0 - it * 90, 70, 0.35) }, gapMillis = 50) },
            BOX to { ToneSynth.wav(listOf(Note(1046.5, 120), Note(1318.5, 120), Note(1568.0, 260)), gapMillis = 80) },
            WIN to { ToneSynth.wav(listOf(Note(523.25, 140), Note(659.25, 140), Note(783.99, 140), Note(1046.5, 160), Note(783.99, 120), Note(1046.5, 420)), gapMillis = 120) },
            STUCK to { ToneSynth.wav(listOf(Note(392.0, 200), Note(330.0, 200), Note(262.0, 420)), gapMillis = 170) },
            TAP to { ToneSynth.wav(listOf(Note(1046.5, 50, 0.3))) },
        ),
    )
}
