package com.hamxanadeem.spendwise.core

import java.time.LocalDate
import java.time.YearMonth
import kotlin.math.abs

/** A short, ranked observation for the home screen. */
data class Insight(val kind: Type, val title: String, val detail: String, val categoryId: String? = null, val weight: Double = 0.0) {
    enum class Type { FORECAST, BUDGET, TREND, ANOMALY, SUBSCRIPTION, SAVING }
}

/** A repeating payment found in the history. */
data class Subscription(
    val name: String,
    val amount: Long,
    val every: Every,
    val last: LocalDate,
    val next: LocalDate,
    val categoryId: String,
    val count: Int,
) {
    val yearly: Long get() = Math.round(amount * every.perYear)
}

object Insights {

    /** Spending per category in [month], biggest first. */
    fun byCategory(ledger: Ledger, month: YearMonth, kind: Kind = Kind.EXPENSE): List<Pair<String, Long>> =
        ledger.inMonth(month, kind).groupBy { it.categoryId }.mapValues { (_, v) -> v.sumOf { it.amount } }
            .entries.sortedByDescending { it.value }.map { it.key to it.value }

    /** Spending on each day of [month] (index 0 = the 1st). */
    fun daily(ledger: Ledger, month: YearMonth): LongArray {
        val out = LongArray(month.lengthOfMonth())
        for (t in ledger.inMonth(month, Kind.EXPENSE)) out[t.date.dayOfMonth - 1] += t.amount
        return out
    }

    /** Income and spending for the [count] months up to [month], oldest first. */
    fun months(ledger: Ledger, month: YearMonth, count: Int): List<Triple<YearMonth, Long, Long>> =
        (count - 1 downTo 0).map { k ->
            val m = month.minusMonths(k.toLong())
            Triple(m, ledger.total(m, Kind.INCOME), ledger.total(m, Kind.EXPENSE))
        }

    /**
     * Where spending is heading by the end of [month]: what's spent so far, plus
     * repeating payments still to come, plus the usual day-to-day pace (from
     * one-off spending so far, steadied by the last three months' daily average).
     */
    fun forecast(ledger: Ledger, month: YearMonth, today: LocalDate): Long {
        if (!month.contains(today)) return ledger.total(month, Kind.EXPENSE)
        val spent = ledger.total(month, Kind.EXPENSE)
        val daysGone = today.dayOfMonth
        val daysLeft = month.lengthOfMonth() - daysGone
        val oneOff = ledger.inMonth(month, Kind.EXPENSE).filter { it.recurringId == null }.sumOf { it.amount }
        val pace = oneOff.toDouble() / daysGone
        val history = (1..3).map { month.minusMonths(it.toLong()) }.filter { ledger.inMonth(it, Kind.EXPENSE).isNotEmpty() }
        val histPace = if (history.isEmpty()) pace else history.sumOf { m ->
            ledger.inMonth(m, Kind.EXPENSE).filter { it.recurringId == null }.sumOf { it.amount }.toDouble() / m.lengthOfMonth()
        } / history.size
        // Early in the month, lean on history; later, on this month's own pace.
        val w = (daysGone / 15.0).coerceIn(0.2, 1.0)
        val blended = pace * w + histPace * (1 - w)
        val upcoming = ledger.recurring.filter { it.kind == Kind.EXPENSE }.sumOf { r ->
            var n = 0L
            var sum = 0L
            while (true) {
                val d = r.every.nth(r.start, n++)
                if (d.isAfter(month.atEndOfMonth())) break
                if (d.isAfter(today) && month.contains(d)) sum += r.amount
            }
            sum
        }
        return spent + upcoming + Math.round(blended * daysLeft)
    }

    /**
     * Unusual expenses in [month]: much bigger than what's normal for their
     * category (more than 3x the median and well above the typical spread).
     * Needs at least 5 earlier expenses in the category to judge.
     */
    fun anomalies(ledger: Ledger, month: YearMonth): List<Txn> {
        val out = mutableListOf<Txn>()
        val byCat = ledger.txns.filter { it.kind == Kind.EXPENSE }.groupBy { it.categoryId }
        for ((_, list) in byCat) {
            val before = list.filter { it.date.isBefore(month.atDay(1)) }.map { it.amount.toDouble() }.sorted()
            if (before.size < 5) continue
            val med = median(before)
            val mad = median(before.map { abs(it - med) }.sorted()).coerceAtLeast(med * 0.1)
            for (t in list) {
                if (!month.contains(t.date) || t.recurringId != null) continue
                if (t.amount > med * 3 && t.amount > med + 5 * mad) out += t
            }
        }
        return out.sortedByDescending { it.amount }
    }

    /**
     * Repeating payments hidden in the history: the same payee about every
     * week, month or year, for about the same amount, at least three times,
     * still active. Ones already set up as repeating rules are left out.
     */
    fun subscriptions(ledger: Ledger, today: LocalDate): List<Subscription> {
        val groups = ledger.txns.filter { it.kind == Kind.EXPENSE && it.recurringId == null }
            .groupBy { Categorizer.normalize(it.note) }.filterKeys { it.isNotEmpty() }
        val ruled = ledger.recurring.map { Categorizer.normalize(it.note) }.toSet()
        val out = mutableListOf<Subscription>()
        for ((key, list) in groups) {
            if (list.size < 3 || key in ruled) continue
            val sorted = list.sortedBy { it.date }
            val gaps = sorted.zipWithNext { a, b -> java.time.temporal.ChronoUnit.DAYS.between(a.date, b.date).toDouble() }
            val gap = median(gaps.sorted())
            val every = when {
                gap in 5.0..9.0 -> Every.WEEKLY
                gap in 26.0..35.0 -> Every.MONTHLY
                gap in 350.0..380.0 -> Every.YEARLY
                else -> continue
            }
            // Most gaps must agree.
            val tolerance = when (every) { Every.WEEKLY -> 2.0; Every.MONTHLY -> 5.0; Every.YEARLY -> 15.0 }
            if (gaps.count { abs(it - gap) <= tolerance } < gaps.size * 0.7) continue
            val amounts = sorted.map { it.amount.toDouble() }.sorted()
            val typical = median(amounts)
            if (sorted.count { abs(it.amount - typical) <= typical * 0.15 } < sorted.size * 0.7) continue
            val last = sorted.last()
            val nextDate = every.nth(last.date, 1)
            // Gone quiet for one and a half cycles? Probably cancelled.
            if (java.time.temporal.ChronoUnit.DAYS.between(last.date, today) > gap * 1.5) continue
            out += Subscription(last.note, Math.round(typical), every, last.date, nextDate, last.categoryId, sorted.size)
        }
        return out.sortedByDescending { it.yearly }
    }

