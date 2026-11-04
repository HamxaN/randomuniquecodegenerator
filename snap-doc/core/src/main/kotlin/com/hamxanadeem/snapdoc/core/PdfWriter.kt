package com.hamxanadeem.snapdoc.core

import java.io.OutputStream

/**
 * Writes a PDF with one scanned page per JPEG. The JPEG bytes are embedded as
 * they are (DCTDecode), so pages keep the scanner's full quality and the file
 * stays small. Each page is as wide as an A4 sheet and as tall as the scan's
 * aspect ratio needs.
 */
object PdfWriter {

    /** A4 width in PDF points (1/72 inch). */
    const val PAGE_WIDTH = 595.0

    class Page(val jpeg: ByteArray) {
        val info: JpegInfo = JpegInfo.read(jpeg) ?: throw IllegalArgumentException("Not a JPEG image")
    }

    fun pageHeight(info: JpegInfo): Double = PAGE_WIDTH * info.height / info.width

    /** Writes the PDF for [pages] to [out]. Returns the number of bytes written. */
    fun write(pages: List<Page>, out: OutputStream, title: String = "Scan"): Long {
        require(pages.isNotEmpty()) { "A PDF needs at least one page" }
        val w = CountingWriter(out)
        // Object numbers: 1 catalog, 2 page tree, 3 info, then 3 per page (page, contents, image).
        val offsets = LongArray(3 + pages.size * 3 + 1)
        fun pageObj(i: Int) = 4 + i * 3
        w.text("%PDF-1.4\n")
        // A comment of high bytes marks the file as binary for transfer tools.
        w.bytes(byteArrayOf('%'.code.toByte(), 0xE2.toByte(), 0xE3.toByte(), 0xCF.toByte(), 0xD3.toByte(), '\n'.code.toByte()))

        offsets[1] = w.count
        w.text("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")

        offsets[2] = w.count
        val kids = pages.indices.joinToString(" ") { "${pageObj(it)} 0 R" }
        w.text("2 0 obj\n<< /Type /Pages /Kids [$kids] /Count ${pages.size} >>\nendobj\n")

        offsets[3] = w.count
        w.text("3 0 obj\n<< /Title ${literal(title)} /Producer (SnapDoc Scanner) /Creator (SnapDoc Scanner) >>\nendobj\n")

        pages.forEachIndexed { i, page ->
            val n = pageObj(i)
            val height = pageHeight(page.info)
            val wStr = fmt(PAGE_WIDTH)
            val hStr = fmt(height)
            offsets[n] = w.count
            w.text("$n 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $wStr $hStr] " +
                "/Resources << /XObject << /Im$i ${n + 2} 0 R >> >> /Contents ${n + 1} 0 R >>\nendobj\n")
            val content = "q $wStr 0 0 $hStr 0 0 cm /Im$i Do Q\n".toByteArray(Charsets.ISO_8859_1)
            offsets[n + 1] = w.count
            w.text("${n + 1} 0 obj\n<< /Length ${content.size} >>\nstream\n")
            w.bytes(content)
            w.text("endstream\nendobj\n")
            val space = when (page.info.components) {
                1 -> "/DeviceGray"
                4 -> "/DeviceCMYK /Decode [1 0 1 0 1 0 1 0]"
                else -> "/DeviceRGB"
            }
            offsets[n + 2] = w.count
            w.text("${n + 2} 0 obj\n<< /Type /XObject /Subtype /Image /Width ${page.info.width} /Height ${page.info.height} " +
                "/ColorSpace $space /BitsPerComponent 8 /Filter /DCTDecode /Length ${page.jpeg.size} >>\nstream\n")
            w.bytes(page.jpeg)
            w.text("\nendstream\nendobj\n")
        }

        val xref = w.count
        val total = offsets.size
        w.text("xref\n0 $total\n0000000000 65535 f \n")
        for (k in 1 until total) {
            w.text(offsets[k].toString().padStart(10, '0') + " 00000 n \n")
        }
        w.text("trailer\n<< /Size $total /Root 1 0 R /Info 3 0 R >>\nstartxref\n$xref\n%%EOF\n")
        w.flush()
        return w.count
    }

    /** A PDF string literal, escaping what must be escaped and dropping non-Latin-1 characters. */
    fun literal(s: String): String {
        val sb = StringBuilder("(")
        for (ch in s) {
            when {
                ch == '(' || ch == ')' || ch == '\\' -> sb.append('\\').append(ch)
                ch == '\n' -> sb.append("\\n")
                ch == '\r' -> sb.append("\\r")
                ch.code in 32..255 -> sb.append(ch)
                else -> sb.append('?')
            }
        }
        return sb.append(')').toString()
    }

    private fun fmt(v: Double): String {
        val r = Math.round(v * 100.0) / 100.0
        return if (r == Math.floor(r)) r.toLong().toString() else r.toString()
    }

    private class CountingWriter(private val out: OutputStream) {
        var count = 0L
            private set

        fun text(s: String) = bytes(s.toByteArray(Charsets.ISO_8859_1))

        fun bytes(b: ByteArray) {
            out.write(b)
            count += b.size
        }

        fun flush() = out.flush()
    }
}
