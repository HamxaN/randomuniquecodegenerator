package com.hamxanadeem.snapdoc.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.LocalDateTime

class LibraryTest {

    private fun doc(id: String, name: String, pages: Int = 2, at: Long = 0L, text: String = "") =
        Document(id, name, List(pages) { "p$it.jpg" }, at, at, text)

    @Test
    fun `default names carry the date and time`() {
        assertEquals("Scan 2026-11-04 09.05", Library.defaultName(LocalDateTime.of(2026, 11, 4, 9, 5)))
    }

    @Test
    fun `names are cleaned for use as file names`() {
        assertEquals("Tax 2026 part 1", Library.cleanName("  Tax/2026:  part\t1 "))
        assertNull(Library.cleanName("  ///  "))
        assertEquals(Library.MAX_NAME, Library.cleanName("x".repeat(200))!!.length)
        assertEquals("Invoice A.pdf", Library.pdfFileName("Invoice A"))
        assertEquals("Scan.pdf", Library.pdfFileName("?"))
    }

    @Test
    fun `newest first, and search looks in names and recognised text`() {
        val lib = Library(listOf(
            doc("a", "Electricity bill", at = 10),
            doc("b", "Passport", at = 30, text = "REPUBLIC OF EXAMPLE passport no 12345"),
            doc("c", "Bill of sale car", at = 20),
        ))
        assertEquals(listOf("b", "c", "a"), lib.sorted().map { it.id })
        assertEquals(listOf("c", "a"), lib.search("bill").map { it.id })
        assertEquals(listOf("c"), lib.search("  BILL car ").map { it.id })
        assertEquals(listOf("b"), lib.search("12345").map { it.id })
        assertEquals(3, lib.search("   ").size)
        assertTrue(lib.search("nothing").isEmpty())
    }

    @Test
    fun `renaming and editing pages update the time`() {
        val lib = Library(listOf(doc("a", "Old", pages = 3)))
        assertEquals("New name", lib.rename("a", " New   name ", 5)!!.name)
        assertEquals(5, lib.get("a")!!.updatedAt)
        assertNull(lib.rename("a", "   ", 6))
        assertEquals(4, lib.addPages("a", listOf("x.jpg"), 7)!!.pages.size)
        assertEquals(listOf("p1.jpg", "p2.jpg", "x.jpg", "p0.jpg"), lib.movePage("a", 0, 3, 8)!!.pages)
        assertEquals(listOf("p1.jpg", "x.jpg", "p0.jpg"), lib.removePage("a", 1, 9)!!.pages)
        assertEquals("r.jpg", lib.replacePage("a", 0, "r.jpg", 10)!!.pages[0])
        assertNull(lib.movePage("a", 0, 9, 11))
        assertNull(lib.rename("missing", "x", 1))
    }

    @Test
    fun `a document always keeps at least one page`() {
        val lib = Library(listOf(doc("a", "One", pages = 1)))
        assertNull(lib.removePage("a", 0, 1))
        assertEquals(1, lib.get("a")!!.pages.size)
    }

    @Test
    fun `ids are unique and documents can be removed`() {
        val lib = Library(listOf(doc("a", "A")))
        assertThrows<IllegalArgumentException> { lib.add(doc("a", "Again")) }
        assertEquals("A", lib.remove("a")!!.name)
        assertNull(lib.remove("a"))
        assertTrue(lib.documents.isEmpty())
    }

    @Test
    fun `the library survives saving, even with awkward text`() {
        val tricky = "Line one\nTab\there | pipe \\ backslash"
        val lib = Library(listOf(doc("a", "Plain", at = 1), doc("b", "Odd\\name", pages = 1, at = 2, text = tricky)))
        val back = Library.decode(lib.encode())
        assertEquals(lib.documents, back.documents)
        assertEquals(tricky, back.get("b")!!.text)
    }

    @Test
    fun `unreadable files give an empty library`() {
        assertTrue(Library.decode("").documents.isEmpty())
        assertTrue(Library.decode("garbage\nmore").documents.isEmpty())
        assertEquals(1, Library.decode("snapdoc 1\nshort\ta\nid\tname\tp.jpg\t1\t2\n").documents.size)
    }
}
