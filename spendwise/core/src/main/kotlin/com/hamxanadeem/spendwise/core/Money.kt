package com.hamxanadeem.spendwise.core

import java.math.BigDecimal
import java.math.RoundingMode
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

/** Money is kept in whole minor units (cents, paisa) so sums never drift. */
object Money {

    fun digits(currency: String): Int =
        runCatching { Currency.getInstance(currency).defaultFractionDigits }.getOrDefault(2).coerceAtLeast(0)

    /** Minor units from a decimal amount, e.g. 12.5 USD -> 1250. */
    fun toMinor(amount: BigDecimal, currency: String): Long =
        amount.setScale(digits(currency), RoundingMode.HALF_UP).movePointRight(digits(currency)).toLong()

    fun toDecimal(minor: Long, currency: String): BigDecimal = BigDecimal.valueOf(minor, digits(currency))

    /** Reads what a person typed, accepting "1,234.50", "1.234,50", "12" or "1.2k". Null if it isn't a number. */
    fun parse(text: String, currency: String): Long? {
        var s = text.trim().lowercase(Locale.ROOT).replace(" ", "").replace(" ", "")
        if (s.isEmpty()) return null
        var mult = BigDecimal.ONE
        if (s.endsWith("k")) {
            mult = BigDecimal(1000)
            s = s.dropLast(1)
        }
        s = s.filter { it.isDigit() || it == '.' || it == ',' }
        if (s.isEmpty() || s.none { it.isDigit() }) return null
        val lastDot = s.lastIndexOf('.')
        val lastComma = s.lastIndexOf(',')
        s = when {
            lastDot >= 0 && lastComma >= 0 ->
                if (lastDot > lastComma) s.replace(",", "") else s.replace(".", "").replace(',', '.')
            lastComma >= 0 -> {
                // "12,50" is a decimal comma; "1,250" groups thousands.
                val tail = s.length - lastComma - 1
                if (tail in 1..2 && s.count { it == ',' } == 1) s.replace(',', '.') else s.replace(",", "")
            }
            lastDot >= 0 && s.count { it == '.' } > 1 -> s.replace(".", "")
            else -> s
        }
        val value = s.toBigDecimalOrNull() ?: return null
        return toMinor(value.multiply(mult), currency)
    }

    /** "$1,234.50", "Rs 1,234", "1.234,50 €" — in the person's own locale style. */
    fun format(minor: Long, currency: String, locale: Locale = Locale.getDefault()): String {
        val f = NumberFormat.getCurrencyInstance(locale)
        runCatching { f.currency = Currency.getInstance(currency) }
        f.minimumFractionDigits = digits(currency)
        f.maximumFractionDigits = digits(currency)
        return f.format(toDecimal(minor, currency))
    }

    /** A short form for charts and tiles: "$1.2k", "$15k", "$3.4M". */
    fun short(minor: Long, currency: String, locale: Locale = Locale.getDefault()): String {
        val whole = toDecimal(minor, currency).toDouble()
        val a = kotlin.math.abs(whole)
        if (a < 1000) {
            // Whole units only on small chart labels.
            val f = NumberFormat.getCurrencyInstance(locale)
            runCatching { f.currency = Currency.getInstance(currency) }
            f.maximumFractionDigits = 0
            f.minimumFractionDigits = 0
            return f.format(Math.round(whole))
        }
        val (v, unit) = if (a >= 1_000_000) whole / 1_000_000 to "M" else whole / 1000 to "k"
        val f = NumberFormat.getCurrencyInstance(locale)
        runCatching { f.currency = Currency.getInstance(currency) }
        f.maximumFractionDigits = if (kotlin.math.abs(v) < 10) 1 else 0
        f.minimumFractionDigits = 0
        return f.format(v) + unit
    }
}
