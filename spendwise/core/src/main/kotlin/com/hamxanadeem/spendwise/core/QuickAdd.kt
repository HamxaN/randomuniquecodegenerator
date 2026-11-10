package com.hamxanadeem.spendwise.core

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.Month
import java.time.format.TextStyle
import java.util.Locale

/** What the quick-add box understood. Anything it couldn't find is null. */
data class Draft(
    val amount: Long?,
    val kind: Kind,
    val note: String,
    val date: LocalDate,
    val categoryId: String?,
)

/**
 * Understands short natural sentences such as
 * "coffee 4.50", "uber 12 yesterday", "salary 3500 on 1st",
 * "rent 1,200 last monday", "+50 refund" or "groceries 23.40 12 mar".
 */
object QuickAdd {

    private val INCOME_WORDS = setOf("salary", "income", "received", "receive", "refund", "refunded", "paycheck", "bonus",
        "earned", "cashback", "dividend", "interest", "reimbursed", "reimbursement", "got paid", "payment received")
    private val FILLER = setOf("on", "for", "at", "spent", "paid", "pay", "bought", "today", "yesterday", "ago", "last", "this",
        "days", "day", "the", "of", "rs", "rs.", "usd", "eur", "gbp", "pkr", "inr", "aed", "dollars", "dollar", "bucks", "rupees")

    fun parse(text: String, today: LocalDate, ledger: Ledger, categorizer: Categorizer): Draft {
        var rest = " " + text.trim() + " "
        val lower = rest.lowercase(Locale.ROOT)

        // Date words first, so their numbers aren't taken for the amount.
        var date = today
        fun take(regex: Regex, f: (MatchResult) -> LocalDate?): Boolean {
            val m = regex.find(rest.lowercase(Locale.ROOT)) ?: return false
            val d = f(m) ?: return false
            date = d
            rest = rest.removeRange(m.range).let { " $it " }
            return true
        }
        take(Regex("\\b(\\d{4})-(\\d{1,2})-(\\d{1,2})\\b")) { m ->
            runCatching { LocalDate.of(m.groupValues[1].toInt(), m.groupValues[2].toInt(), m.groupValues[3].toInt()) }.getOrNull()
        } ||
            take(Regex("\\bday before yesterday\\b")) { today.minusDays(2) } ||
            take(Regex("\\byesterday\\b|\\byday\\b")) { today.minusDays(1) } ||
            take(Regex("\\btoday\\b")) { today } ||
            take(Regex("\\b(\\d{1,2}) days? ago\\b")) { today.minusDays(it.groupValues[1].toLong()) } ||
            take(Regex("\\b(?:last |on )?(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)(?:day|nesday|sday|urday)?\\b")) { m ->
                val dow = weekday(m.groupValues[1]) ?: return@take null
                var d = today.minusDays(1)
                while (d.dayOfWeek != dow) d = d.minusDays(1)
                d
            } ||
            take(Regex("\\b(?:on )?(\\d{1,2})(?:st|nd|rd|th)? (jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\\b")) { m ->
                dayMonth(m.groupValues[1].toInt(), m.groupValues[2], today)
            } ||
            take(Regex("\\b(?:on )?(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]* (\\d{1,2})(?:st|nd|rd|th)?\\b")) { m ->
                dayMonth(m.groupValues[2].toInt(), m.groupValues[1], today)
            } ||
            take(Regex("\\bon (?:the )?(\\d{1,2})(?:st|nd|rd|th)\\b")) { m ->
                val day = m.groupValues[1].toInt()
                if (day !in 1..31) return@take null
                var d = today.withDayOfMonth(minOf(day, today.lengthOfMonth()))
                if (d.isAfter(today)) d = today.minusMonths(1).let { it.withDayOfMonth(minOf(day, it.lengthOfMonth())) }
                d
            }

        // Income if it starts with "+" or uses an income word.
        val plus = rest.trimStart().startsWith("+")
        var kind = if (plus || INCOME_WORDS.any { w -> Regex("\\b${Regex.escape(w)}\\b").containsMatchIn(lower) }) Kind.INCOME else Kind.EXPENSE
        if (rest.trimStart().startsWith("-")) kind = Kind.EXPENSE

        // The amount: the first number, with optional currency sign and "k".
        var amount: Long? = null
        val num = Regex("(?<![\\p{L}\\d])[+-]?[$€£₹¥₨]?\\s?(\\d[\\d.,]*\\d|\\d)(k)?(?![\\p{L}\\d])", RegexOption.IGNORE_CASE).find(rest)
        if (num != null) {
            amount = Money.parse(num.groupValues[1] + num.groupValues[2], ledger.currency)
            rest = rest.removeRange(num.range)
        }

        val words = rest.split(Regex("\\s+")).filter { it.isNotBlank() }
            .map { it.trim('+', '-', '$', '€', '£', '₹', ',', '.') }
            .filter { it.isNotEmpty() && it.lowercase(Locale.ROOT) !in FILLER }
        val note = words.joinToString(" ").replaceFirstChar { it.titlecase(Locale.getDefault()) }
        val category = if (note.isEmpty()) null else categorizer.best(note, kind)
        return Draft(amount?.takeIf { it > 0 }, kind, note, date, category)
    }

    private fun weekday(s: String): DayOfWeek? = DayOfWeek.entries.firstOrNull {
        it.getDisplayName(TextStyle.FULL, Locale.ENGLISH).lowercase().startsWith(s.take(3))
    }

    private fun dayMonth(day: Int, mon: String, today: LocalDate): LocalDate? {
        val month = Month.entries.firstOrNull { it.getDisplayName(TextStyle.FULL, Locale.ENGLISH).lowercase().startsWith(mon.take(3)) }
            ?: return null
        var d = runCatching { LocalDate.of(today.year, month, day) }.getOrNull() ?: return null
        // "12 dec" in January means last December.
        if (d.isAfter(today)) d = d.minusYears(1)
        return d
    }
}
