package com.hamxanadeem.clipcraft.core

import java.util.Locale

/** Reads the soundtrack's loudness alongside the words, for the AI's sound cues. */
class SoundCues(private val t: Transcript, private val loudness: FloatArray) {
    private val speech = Copyright.speechLevel(loudness, t)

    private fun window(i: Int) = loudness.getOrElse(i) { 0f }

    private fun avg(start: Double, end: Double): Float {
        val a = (start / Copyright.WINDOW).toInt()
        val b = maxOf(a + 1, (end / Copyright.WINDOW).toInt())
        var s = 0f
        for (i in a until b) s += window(i)
        return s / (b - a)
    }

    /** A line said much louder than the speaker usually talks. */
    fun loud(l: Line): Boolean = speech > 0f && avg(l.start, l.end) > speech * 1.6f

    /** A note for the gap between two lines, or null when nothing notable happens. */
    fun gap(from: Double, to: Double): String? {
        val len = to - from
        if (len < 1.2) return null
        val a = (from / Copyright.WINDOW).toInt() + 1
        val b = (to / Copyright.WINDOW).toInt()
        var sound = 0
        for (i in a until b) if (window(i) >= maxOf(speech * 0.25f, 0.02f)) sound++
        val soundSec = sound * Copyright.WINDOW
        return when {
            soundSec >= 1.0 -> "[%.1fs of sound without speech: music, laughter or a reaction]".format(Locale.ROOT, soundSec)
            len >= 2.0 -> "[pause %.1fs]".format(Locale.ROOT, len)
            else -> null
        }
    }
}
