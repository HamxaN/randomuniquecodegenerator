package com.hamxanadeem.spendwise.core

import kotlin.math.ln

/**
 * Suggests a category for a note like "Uber to airport". It starts from each
 * category's keywords and learns from what the person actually chose (a small
 * naive Bayes model over the words in past notes), so corrections stick.
 * Everything runs on the device.
 */
class Categorizer(private val ledger: Ledger) {

    private class Model(val wordCounts: Map<String, Map<String, Int>>, val catTotals: Map<String, Int>, val vocab: Int, val exact: Map<String, String>)

    private val models = mutableMapOf<Kind, Model>()

    private fun model(kind: Kind): Model = models.getOrPut(kind) {
        val words = mutableMapOf<String, MutableMap<String, Int>>()
        val totals = mutableMapOf<String, Int>()
        val vocab = mutableSetOf<String>()
        val exactVotes = mutableMapOf<String, MutableMap<String, Int>>()
        for (t in ledger.txns) {
            if (t.kind != kind || t.note.isBlank()) continue
            val toks = tokens(t.note)
            for (w in toks) {
                words.getOrPut(t.categoryId) { mutableMapOf() }.merge(w, 1, Int::plus)
                totals.merge(t.categoryId, 1, Int::plus)
                vocab += w
            }
            val key = normalize(t.note)
            if (key.isNotEmpty()) exactVotes.getOrPut(key) { mutableMapOf() }.merge(t.categoryId, 1, Int::plus)
        }
        val exact = exactVotes.mapValues { (_, v) -> v.maxByOrNull { it.value }!!.key }
        Model(words, totals, vocab.size.coerceAtLeast(1), exact)
    }

    /** Categories of [kind], best guess first. Never empty if the kind has categories. */
    fun suggest(note: String, kind: Kind): List<String> {
        val cats = ledger.categoriesOf(kind)
        if (cats.isEmpty()) return emptyList()
        val m = model(kind)
        val toks = tokens(note)
        val lower = " " + note.lowercase() + " "
        // The same note as before? Use what was picked last time.
        m.exact[normalize(note)]?.let { hit -> if (cats.any { it.id == hit }) return listOf(hit) + cats.map { it.id }.filter { it != hit } }
        val scores = cats.associate { c ->
            var s = 0.0
            for (k in c.keywords) {
                if (lower.contains(" ${k.lowercase()} ") || toks.contains(k.lowercase())) s += 4.0 + k.length * 0.05
            }
            val counts = m.wordCounts[c.id]
            val total = m.catTotals[c.id] ?: 0
            if (total > 0 && toks.isNotEmpty()) {
                var lp = 0.0
                for (w in toks) lp += ln(((counts?.get(w) ?: 0) + 0.5) / (total + 0.5 * m.vocab))
                // Compare with a category that has never seen these words.
                var base = 0.0
                for (w in toks) base += ln(0.5 / (0.5 * m.vocab + 1))
                s += (lp - base).coerceAtLeast(0.0) * 0.8 + ln(1.0 + total) * 0.05
            }
            c.id to s
        }
        val best = scores.filter { it.value > 0.0 }.entries.sortedByDescending { it.value }.map { it.key }
        val fallback = if (kind == Kind.EXPENSE) Defaults.FALLBACK_EXPENSE else Defaults.FALLBACK_INCOME
        val rest = cats.map { it.id }.filter { it !in best }.sortedBy { if (it == fallback) 0 else 1 }
        return best + rest
    }

    fun best(note: String, kind: Kind): String? = suggest(note, kind).firstOrNull()

    companion object {
        private val STOP = setOf("the", "a", "an", "to", "for", "at", "on", "in", "of", "and", "with", "from", "my", "paid", "spent", "bought", "buy", "got")

        fun tokens(text: String): List<String> =
            text.lowercase().split(Regex("[^\\p{L}\\p{N}&]+")).filter { it.length >= 2 && it !in STOP && it.any { c -> c.isLetter() } }

        /** "Netflix #1234" and "netflix" become the same key. */
        fun normalize(text: String): String = tokens(text).filter { w -> w.none { it.isDigit() } }.joinToString(" ")
    }
}
