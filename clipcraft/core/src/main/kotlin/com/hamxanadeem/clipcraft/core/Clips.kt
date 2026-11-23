package com.hamxanadeem.clipcraft.core

import kotlin.math.max
import kotlin.math.min

/** One suggested short: where it is, how to post it, and why it should work. */
data class ClipPlan(
    val start: Double,
    val end: Double,
    val title: String,
    val description: String,
    val hashtags: List<String>,
    val score: Int,
    val reason: String,
    val hook: String = "",
) {
    val length: Double get() = end - start
}

object Clips {
    const val MIN = 15.0
    const val MAX = 60.0

    /**
     * Cleans up suggestions: snaps edges to sentence boundaries so a clip never starts
     * or ends mid-word, keeps lengths between [MIN] and [MAX] seconds, drops clips that
     * overlap a better one, and sorts best first.
     */
    fun tidy(plans: List<ClipPlan>, t: Transcript, maxCount: Int = 10): List<ClipPlan> {
        val lines = t.lines()
        val dur = max(t.duration, plans.maxOfOrNull { it.end } ?: 0.0)
        val out = mutableListOf<ClipPlan>()
        for (p in plans.sortedByDescending { it.score }) {
            if (p.end <= p.start || p.start >= dur) continue
            var s = p.start.coerceAtLeast(0.0)
            var e = p.end.coerceAtMost(dur)
            if (lines.isNotEmpty()) {
                // Start at the beginning of the line that contains (or follows) the start.
                lines.lastOrNull { it.start <= s + 0.3 }?.let { s = it.start }
                // End at the end of the line that contains the end.
                lines.firstOrNull { it.end >= e - 0.3 }?.let { e = it.end }
            }
            if (e - s > MAX) {
                // Too long: end at the last line that fits.
                val fit = lines.lastOrNull { it.end <= s + MAX && it.end > s + MIN }
                e = fit?.end ?: (s + MAX)
            }
            if (e - s < MIN) {
                // Too short: grow forward, then backward, a line at a time.
                for (l in lines) if (l.start >= e && l.end - s <= MAX && e - s < MIN) e = l.end
                for (l in lines.reversed()) if (l.end <= s && e - l.start <= MAX && e - s < MIN) s = l.start
                if (e - s < MIN) e = min(dur, s + MIN)
            }
            s = (s - 0.15).coerceAtLeast(0.0)
            e = min(dur, e + 0.35)
            val overlaps = out.any { o -> min(o.end, e) - max(o.start, s) > 0.3 * min(o.length, e - s) }
            if (overlaps) continue
            out += p.copy(start = s, end = e, title = p.title.trim().take(95), hashtags = hashtags(p.hashtags), score = p.score.coerceIn(1, 100))
            if (out.size >= maxCount) break
        }
        return out
    }

    fun hashtags(tags: List<String>): List<String> =
        tags.map { "#" + it.trim().trimStart('#').replace(Regex("[^\\p{L}\\p{N}_]"), "") }
            .filter { it.length > 1 }.distinctBy { it.lowercase() }.take(8)

    /** Reads the model's JSON reply into plans. Unknown or broken entries are skipped. */
    fun fromJson(text: String): List<ClipPlan> {
        val body = text.trim().removePrefix("```json").removePrefix("```").removeSuffix("```").trim()
        val root = Json.obj(Json.parse(body))
        return Json.arr(root["clips"]).mapNotNull { c ->
            val m = Json.obj(c)
            val s = Json.num(m["start"], -1.0)
            val e = Json.num(m["end"], -1.0)
            if (s < 0 || e <= s) return@mapNotNull null
            ClipPlan(s, e, Json.str(m["title"]), Json.str(m["description"]), Json.arr(m["hashtags"]).map { Json.str(it) },
                Json.num(m["score"], 50.0).toInt(), Json.str(m["reason"]), Json.str(m["hook"]))
        }
    }
}
