package com.hamxanadeem.scamradar.core

import java.util.Locale

/** Text clean-up so tricks like Urdu digits, zero-width spaces or s p a c e d letters don't hide words. */
object Normalize {
    private val URDU_DIGITS = "۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩"
    private val INVISIBLE = Regex("[\\u200B-\\u200F\\u202A-\\u202E\\u2060\\uFEFF]")

    fun text(raw: String): String {
        val sb = StringBuilder(raw.length)
        for (ch in raw.replace(INVISIBLE, "")) {
            val i = URDU_DIGITS.indexOf(ch)
            sb.append(if (i >= 0) ('0' + i % 10) else ch)
        }
        return sb.toString()
            .lowercase(Locale.ROOT)
            .replace('’', '\'')
            .replace(Regex("[ \\t]+"), " ")
    }

    /** Lower-case words (Latin letters, digits and Urdu letters), for word matching. */
    fun words(norm: String): Set<String> =
        Regex("[\\p{L}\\p{N}]+").findAll(norm).map { it.value }.toSet()

    /** True if any phrase appears. Single short Latin words must match a whole word. */
    fun hasAny(norm: String, words: Set<String>, phrases: List<String>): Boolean =
        phrases.any { has(norm, words, it) }

    fun has(norm: String, words: Set<String>, phrase: String): Boolean {
        val p = phrase.lowercase(Locale.ROOT)
        val latinWord = p.all { it.isLetterOrDigit() && it.code < 0x0600 }
        return if (latinWord) p in words else norm.contains(p)
    }

    fun count(norm: String, words: Set<String>, phrases: List<String>): Int = phrases.count { has(norm, words, it) }
}
