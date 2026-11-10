package com.hamxanadeem.spendwise.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import java.time.LocalDate
import java.util.Locale

class MoneyAndQuickAddTest {

    private val today = LocalDate.of(2026, 11, 9) // a Monday

    @Test
    fun `amounts are read in many styles`() {
        assertEquals(1250L, Money.parse("12.50", "USD"))
        assertEquals(123450L, Money.parse("1,234.50", "USD"))
        assertEquals(123450L, Money.parse("1.234,50", "EUR"))
        assertEquals(1250L, Money.parse("12,50", "EUR"))
        assertEquals(125000L, Money.parse("1,250", "USD"))
        assertEquals(120000L, Money.parse("1.2k", "USD"))
        assertEquals(500L, Money.parse("500", "JPY"))
        assertNull(Money.parse("abc", "USD"))
        assertNull(Money.parse("", "USD"))
    }

    @Test
    fun `money is formatted for the reader`() {
        assertEquals("$1,234.50", Money.format(123450, "USD", Locale.US))
        assertEquals("$1.2k", Money.short(123450, "USD", Locale.US))
        assertEquals("$999", Money.short(99900, "USD", Locale.US))
    }

    private fun parse(text: String): Draft {
        val ledger = Ledger()
        return QuickAdd.parse(text, today, ledger, Categorizer(ledger))
    }

    @Test
    fun `simple expenses`() {
        val d = parse("coffee 4.50")
        assertEquals(450L, d.amount)
        assertEquals(Kind.EXPENSE, d.kind)
        assertEquals("Coffee", d.note)
        assertEquals(today, d.date)
        assertEquals("food", d.categoryId)
        assertEquals("transport", parse("uber 12 to airport").categoryId)
        assertEquals("groceries", parse("$23.40 at Walmart").categoryId)
    }

    @Test
    fun `dates in words`() {
        assertEquals(today.minusDays(1), parse("uber 12 yesterday").date)
        assertEquals(today.minusDays(3), parse("lunch 8 3 days ago").date)
        assertEquals(LocalDate.of(2026, 11, 6), parse("pizza 15 last friday").date)
        assertEquals(LocalDate.of(2026, 11, 2), parse("taxi 9 monday").date)
        assertEquals(LocalDate.of(2026, 3, 12), parse("groceries 23.40 12 mar").date)
        assertEquals(LocalDate.of(2025, 12, 24), parse("gift 40 dec 24").date)
        assertEquals(LocalDate.of(2026, 11, 1), parse("rent 1,200 on 1st").date)
        assertEquals(LocalDate.of(2026, 10, 15), parse("gym 30 on 15th").date)
        assertEquals(LocalDate.of(2026, 9, 30), parse("2026-09-30 books 20").date)
        assertEquals(120000L, parse("rent 1,200 on 1st").amount)
        assertEquals(2340L, parse("groceries 23.40 12 mar").amount)
    }

    @Test
    fun `income is recognised`() {
        val salary = parse("salary 3500")
        assertEquals(Kind.INCOME, salary.kind)
        assertEquals("salary", salary.categoryId)
        assertEquals(Kind.INCOME, parse("+50 refund from amazon").kind)
        assertEquals(5000L, parse("+50 refund from amazon").amount)
    }

    @Test
    fun `no number means no amount`() {
        assertNull(parse("coffee").amount)
        assertEquals(150000L, parse("laptop 1.5k").amount)
    }
}