    /** How spending in each category compares with the same days of last month. */
    fun trends(ledger: Ledger, month: YearMonth, today: LocalDate): List<Pair<String, Double>> {
        val upTo = if (month.contains(today)) today.dayOfMonth else month.lengthOfMonth()
        val prev = month.minusMonths(1)
        val now = ledger.inMonth(month, Kind.EXPENSE).filter { it.date.dayOfMonth <= upTo }.groupBy { it.categoryId }
            .mapValues { (_, v) -> v.sumOf { it.amount } }
        val before = ledger.inMonth(prev, Kind.EXPENSE).filter { it.date.dayOfMonth <= upTo }.groupBy { it.categoryId }
            .mapValues { (_, v) -> v.sumOf { it.amount } }
        return (now.keys + before.keys).mapNotNull { id ->
            val a = now[id] ?: 0
            val b = before[id] ?: 0
            if (b == 0L) null else id to (a - b).toDouble() / b
        }.sortedByDescending { abs(it.second) }
    }

    /** The home screen's handful of most useful observations, most important first. */
    fun cards(ledger: Ledger, today: LocalDate, fmt: (Long) -> String): List<Insight> {
        val month = YearMonth.from(today)
        val out = mutableListOf<Insight>()
        val name = { id: String -> ledger.category(id)?.name ?: "Other" }

        val forecast = forecast(ledger, month, today)
        val income = ledger.total(month, Kind.INCOME)
        val lastMonth = ledger.total(month.minusMonths(1), Kind.EXPENSE)
        if (ledger.inMonth(month, Kind.EXPENSE).isNotEmpty()) {
            val detail = when {
                income > 0 && forecast > income -> "That's ${fmt(forecast - income)} more than you've earned this month."
                lastMonth > 0 -> {
                    val d = (forecast - lastMonth).toDouble() / lastMonth
                    if (abs(d) < 0.03) "About the same as last month." else
                        "${if (d > 0) "Up" else "Down"} ${pct(d)} on last month's ${fmt(lastMonth)}."
                }
                else -> "Based on your spending so far."
            }
            out += Insight(Insight.Type.FORECAST, "On track to spend ${fmt(forecast)} this month", detail,
                weight = if (income > 0 && forecast > income) 9.0 else 5.0)
        }
        for (b in Budgets.status(ledger, month)) {
            when (b.state) {
                BudgetState.OVER -> out += Insight(Insight.Type.BUDGET, "${b.category.name} is over budget",
                    "${fmt(b.spent)} of ${fmt(b.available)} (${fmt(-b.remaining)} over).", b.category.id, 10.0)
                BudgetState.WARNING -> out += Insight(Insight.Type.BUDGET, "${b.category.name} is at ${pct(b.fraction)} of budget",
                    "${fmt(b.remaining)} left for the rest of the month.", b.category.id, 7.0)
                else -> Unit
            }
        }
        for (t in anomalies(ledger, month).take(2)) {
            out += Insight(Insight.Type.ANOMALY, "Unusually large: ${t.note.ifBlank { name(t.categoryId) }}",
                "${fmt(t.amount)} on ${t.date.dayOfMonth} ${t.date.month.name.lowercase().replaceFirstChar { it.uppercase() }.take(3)}, much more than your usual ${name(t.categoryId)} spend.",
                t.categoryId, 6.0)
        }
        trends(ledger, month, today).firstOrNull { abs(it.second) >= 0.25 }?.let { (id, d) ->
            out += Insight(Insight.Type.TREND, "${name(id)} ${if (d > 0) "up" else "down"} ${pct(d)}",
                "Compared with the same days last month.", id, 4.0 + abs(d))
        }
        val subs = subscriptions(ledger, today)
        if (subs.isNotEmpty()) {
            val yearly = subs.sumOf { it.yearly }
            out += Insight(Insight.Type.SUBSCRIPTION, "${subs.size} repeating payment${if (subs.size > 1) "s" else ""} found",
                "${subs.take(3).joinToString(", ") { it.name }}: about ${fmt(yearly)} a year.", weight = 3.0)
        }
        if (income > 0) {
            val spent = ledger.total(month, Kind.EXPENSE)
            val rate = (income - spent).toDouble() / income
            if (rate > 0.1) out += Insight(Insight.Type.SAVING, "You've kept ${pct(rate)} of this month's income",
                "${fmt(income - spent)} saved so far. Nice.", weight = 2.0)
        }
        return out.sortedByDescending { it.weight }
    }

    fun pct(d: Double): String = "${Math.round(abs(d) * 100)}%"

    private fun median(sorted: List<Double>): Double {
        if (sorted.isEmpty()) return 0.0
        val n = sorted.size
        return if (n % 2 == 1) sorted[n / 2] else (sorted[n / 2 - 1] + sorted[n / 2]) / 2
    }
}
