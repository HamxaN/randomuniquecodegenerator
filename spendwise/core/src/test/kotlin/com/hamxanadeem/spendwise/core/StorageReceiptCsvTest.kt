package com.hamxanadeem.spendwise.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.LocalDate

class StorageReceiptCsvTest {

    private val today = LocalDate.of(2026, 11, 9)

    @Test
    fun `the ledger survives saving`() {
        val l = Ledger(currency = "PKR")
        l.upsertCategory(l.category("food")!!.copy(budget = 1500000, rollover = true))
        l.upsertCategory(Category("pets", "Pets\twith tab", "paw", 0xFF123456, keywords = listOf("vet", "dog food")))
        l.txns += Fixtures.txn(4550, "pets", "Vet\nvisit \\ check", today)
        l.recurring += Recurring("r", 1000, Kind.EXPENSE, "bills", "Phone", LocalDate.of(2026, 1, 5), Every.MONTHLY, LocalDate.of(2026, 11, 5))
        val back = Ledger.decode(l.encode())!!
        assertEquals("PKR", back.currency)
        assertEquals(l.categories, back.categories)
        assertEquals(l.txns, back.txns)
        assertEquals(l.recurring, back.recurring)
        assertNull(Ledger.decode("not a ledger"))
    }

    @Test
    fun `categories can be removed only into a sibling`() {
        val l = Ledger()
        l.txns += Fixtures.txn(100, "fun", "Movie", today)
        assertFalse(l.removeCategory("fun", "salary"))
        assertTrue(l.removeCategory("fun", "other"))
        assertEquals("other", l.txns.single().categoryId)
        assertNull(l.category("fun"))
    }

    @Test
    fun `receipt totals, dates and shops are found`() {
        val lines = listOf(
            "GREEN VALLEY MARKET",
            "123 Main Street",
            "Tel 555-0101",
            "Date: 07/11/2026 14:32",
            "Milk 2L            3.49",
            "Bread              2.99",
            "SUBTOTAL          45.20",
            "TAX                3.62",
            "TOTAL             48.82",
            "CASH              50.00",
            "CHANGE             1.18",
        )
        val g = Receipt.read(lines, today, "USD")
        assertEquals(4882L, g.amount)
        assertEquals(LocalDate.of(2026, 11, 7), g.date)
        assertEquals("Green Valley Market", g.merchant)
    }

    @Test
    fun `receipts with the total on the next line or no total word`() {
        assertEquals(125000L, Receipt.total(listOf("Amount Due", "Rs 1,250.00"), "PKR"))
        assertEquals(1999L, Receipt.total(listOf("Item 5.00", "Item 19.99", "Thanks"), "USD"))
        assertEquals(LocalDate.of(2026, 10, 3), Receipt.date(listOf("Oct 3, 2026 9:41 AM"), today))
        assertEquals(LocalDate.of(2026, 3, 12), Receipt.date(listOf("12 Mar 2026"), today))
        assertNull(Receipt.date(listOf("no date here"), today))
    }

    @Test
    fun `csv export is spreadsheet-safe`() {
        val l = Ledger()
        l.txns += Fixtures.txn(1250, "food", "Lunch, with \"Sam\"", LocalDate.of(2026, 11, 2))
        l.txns += Fixtures.txn(300000, "salary", "=HYPERLINK(1)", LocalDate.of(2026, 11, 1), Kind.INCOME)
        val csv = Csv.export(l).lines()
        assertEquals("Date,Type,Category,Amount,Currency,Note,Repeating", csv[0])
        assertEquals("2026-11-02,Expense,Food & Dining,-12.50,USD,\"Lunch, with \"\"Sam\"\"\",", csv[1])
        assertEquals("2026-11-01,Income,Salary,3000.00,USD,'=HYPERLINK(1),", csv[2])
    }
}
