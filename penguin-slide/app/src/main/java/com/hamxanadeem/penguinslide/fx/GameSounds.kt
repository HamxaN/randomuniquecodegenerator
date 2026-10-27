package com.hamxanadeem.penguinslide.fx

import android.content.Context
import com.hamxanadeem.penguinslide.core.ToneSynth
import com.hamxanadeem.penguinslide.core.ToneSynth.Note

/** The penguin's sound effects, as notes of a C major scale. */
object GameSounds {
    const val TAKEOFF = "takeoff"
    const val PERFECT = "perfect"
    const val LAND = "land"
    const val WIPEOUT = "wipeout"
    const val FLIP = "flip"
    const val FISH = "fish"
    const val CHECKPOINT = "checkpoint"
    const val FEVER = "fever"
    const val TIME_UP = "time_up"
    const val TAP = "tap"

    private const val C5 = 523.25
    private const val E5 = 659.25
    private const val G5 = 783.99
    private const val A5 = 880.00
    private const val C6 = 1046.50
    private const val E6 = 1318.51
    private const val G6 = 1567.98
    private const val C7 = 2093.00

    fun init(context: Context) = Sounds.init(
        context,
        mapOf(
            TAKEOFF to { ToneSynth.wav(listOf(Note(G5, 60, 0.3), Note(C6, 80, 0.3)), gapMillis = 40) },
            PERFECT to { ToneSynth.wav(listOf(Note(E6, 120), Note(G6, 200)), gapMillis = 60) },
            LAND to { ToneSynth.wav(listOf(Note(C5, 90, 0.35))) },
            WIPEOUT to { ToneSynth.wav(listOf(Note(E5, 140, 0.5), Note(C5, 140, 0.5), Note(262.0, 260, 0.5)), gapMillis = 110) },
            FLIP to { ToneSynth.wav(listOf(Note(C6, 110), Note(E6, 110), Note(G6, 110), Note(C7, 260)), gapMillis = 70) },
            FISH to { ToneSynth.wav(listOf(Note(C7, 70, 0.35))) },
            CHECKPOINT to { ToneSynth.wav(listOf(Note(G5, 120), Note(C6, 120), Note(E6, 120), Note(G6, 360)), gapMillis = 110) },
            FEVER to { ToneSynth.wav(listOf(Note(C6, 80), Note(E6, 80), Note(G6, 80), Note(C7, 80), Note(G6, 80), Note(C7, 220)), gapMillis = 55) },
            TIME_UP to { ToneSynth.wav(listOf(Note(A5, 220), Note(G5, 220), Note(E5, 220), Note(C5, 520)), gapMillis = 190) },
            TAP to { ToneSynth.wav(listOf(Note(C6, 50, 0.3))) },
        ),
    )
}
