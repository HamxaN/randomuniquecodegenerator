package com.hamxanadeem.idlebakery.fx

import android.content.Context
import com.hamxanadeem.idlebakery.core.ToneSynth
import com.hamxanadeem.idlebakery.core.ToneSynth.Note

object GameSounds {
    const val COIN = "coin"
    const val BAKE = "bake"
    const val BUY = "buy"
    const val HIRE = "hire"
    const val MILESTONE = "milestone"
    const val BOOST = "boost"
    const val TAP = "tap"
    const val DENIED = "denied"

    fun init(context: Context) = Sounds.init(
        context,
        mapOf(
            COIN to { ToneSynth.wav(listOf(Note(1975.5, 60, 0.3), Note(2637.0, 120, 0.3)), gapMillis = 50) },
            BAKE to { ToneSynth.wav(listOf(Note(659.25, 60, 0.35), Note(880.0, 80, 0.35)), gapMillis = 40) },
            BUY to { ToneSynth.wav(listOf(Note(1046.5, 70), Note(1568.0, 120)), gapMillis = 55) },
            HIRE to { ToneSynth.wav(listOf(Note(783.99, 110), Note(1046.5, 110), Note(1318.5, 110), Note(1568.0, 260)), gapMillis = 90) },
            MILESTONE to { ToneSynth.wav(listOf(Note(1046.5, 100), Note(1318.5, 100), Note(1568.0, 100), Note(2093.0, 300)), gapMillis = 70) },
            BOOST to { ToneSynth.wav((0 until 8).map { Note(523.25 * Math.pow(2.0, it / 6.0), 80, 0.4) }, gapMillis = 45) },
            TAP to { ToneSynth.wav(listOf(Note(1046.5, 45, 0.3))) },
            DENIED to { ToneSynth.wav(listOf(Note(220.0, 120, 0.5))) },
        ),
    )
}
