package com.hamxanadeem.neonrunner.fx

import android.content.Context
import com.hamxanadeem.neonrunner.core.ToneSynth
import com.hamxanadeem.neonrunner.core.ToneSynth.Note

object GameSounds {
    const val ORB = "orb"
    const val JUMP = "jump"
    const val SLIDE = "slide"
    const val SWOOSH = "swoosh"
    const val POWER = "power"
    const val SHIELD = "shield"
    const val CRASH = "crash"
    const val MILESTONE = "milestone"
    const val TAP = "tap"
    const val BUY = "buy"

    fun init(context: Context) = Sounds.init(
        context,
        mapOf(
            ORB to { ToneSynth.wav(listOf(Note(1568.0, 45, 0.35), Note(2093.0, 70, 0.3)), gapMillis = 30) },
            JUMP to { ToneSynth.wav((0 until 5).map { Note(500.0 + it * 140, 28, 0.3) }, gapMillis = 14) },
            SLIDE to { ToneSynth.wav((0 until 4).map { Note(700.0 - it * 110, 30, 0.3) }, gapMillis = 14) },
            SWOOSH to { ToneSynth.wav(listOf(Note(880.0, 30, 0.18), Note(1320.0, 30, 0.12)), gapMillis = 10) },
            POWER to { ToneSynth.wav((0 until 6).map { Note(523.25 * Math.pow(2.0, it / 6.0), 55, 0.35) }, gapMillis = 35) },
            SHIELD to { ToneSynth.wav(listOf(Note(330.0, 120, 0.5), Note(220.0, 200, 0.4)), gapMillis = 60) },
            CRASH to { ToneSynth.wav(listOf(Note(220.0, 120, 0.6), Note(146.8, 160, 0.6), Note(98.0, 320, 0.6)), gapMillis = 80) },
            MILESTONE to { ToneSynth.wav(listOf(Note(1046.5, 80), Note(1318.5, 80), Note(1568.0, 180)), gapMillis = 60) },
            TAP to { ToneSynth.wav(listOf(Note(1046.5, 45, 0.3))) },
            BUY to { ToneSynth.wav(listOf(Note(784.0, 90), Note(1046.5, 90), Note(1568.0, 220)), gapMillis = 60) },
        ),
    )
}
