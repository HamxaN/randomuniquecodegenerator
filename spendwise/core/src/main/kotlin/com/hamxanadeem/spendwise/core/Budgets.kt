package com.hamxanadeem.spendwise.core

import java.time.LocalDate
import java.time.YearMonth

enum class BudgetState { OK, WARNING, OVER }

/** Where a category's budget stands this month. */
data class BudgetStatus(
    val category: Category,
    val budget: Long,
    val carried: Long,
    val spent: Long,
) {
    /** What this month allows: the budget plus anything carried over (which can be negative). */
    val available: Long get() = budget + carried
    val remaining: Long get() = available - spent
    val fraction: Double get() = if (available <= 0) (if (spent > 0) 2.0 else 0.0) else spent.toDouble() / available
    val state: BudgetState
        get() = when {
            fraction > 1.0 -> BudgetState.OVER
            fraction >= Budgets.WARN_AT -> BudgetState.WARNING
            else -> BudgetState.OK
        }
}

object Budgets {
    const val WARN_AT = 0.8

    /** How far back rollover looks. */
    const val ROLLOVER_MONTHS = 12

    /** Every expense category with a budget, for [month]. */
    fun status(ledger: Ledger, month: YearMonth): List<BudgetStatus> =
        ledger.categoriesOf(Kind.EXPENSE).filter { it.budget > 0 }.map { status(ledger, it, month) }

    fun status(ledger: Ledger, c: Category, month: YearMonth): BudgetStatus {
        val spent = spent(ledger, c.id, month)
        return BudgetStatus(c, c.budget, if (c.rollover) carried(ledger, c, month) else 0, spent)
    }

    fun spent(ledger: Ledger, categoryId: String, month: YearMonth): Long =
        ledger.txns.filter { it.kind == Kind.EXPENSE && it.categoryId == categoryId && month.contains(it.date) }.sumOf { it.amount }

    /**
     * Envelope rollover: what was left (or overspent) in earlier months carries
     * forward, starting from the first month with spending in this category.
     */
    fun carried(ledger: Ledger, c: Category, month: YearMonth): Long {
        val first = ledger.txns.filter { it.kind == Kind.EXPENSE && it.categoryId == c.id }.minOfOrNull { YearMonth.from(it.date) }
            ?: return 0
        var m = maxOf(first, month.minusMonths(ROLLOVER_MONTHS.toLong()))
        var carry = 0L
        while (m.isBefore(month)) {
            carry += c.budget - spent(ledger, c.id, m)
            m = m.plusMonths(1)
        }
        return carry
    }

    /**
     * How much can be spent per day for the rest of [month] and stay within
     * budget: what's left of all budgets (or, with no budgets, of this month's
     * income) spread over the days left including today. Never negative.
     */
    fun safeToSpendPerDay(ledger: Ledger, month: YearMonth, today: LocalDate): Long {
        val daysLeft = if (month.contains(today)) (month.lengthOfMonth() - today.dayOfMonth + 1).toLong() else month.lengthOfMonth().toLong()
        val statuses = status(ledger, month)
        val left = if (statuses.isNotEmpty()) {
            val unbudgeted = ledger.inMonth(month, Kind.EXPENSE).filter { t -> statuses.none { it.category.id == t.categoryId } }.sumOf { it.amount }
            statuses.sumOf { it.remaining } - unbudgeted
        } else {
            ledger.total(month, Kind.INCOME) - ledger.total(month, Kind.EXPENSE)
        }
        return (left / daysLeft).coerceAtLeast(0)
    }
}
