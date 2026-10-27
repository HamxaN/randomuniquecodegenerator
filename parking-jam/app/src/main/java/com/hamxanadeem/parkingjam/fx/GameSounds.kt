package com.hamxanadeem.parkingjam.fx

import android.content.Context
import com.hamxanadeem.parkingjam.core.ToneSynth
import com.hamxanadeem.parkingjam.core.ToneSynth.Note

object GameSounds {
    const val VROOM = "vroom"
    const val HONK = "honk"
    const val TAP = "tap"
    const val WIN = "win"
    const val COIN = "coin"
    const val HINT = "hint"

    fun init(context: Context) = Sounds.init(
        context,
        mapOf(
            VROOM to { ToneSynth.wav((0 until 6).map { Note(110.0 + it * 40, 45, 0.45) }, gapMillis = 20) },
            HONK to { ToneSynth.wav(listOf(Note(415.3, 110, 0.5), Note(415.3, 160, 0.5)), gapMillis = 60) },
            TAP to { ToneSynth.wav(listOf(Note(1046.5, 45, 0.3))) },
            WIN to { ToneSynth.wav(listOf(Note(523.25, 120), Note(659.25, 120), Note(783.99, 120), Note(1046.5, 320)), gapMillis = 110) },
            COIN to { ToneSynth.wav(listOf(Note(1318.5, 60, 0.35), Note(1975.5, 120, 0.3)), gapMillis = 50) },
            HINT to { ToneSynth.wav(listOf(Note(880.0, 80, 0.3), Note(1174.7, 120, 0.3)), gapMillis = 60) },
        ),
    )
}
