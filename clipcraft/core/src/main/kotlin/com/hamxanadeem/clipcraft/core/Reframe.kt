package com.hamxanadeem.clipcraft.core

import kotlin.math.abs
import kotlin.math.min

/** Where the main face is at time [t] (seconds into the clip): its centre, 0..1 across the frame, or null. */
data class FaceSample(val t: Double, val x: Double?)

/**
 * A horizontal pan over time, as a shift in normalised device coordinates (the frame
 * is 2 wide). Shifting the picture by [at] and then centre-cropping to 9:16 keeps the
 * face in shot.
 */
class PanPath(val keys: List<Pair<Double, Double>>) {
    fun at(t: Double): Double {
        if (keys.isEmpty()) return 0.0
        if (t <= keys.first().first) return keys.first().second
        if (t >= keys.last().first) return keys.last().second
        val i = keys.indexOfLast { it.first <= t }
        val (t0, v0) = keys[i]
        val (t1, v1) = keys[i + 1]
        val k = if (t1 > t0) (t - t0) / (t1 - t0) else 0.0
        // Ease in and out between keyframes so pans feel like a camera operator.
        val e = k * k * (3 - 2 * k)
        return v0 + (v1 - v0) * e
    }

    val still: Boolean get() = keys.all { abs(it.second - (keys.firstOrNull()?.second ?: 0.0)) < 1e-6 }
}

object Reframe {
    /** The share of the source width a 9:16 crop keeps (1.0 if the source is already tall enough). */
    fun cropFraction(srcW: Int, srcH: Int, outAspect: Double = 9.0 / 16.0): Double =
        if (srcW <= 0 || srcH <= 0) 1.0 else min(1.0, srcH * outAspect / srcW)

    /**
     * Turns face positions into a smooth pan. Gaps without a face hold the last
     * position; small movements inside a dead zone are ignored so the shot doesn't
     * wobble; the crop never leaves the frame.
     */
    fun path(samples: List<FaceSample>, cropFraction: Double, deadZone: Double = 0.12): PanPath {
        if (cropFraction >= 0.999 || samples.isEmpty()) return PanPath(listOf(0.0 to 0.0))
        val limit = 1.0 - cropFraction
        // Fill gaps: before the first face use the first one, after it hold the last.
        val firstX = samples.firstOrNull { it.x != null }?.x ?: return PanPath(listOf(0.0 to 0.0))
        var last = firstX
        val filled = samples.sortedBy { it.t }.map { s ->
            val x = s.x ?: last
            last = x
            s.t to x
        }
        // Light smoothing (moving average of 3).
        val smooth = filled.mapIndexed { i, (t, _) ->
            val from = maxOf(0, i - 1)
            val to = minOf(filled.size - 1, i + 1)
            t to (from..to).map { filled[it].second }.average()
        }
        val keys = mutableListOf<Pair<Double, Double>>()
        var held = Double.NaN
        for ((t, x) in smooth) {
            val target = (-(2 * x - 1)).coerceIn(-limit, limit)
            if (held.isNaN() || abs(target - held) > deadZone * cropFraction * 2) {
                held = target
                keys += t to held
            }
        }
        // Hold each position until just before the next move, so the camera rests, then pans.
        val out = mutableListOf<Pair<Double, Double>>()
        for (i in keys.indices) {
            if (i > 0) out += (keys[i].first - 0.6).coerceAtLeast(out.last().first + 0.01) to keys[i - 1].second
            out += keys[i]
        }
        return PanPath(out)
    }
}
