package com.hamxanadeem.clipcraft.core

import java.util.Locale
import kotlin.math.max
import kotlin.math.min

/** How likely a clip is to hold background music, from the soundtrack's loudness and where speech is. */
data class MusicRisk(val level: Level, val musicSeconds: Double, val share: Double) {
    enum class Level { LOW, MEDIUM, HIGH }
}

/**
 * Copyright helpers. ClipCraft can't check content against YouTube's database (only
 * YouTube can, with Content ID, after upload). What it can do offline is spot the most
 * common cause of Shorts claims: music playing where nobody is talking.
 */
object Copyright {
    /** Loudness is measured in windows of this length (seconds). */
    const val WINDOW = 0.5

    /**
     * Sound with no speech, window by window. [loudness] is RMS (0..1) per [WINDOW].
     * A window counts as "music" when no word overlaps it but it is at least a quarter
     * as loud as the speaker usually is; room noise and breaths are far quieter.
     */
    fun musicRisk(loudness: FloatArray, t: Transcript, start: Double, end: Double): MusicRisk {
        if (loudness.isEmpty() || end <= start) return MusicRisk(MusicRisk.Level.LOW, 0.0, 0.0)
        val threshold = max(speechLevel(loudness, t) * 0.25f, 0.02f)
        val words = t.between(start - 1.0, end + 1.0)
        val first = (start / WINDOW).toInt().coerceAtLeast(0)
        val last = min(loudness.size, (end / WINDOW).toInt() + 1)
        var music = 0
        var total = 0
        var run = 0
        var longest = 0
        for (i in first until last) {
            total++
            val ws = i * WINDOW
            val we = ws + WINDOW
            // Allow a little slack around words for breaths and word-boundary timing.
            val speech = words.any { it.start - 0.25 < we && it.end + 0.25 > ws }
            if (!speech && loudness[i] >= threshold) {
                music++
                run++
                longest = max(longest, run)
            } else {
                run = 0
            }
        }
        val share = if (total == 0) 0.0 else music.toDouble() / total
        val seconds = music * WINDOW
        val level = when {
            share >= 0.3 || longest * WINDOW >= 6.0 -> MusicRisk.Level.HIGH
            share >= 0.12 || longest * WINDOW >= 3.0 -> MusicRisk.Level.MEDIUM
            else -> MusicRisk.Level.LOW
        }
        return MusicRisk(level, seconds, share)
    }

    /** How loud the speaker typically is: the median loudness of windows with words in them. */
    fun speechLevel(loudness: FloatArray, t: Transcript): Float {
        val speaking = mutableListOf<Float>()
        for (i in loudness.indices) {
            val ws = i * WINDOW
            val we = ws + WINDOW
            if (t.words.any { it.start < we && it.end > ws }) speaking += loudness[i]
        }
        if (speaking.isEmpty()) return loudness.sorted()[loudness.size / 2]
        speaking.sort()
        return speaking[speaking.size / 2]
    }

    fun warning(r: MusicRisk): String? = when (r.level) {
        MusicRisk.Level.HIGH -> "Likely contains music (about %d s with sound but no speech). Music is the most common cause of copyright claims.".format(Locale.ROOT, r.musicSeconds.toInt())
        MusicRisk.Level.MEDIUM -> "May contain some music (about %d s with sound but no speech).".format(Locale.ROOT, r.musicSeconds.toInt())
        MusicRisk.Level.LOW -> null
    }

    fun encode(loudness: FloatArray): String = loudness.joinToString(",") { "%.4f".format(Locale.ROOT, it) }

    fun decode(text: String): FloatArray =
        text.split(',').mapNotNull { it.trim().toFloatOrNull() }.toFloatArray()

    /** What YouTube's processing said about an uploaded video, in plain words. */
    data class UploadCheck(val done: Boolean, val ok: Boolean, val message: String)

    /**
     * Reads the "status" part of a videos.list response. Rejections (copyright,
     * duplicate, terms of use…) are reported; claims that leave the video up don't
     * appear in the public API and must be checked in YouTube Studio.
     */
    fun readStatus(json: String): UploadCheck {
        val items = Json.arr(Json.obj(Json.parse(json))["items"])
        if (items.isEmpty()) return UploadCheck(false, true, "Still processing on YouTube…")
        val status = Json.obj(Json.obj(items[0])["status"])
        val upload = Json.str(status["uploadStatus"])
        return when (upload) {
            "processed" -> UploadCheck(true, true, "Processed by YouTube with no problems reported. Check YouTube Studio for any copyright claims.")
            "rejected" -> {
                val reason = Json.str(status["rejectionReason"])
                val text = when (reason) {
                    "copyright" -> "YouTube rejected this video for copyright. Remove the copyrighted music or footage and try again."
                    "duplicate" -> "YouTube rejected this video as a duplicate of one already on your channel."
                    "inappropriate", "termsOfUse" -> "YouTube rejected this video for breaking its rules."
                    "length" -> "YouTube rejected this video because of its length."
                    "trademark" -> "YouTube rejected this video for a trademark problem."
                    "legal" -> "YouTube rejected this video for a legal reason."
                    else -> "YouTube rejected this video ($reason)."
                }
                UploadCheck(true, false, text)
            }
            "failed" -> UploadCheck(true, false, "YouTube couldn't process this video (${Json.str(status["failureReason"])}).")
            "deleted" -> UploadCheck(true, false, "The video was deleted.")
            else -> UploadCheck(false, true, "Still processing on YouTube…")
        }
    }
}
