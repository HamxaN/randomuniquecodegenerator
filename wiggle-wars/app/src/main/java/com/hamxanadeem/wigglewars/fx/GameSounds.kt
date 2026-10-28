package com.hamxanadeem.wigglewars.fx

import android.content.Context
import com.hamxanadeem.wigglewars.core.ToneSynth
import com.hamxanadeem.wigglewars.core.ToneSynth.Note

object GameSounds {
    const val BOOM = "boom"
    const val BIG_BOOM = "big_boom"
    const val LAUNCH = "launch"
    const val SHOTGUN = "shotgun"
    const val WHACK = "whack"
    const val JUMP = "jump"
    const val OUCH = "ouch"
    const val SPLASH = "splash"
    const val BOUNCE = "bounce"
    const val TURN = "turn"
    const val TICK = "tick"
    const val CRATE = "crate"
    const val TELEPORT = "teleport"
    const val VICTORY = "victory"
    const val TAP = "tap"

    fun init(context: Context) = Sounds.init(
        context,
        mapOf(
            BOOM to { ToneSynth.noise(700, volume = 0.9, brightness = 0.12, rumble = 0.7, seed = 1) },
            BIG_BOOM to { ToneSynth.noise(1300, volume = 1.0, brightness = 0.07, rumble = 0.9, seed = 2) },
            LAUNCH to { ToneSynth.noise(260, volume = 0.5, brightness = 0.55, seed = 3) },
            SHOTGUN to { ToneSynth.noise(220, volume = 0.9, brightness = 0.85, rumble = 0.3, seed = 4) },
            WHACK to { ToneSynth.noise(120, volume = 0.9, brightness = 0.6, rumble = 0.5, seed = 5) },
            JUMP to { ToneSynth.wav((0 until 5).map { Note(400.0 + it * 120, 30, 0.35) }, gapMillis = 18) },
            OUCH to { ToneSynth.wav(listOf(Note(620.0, 90, 0.5), Note(440.0, 140, 0.5)), gapMillis = 80) },
            SPLASH to { ToneSynth.noise(600, volume = 0.6, brightness = 0.35, seed = 6) },
            BOUNCE to { ToneSynth.wav(listOf(Note(1200.0, 40, 0.25))) },
            TURN to { ToneSynth.wav(listOf(Note(784.0, 110), Note(1046.5, 180)), gapMillis = 90) },
            TICK to { ToneSynth.wav(listOf(Note(1568.0, 40, 0.3))) },
            CRATE to { ToneSynth.wav(listOf(Note(1046.5, 90), Note(1318.5, 90), Note(1568.0, 200)), gapMillis = 70) },
            TELEPORT to { ToneSynth.wav((0 until 8).map { Note(500.0 * Math.pow(2.0, it / 4.0), 50, 0.3) }, gapMillis = 30) },
            VICTORY to { ToneSynth.wav(listOf(Note(523.25, 150), Note(659.25, 150), Note(783.99, 150), Note(1046.5, 250), Note(783.99, 130), Note(1046.5, 500)), gapMillis = 140) },
            TAP to { ToneSynth.wav(listOf(Note(1046.5, 45, 0.3))) },
        ),
    )
}
