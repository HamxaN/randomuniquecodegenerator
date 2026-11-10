package com.hamxanadeem.spendwise.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import java.time.LocalDate
import java.time.YearMonth

class BudgetsTest {

    private val nov = YearMonth.of(2026, 11)

    private fun ledger(rollover: Boolean): Ledger {
        val l = Ledger()
        l.upsertCategory(l.category("food")!!.copy(budget = 30000, rollover = rollover))
        l.txns += Fixtures.txn(20000, "food", "groceries", LocalDate.of(2026, 9, 10)) // 100 left in Sep
        l.txns += Fixtures.txn(35000, "food", "party", LocalDate.of(2026, 10, 10)) // 50 over in Oct
        l.txns += Fixtures.txn(25000, "food", "restaurants", LocalDate.of(2026, 11, 5))
        return l
    }

    @Test
    fun `budgets show spending, what's left and a state`() {
        val s = Budgets.status(ledger(false), nov).single()
        assertEquals(25000L, s.spent)
        assertEquals(0L, s.carried)
        assertEquals(5000L, s.remaining)
        assertEquals(BudgetState.WARNING, s.state)
    }

    @Test
    fun `rollover carries leftovers and overspending forward`() {
        val s = Budgets.status(ledger(true), nov).single()
        // +100 from September, -50 from October.
        assertEquals(5000L, s.carried)
        assertEquals(35000L, s.available)
        assertEquals(10000L, s.remaining)
    }

    @Test
    fun `overspending is flagged`() {
        val l = ledger(false)
        l.txns += Fixtures.txn(10000, "food", "more", LocalDate.of(2026, 11, 6))
        assertEquals(BudgetState.OVER, Budgets.status(l, nov).single().state)
    }

    @Test
    fun `safe to spend spreads what's left over the days left`() {
        val l = ledger(false)
        // 50 left of budgets, 22 days left including the 9th.
        assertEquals(5000L / 22, Budgets.safeToSpendPerDay(l, nov, LocalDate.of(2026, 11, 9)))
        val noBudget = Ledger()
        noBudget.txns += Fixtures.txn(300000, "salary", "Salary", LocalDate.of(2026, 11, 1), Kind.INCOME)
        noBudget.txns += Fixtures.txn(80000, "bills", "Rent", LocalDate.of(2026, 11, 2))
        assertEquals(220000L / 22, Budgets.safeToSpendPerDay(noBudget, nov, LocalDate.of(2026, 11, 9)))
        noBudget.txns += Fixtures.txn(999999, "shopping", "TV", LocalDate.of(2026, 11, 3))
        assertEquals(0L, Budgets.safeToSpendPerDay(noBudget, nov, LocalDate.of(2026, 11, 9)))
    }
}
