package com.hamxanadeem.spendwise.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.LocalDate

class CategorizerTest {

    private val d = LocalDate.of(2026, 10, 1)

    @Test
    fun `keywords give a first guess`() {
        val c = Categorizer(Ledger())
        assertEquals("subscriptions", c.best("Netflix", Kind.EXPENSE))
        assertEquals("health", c.best("pharmacy run", Kind.EXPENSE))
        assertEquals("other", c.best("zzzz", Kind.EXPENSE))
        assertEquals("salary", c.best("October salary", Kind.INCOME))
        assertTrue(c.suggest("anything", Kind.EXPENSE).size == Ledger().categoriesOf(Kind.EXPENSE).size)
    }

    @Test
    fun `it learns from what the person picked`() {
        val ledger = Ledger()
        // This person files "Joe's" under groceries, not food.
        repeat(3) { ledger.txns += Fixtures.txn(1500, "groceries", "Joe's corner shop", d.plusDays(it.toLong())) }
        val c = Categorizer(ledger)
        assertEquals("groceries", c.best("Joe's corner shop", Kind.EXPENSE))
        assertEquals("groceries", c.best("corner shop", Kind.EXPENSE))
    }

    @Test
    fun `a learned exact payee wins over keywords`() {
        val ledger = Ledger()
        // "Starbucks" is food by keyword, but this person counts it as work travel.
        repeat(2) { ledger.txns += Fixtures.txn(500, "travel", "Starbucks", d) }
        assertEquals("travel", Categorizer(ledger).best("starbucks", Kind.EXPENSE))
    }

    @Test
    fun `notes are normalised for matching`() {
        assertEquals("netflix", Categorizer.normalize("Netflix #1234"))
        assertEquals(listOf("uber", "airport"), Categorizer.tokens("Paid Uber to the airport"))
    }
}
