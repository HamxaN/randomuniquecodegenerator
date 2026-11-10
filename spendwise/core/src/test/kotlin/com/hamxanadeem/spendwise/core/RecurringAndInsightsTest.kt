package com.hamxanadeem.spendwise.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.LocalDate
import java.time.YearMonth

class RecurringAndInsightsTest {

    @Test
    fun `monthly rules keep the day, even after short months`() {
        val r = Recurring("r", 1000, Kind.EXPENSE, "bills", "Rent", LocalDate.of(2026, 1, 31), Every.MONTHLY)
        val due = r.due(LocalDate.of(2026, 4, 30))
        assertEquals(listOf(LocalDate.of(2026, 1, 31), LocalDate.of(2026, 2, 28), LocalDate.of(2026, 3, 31), LocalDate.of(2026, 4, 30)), due)
        assertEquals(LocalDate.of(2026, 5, 31), r.copy(lastPosted = LocalDate.of(2026, 4, 30)).next(LocalDate.of(2026, 4, 30)))
    }

    @Test
    fun `due rules are posted once`() {
        val l = Ledger()
        l.recurring += Recurring("r", 1599, Kind.EXPENSE, "subscriptions", "Netflix", LocalDate.of(2026, 9, 5), Every.MONTHLY)
        val first = l.postDue(LocalDate.of(2026, 11, 9), 0, Fixtures::id)
        assertEquals(3, first.size)
        assertTrue(first.all { it.recurringId == "r" })
        assertEquals(0, l.postDue(LocalDate.of(2026, 11, 9), 0, Fixtures::id).size)
        assertEquals(1, l.postDue(LocalDate.of(2026, 12, 5), 0, Fixtures::id).size)
    }

    @Test
    fun `subscriptions are found in the history`() {
        val l = Ledger()
        for (m in 0..4) l.txns += Fixtures.txn(1599, "subscriptions", "Netflix", LocalDate.of(2026, 6, 14).plusMonths(m.toLong()))
        for (w in 0..5) l.txns += Fixtures.txn(1200L + w * 10, "fun", "Squash club", LocalDate.of(2026, 9, 28).plusWeeks(w.toLong()))
        // Irregular spending isn't a subscription.
        for (x in listOf(1, 4, 20, 22, 50)) l.txns += Fixtures.txn(800, "food", "Lunch", LocalDate.of(2026, 8, 1).plusDays(x.toLong()))
        // A gym that stopped in the summer is cancelled.
        for (m in 0..3) l.txns += Fixtures.txn(3000, "subscriptions", "Gym", LocalDate.of(2026, 2, 3).plusMonths(m.toLong()))
        val subs = Insights.subscriptions(l, LocalDate.of(2026, 11, 9))
        assertEquals(listOf("Squash club", "Netflix"), subs.map { it.name })
        val netflix = subs.first { it.name == "Netflix" }
        assertEquals(Every.MONTHLY, netflix.every)
        assertEquals(LocalDate.of(2026, 11, 14), netflix.next)
        assertEquals(1599L * 12, netflix.yearly)
        assertEquals(Every.WEEKLY, subs.first().every)
    }

    @Test
    fun `unusually large expenses stand out`() {
        val l = Ledger()
        for (i in 1..8) l.txns += Fixtures.txn(1000L + i * 50, "food", "Lunch", LocalDate.of(2026, 10, i))
        val big = Fixtures.txn(9000, "food", "Wedding dinner", LocalDate.of(2026, 11, 4))
        l.txns += big
        l.txns += Fixtures.txn(1300, "food", "Lunch", LocalDate.of(2026, 11, 5))
        assertEquals(listOf(big), Insights.anomalies(l, YearMonth.of(2026, 11)))
    }

    @Test
    fun `the forecast adds the usual pace and payments still to come`() {
        val l = Ledger()
        val nov = YearMonth.of(2026, 11)
        for (d in 1..10) l.txns += Fixtures.txn(1000, "food", "Lunch", LocalDate.of(2026, 11, d))
        l.recurring += Recurring("r", 50000, Kind.EXPENSE, "bills", "Rent", LocalDate.of(2026, 1, 25), Every.MONTHLY,
            LocalDate.of(2026, 10, 25))
        val f = Insights.forecast(l, nov, LocalDate.of(2026, 11, 10))
        // 100 so far, 10/day for 20 more days, 500 rent on the 25th.
        assertEquals(10000L + 20000L + 50000L, f)
        // A past month's forecast is just its total.
        assertEquals(0L, Insights.forecast(l, YearMonth.of(2026, 10), LocalDate.of(2026, 11, 10)))
    }

    @Test
    fun `cards put the most urgent first`() {
        val l = Ledger()
        l.upsertCategory(l.category("fun")!!.copy(budget = 5000))
        l.txns += Fixtures.txn(200000, "salary", "Salary", LocalDate.of(2026, 11, 1), Kind.INCOME)
        l.txns += Fixtures.txn(7000, "fun", "Concert", LocalDate.of(2026, 11, 3))
        val cards = Insights.cards(l, LocalDate.of(2026, 11, 9)) { "$" + it / 100 }
        assertEquals(Insight.Type.BUDGET, cards.first().kind)
        assertTrue(cards.any { it.kind == Insight.Type.FORECAST })
        assertTrue(cards.any { it.kind == Insight.Type.SAVING })
    }

    @Test
    fun `trends compare the same days of last month`() {
        val l = Ledger()
        l.txns += Fixtures.txn(10000, "transport", "Fuel", LocalDate.of(2026, 10, 5))
        l.txns += Fixtures.txn(99999, "transport", "Fuel", LocalDate.of(2026, 10, 25)) // after the 9th: ignored
        l.txns += Fixtures.txn(15000, "transport", "Fuel", LocalDate.of(2026, 11, 5))
        val t = Insights.trends(l, YearMonth.of(2026, 11), LocalDate.of(2026, 11, 9)).single()
        assertEquals("transport", t.first)
        assertEquals(0.5, t.second, 1e-9)
    }
}
