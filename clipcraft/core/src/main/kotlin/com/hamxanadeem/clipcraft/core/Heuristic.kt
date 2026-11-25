package com.hamxanadeem.clipcraft.core

import java.util.Locale

/**
 * An offline fallback for when there's no AI key: scores windows of the talk by
 * pace, questions, exclamations, strong words, numbers and confident speech.
 */
object Heuristic {
    private val STRONG = setOf("secret", "never", "always", "best", "worst", "crazy", "insane", "shocking", "truth", "mistake",
        "money", "free", "how", "why", "stop", "wow", "amazing", "important", "nobody", "everyone", "biggest", "first",
        "love", "hate", "funny", "laugh", "story", "actually", "seriously", "problem", "hack", "tip")

    fun pick(t: Transcript, count: Int = 5): List<ClipPlan> {
        val lines = t.lines()
        if (lines.isEmpty()) return emptyList()
        val cands = mutableListOf<ClipPlan>()
        for (i in lines.indices) {
            var j = i
            while (j + 1 < lines.size && lines[j + 1].end - lines[i].start <= 45.0) j++
            val window = lines.subList(i, j + 1)
            val len = window.last().end - window.first().start
            if (len < Clips.MIN) continue
            val words = window.flatMap { it.words }
            val pace = words.size / len
            val text = window.joinToString(" ") { it.text }.lowercase(Locale.ROOT)
            val strong = words.count { it.text.lowercase(Locale.ROOT).trim('.', ',', '!', '?') in STRONG }
            val qs = text.count { it == '?' }
            val ex = text.count { it == '!' }
            val nums = Regex("\\d+").findAll(text).count()
            val conf = words.map { it.conf }.average()
            // A strong opening line matters most for shorts.
            val opener = window.first().words.count { it.text.lowercase(Locale.ROOT).trim('.', ',', '!', '?') in STRONG } * 3
            val score = (pace * 12 + strong * 4 + qs * 5 + ex * 4 + nums * 2 + opener + conf * 10).toInt().coerceIn(1, 100)
            val first = window.first().text
            cands += ClipPlan(window.first().start, window.last().end, title(first), first, listOf("shorts"), score,
                "Fast, punchy section with a strong opening line.", first)
        }
        return Clips.tidy(cands, t, count)
    }

    private fun title(s: String): String {
        val t = s.trim().split(" ").take(9).joinToString(" ")
        return t.replaceFirstChar { it.titlecase(Locale.ROOT) }.trimEnd('.', ',') + if (s.split(" ").size > 9) "..." else ""
    }
}
