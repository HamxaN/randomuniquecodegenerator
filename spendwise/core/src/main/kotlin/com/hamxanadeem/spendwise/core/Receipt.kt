package com.hamxanadeem.spendwise.core

import java.time.LocalDate
import java.time.Month
import java.time.format.TextStyle
import java.util.Locale

/** What could be read off a receipt photo. */
data class ReceiptGuess(val amount: Long?, val date: LocalDate?, val merchant: String?)

/**
 * Picks the total, date and shop name out of the text lines that on-device
 * text recognition read from a receipt.
 */
object Receipt {

    private val TOTAL = Regex("\\b(grand\\s*total|total\\s*due|amount\\s*due|balance\\s*due|total\\s*amount|net\\s*total|total|amount|to\\s*pay|payable)\\b", RegexOption.IGNORE_CASE)
    private val NOT_TOTAL = Regex("\\b(sub\\s*-?\\s*total|subtotal|tax|vat|gst|tip|change|cash|tendered|discount|saving|savings|points|qty|items?)\\b", RegexOption.IGNORE_CASE)
    private val MONEY = Regex("(?<![\\d.,])(\\d{1,3}(?:[,. ]\\d{3})*(?:[.,]\\d{2})|\\d+(?:[.,]\\d{2}))(?![\\d])")
    private val SKIP_MERCHANT = Regex("(receipt|invoice|tax|tel|phone|www\\.|http|@|\\d{3,}|date|time|cashier|order|table|thank)", RegexOption.IGNORE_CASE)

    fun read(lines: List<String>, today: LocalDate, currency: String): ReceiptGuess =
        ReceiptGuess(total(lines, currency), date(lines, today), merchant(lines))

    fun total(lines: List<String>, currency: String): Long? {
        // Prefer the amount on (or just after) a "total" line, taking the last such line.
        for (i in lines.indices.reversed()) {
            val line = lines[i]
            if (!TOTAL.containsMatchIn(line) || NOT_TOTAL.containsMatchIn(line)) continue
            val here = amounts(line, currency)
            if (here.isNotEmpty()) return here.last()
            val next = lines.getOrNull(i + 1)?.let { amounts(it, currency) }.orEmpty()
            if (next.isNotEmpty()) return next.first()
        }
        // Otherwise the largest money-looking number.
        return lines.flatMap { amounts(it, currency) }.maxOrNull()
    }

    private fun amounts(line: String, currency: String): List<Long> =
        MONEY.findAll(line).mapNotNull { Money.parse(it.groupValues[1].replace(" ", ""), currency) }.filter { it > 0 }.toList()

    fun date(lines: List<String>, today: LocalDate): LocalDate? {
        val text = lines.joinToString(" ")
        val candidates = mutableListOf<LocalDate>()
        Regex("\\b(\\d{4})[-/.](\\d{1,2})[-/.](\\d{1,2})\\b").findAll(text).forEach { m ->
            make(m.groupValues[1].toInt(), m.groupValues[2].toInt(), m.groupValues[3].toInt())?.let { candidates += it }
        }
        Regex("\\b(\\d{1,2})[-/.](\\d{1,2})[-/.](\\d{2,4})\\b").findAll(text).forEach { m ->
            val a = m.groupValues[1].toInt()
            val b = m.groupValues[2].toInt()
            var y = m.groupValues[3].toInt()
            if (y < 100) y += 2000
            // Day first unless that's impossible; month first as the other reading.
            val dayFirst = make(y, b, a)
            val monthFirst = make(y, a, b)
            listOfNotNull(dayFirst, monthFirst).filter { !it.isAfter(today) }.maxOrNull()?.let { candidates += it }
        }
        Regex("\\b(\\d{1,2})\\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\.?,?\\s*(\\d{2,4})\\b", RegexOption.IGNORE_CASE).findAll(text).forEach { m ->
            val y = m.groupValues[3].toInt().let { if (it < 100) it + 2000 else it }
            month(m.groupValues[2])?.let { mo -> make(y, mo, m.groupValues[1].toInt())?.let { candidates += it } }
        }
        Regex("\\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\.?\\s*(\\d{1,2}),?\\s*(\\d{4})\\b", RegexOption.IGNORE_CASE).findAll(text).forEach { m ->
            month(m.groupValues[1])?.let { mo -> make(m.groupValues[3].toInt(), mo, m.groupValues[2].toInt())?.let { candidates += it } }
        }
        // A receipt isn't from the future or from long ago.
        return candidates.firstOrNull { !it.isAfter(today) && it.isAfter(today.minusYears(2)) }
    }

    fun merchant(lines: List<String>): String? =
        lines.take(6).map { it.trim() }.firstOrNull { line ->
            line.length in 3..40 && line.count { it.isLetter() } >= 3 && !SKIP_MERCHANT.containsMatchIn(line)
        }?.let { name -> name.lowercase().split(' ').joinToString(" ") { w -> w.replaceFirstChar { it.titlecase() } } }

    private fun make(y: Int, m: Int, d: Int): LocalDate? = runCatching { LocalDate.of(y, m, d) }.getOrNull()

    private fun month(s: String): Int? =
        Month.entries.firstOrNull { it.getDisplayName(TextStyle.FULL, Locale.ENGLISH).lowercase().startsWith(s.lowercase().take(3)) }?.value
}
