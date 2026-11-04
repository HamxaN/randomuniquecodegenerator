package com.hamxanadeem.snapdoc.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.io.ByteArrayOutputStream

class PdfWriterTest {

    /** A minimal JPEG header: SOI, an APP0 segment, then a baseline frame header. */
    private fun fakeJpeg(width: Int, height: Int, components: Int = 3, body: Int = 200): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(byteArrayOf(0xFF.toByte(), 0xD8.toByte()))
        // APP0 (JFIF), 16 bytes long.
        out.write(byteArrayOf(0xFF.toByte(), 0xE0.toByte(), 0x00, 0x10))
        out.write("JFIF".toByteArray() + byteArrayOf(0, 1, 1, 0, 0, 1, 0, 1, 0, 0))
        // SOF0.
        val len = 8 + components * 3
        out.write(byteArrayOf(0xFF.toByte(), 0xC0.toByte(), (len shr 8).toByte(), len.toByte(), 8,
            (height shr 8).toByte(), height.toByte(), (width shr 8).toByte(), width.toByte(), components.toByte()))
        repeat(components) { out.write(byteArrayOf((it + 1).toByte(), 0x11, 0)) }
        out.write(ByteArray(body) { (it % 251).toByte() })
        out.write(byteArrayOf(0xFF.toByte(), 0xD9.toByte()))
        return out.toByteArray()
    }

    @Test
    fun `reads the size and colours of a JPEG`() {
        val info = JpegInfo.read(fakeJpeg(1240, 1754, 3))
        assertEquals(JpegInfo(1240, 1754, 3), info)
        assertEquals(1, JpegInfo.read(fakeJpeg(10, 20, 1))?.components)
    }

    @Test
    fun `rejects things that are not JPEGs`() {
        assertNull(JpegInfo.read(ByteArray(0)))
        assertNull(JpegInfo.read("%PDF-1.4".toByteArray()))
        assertNull(JpegInfo.read(fakeJpeg(100, 100).copyOf(12)))
        assertThrows<IllegalArgumentException> { PdfWriter.Page("nope".toByteArray()) }
    }

    @Test
    fun `writes a well-formed PDF with one page per image`() {
        val pages = listOf(fakeJpeg(1000, 1414), fakeJpeg(1414, 1000), fakeJpeg(800, 800, 1)).map { PdfWriter.Page(it) }
        val out = ByteArrayOutputStream()
        val size = PdfWriter.write(pages, out, "Receipts (May)")
        val bytes = out.toByteArray()
        assertEquals(bytes.size.toLong(), size)
        val text = String(bytes, Charsets.ISO_8859_1)
        assertTrue(text.startsWith("%PDF-1.4\n"))
        assertTrue(text.trimEnd().endsWith("%%EOF"))
        assertTrue(text.contains("/Count 3"))
        assertTrue(text.contains("/Title (Receipts \\(May\\))"))
        assertEquals(3, Regex("/Type /Page ").findAll(text).count())
        assertTrue(text.contains("/ColorSpace /DeviceGray"))
        // Portrait, landscape and square pages keep their shape.
        assertTrue(text.contains("/MediaBox [0 0 595 841.33]"))
        assertTrue(text.contains("/MediaBox [0 0 595 420.79]"))
        assertTrue(text.contains("/MediaBox [0 0 595 595]"))
    }

    @Test
    fun `every cross-reference entry points at its object`() {
        val pages = List(4) { PdfWriter.Page(fakeJpeg(600 + it * 10, 900)) }
        val out = ByteArrayOutputStream()
        PdfWriter.write(pages, out)
        val text = String(out.toByteArray(), Charsets.ISO_8859_1)
        val startxref = Regex("startxref\n(\\d+)").find(text)!!.groupValues[1].toInt()
        assertTrue(text.startsWith("xref", startxref))
        val entries = Regex("(\\d{10}) 00000 n ").findAll(text).map { it.groupValues[1].toInt() }.toList()
        assertEquals(3 + 4 * 3, entries.size)
        entries.forEachIndexed { k, offset ->
            assertTrue(text.startsWith("${k + 1} 0 obj", offset), "object ${k + 1} at $offset")
        }
        val size = Regex("/Size (\\d+)").find(text)!!.groupValues[1].toInt()
        assertEquals(entries.size + 1, size)
    }

    @Test
    fun `images are embedded byte for byte`() {
        val jpeg = fakeJpeg(300, 400, body = 5000)
        val out = ByteArrayOutputStream()
        PdfWriter.write(listOf(PdfWriter.Page(jpeg)), out)
        val bytes = out.toByteArray()
        val at = indexOf(bytes, jpeg)
        assertTrue(at > 0)
        val header = String(bytes, 0, at, Charsets.ISO_8859_1)
        assertTrue(header.contains("/Length ${jpeg.size} >>\nstream\n"))
        assertNotNull(Regex("/Filter /DCTDecode").find(header))
    }

    @Test
    fun `needs at least one page`() {
        assertThrows<IllegalArgumentException> { PdfWriter.write(emptyList(), ByteArrayOutputStream()) }
    }

    @Test
    fun `titles are escaped and kept to Latin-1`() {
        assertEquals("(a\\(b\\)c\\\\d)", PdfWriter.literal("a(b)c\\d"))
        assertEquals("(Caf\u00e9 ?)", PdfWriter.literal("Caf\u00e9 \u4e2d"))
    }

    private fun indexOf(hay: ByteArray, needle: ByteArray): Int {
        outer@ for (i in 0..hay.size - needle.size) {
            for (j in needle.indices) if (hay[i + j] != needle[j]) continue@outer
            return i
        }
        return -1
    }
}
