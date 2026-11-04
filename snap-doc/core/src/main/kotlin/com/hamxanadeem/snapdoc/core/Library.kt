package com.hamxanadeem.snapdoc.core

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/** One scanned document: its pages (image file names, in order) and any recognised text. */
data class Document(
    val id: String,
    val name: String,
    val pages: List<String>,
    val createdAt: Long,
    val updatedAt: Long,
    val text: String = "",
)

/**
 * The list of documents and the rules for naming, searching, sorting and
 * editing them. Stored as a simple line-based text file (see [encode]).
 */
class Library(documents: List<Document> = emptyList()) {

    private val docs = documents.toMutableList()

    val documents: List<Document> get() = docs.toList()

    fun get(id: String): Document? = docs.firstOrNull { it.id == id }

    /** Newest first. */
    fun sorted(): List<Document> = docs.sortedByDescending { it.updatedAt }

    /** Documents whose name or recognised text contains every word of [query], newest first. */
    fun search(query: String): List<Document> {
        val words = query.trim().lowercase().split(Regex("\\s+")).filter { it.isNotEmpty() }
        if (words.isEmpty()) return sorted()
        return sorted().filter { d ->
            val hay = (d.name + "\n" + d.text).lowercase()
            words.all { hay.contains(it) }
        }
    }

    fun add(doc: Document) {
        require(get(doc.id) == null) { "Duplicate document id ${doc.id}" }
        docs += doc
    }

    fun remove(id: String): Document? {
        val d = get(id) ?: return null
        docs.remove(d)
        return d
    }

    private fun replace(id: String, now: Long, change: (Document) -> Document): Document? {
        val i = docs.indexOfFirst { it.id == id }
        if (i < 0) return null
        val updated = change(docs[i]).copy(updatedAt = now)
        docs[i] = updated
        return updated
    }

    fun rename(id: String, newName: String, now: Long): Document? {
        val clean = cleanName(newName) ?: return null
        return replace(id, now) { it.copy(name = clean) }
    }

    fun addPages(id: String, pages: List<String>, now: Long): Document? =
        replace(id, now) { it.copy(pages = it.pages + pages) }

    /** Removes one page. Returns null if that would leave the document empty. */
    fun removePage(id: String, index: Int, now: Long): Document? {
        val d = get(id) ?: return null
        if (index !in d.pages.indices || d.pages.size <= 1) return null
        return replace(id, now) { it.copy(pages = it.pages.filterIndexed { i, _ -> i != index }) }
    }

    fun movePage(id: String, from: Int, to: Int, now: Long): Document? {
        val d = get(id) ?: return null
        if (from !in d.pages.indices || to !in d.pages.indices) return null
        val list = d.pages.toMutableList()
        list.add(to, list.removeAt(from))
        return replace(id, now) { it.copy(pages = list) }
    }

    /** Replaces a page's file name (after it was rotated and saved under a new name). */
    fun replacePage(id: String, index: Int, file: String, now: Long): Document? {
        val d = get(id) ?: return null
        if (index !in d.pages.indices) return null
        return replace(id, now) { it.copy(pages = it.pages.mapIndexed { i, p -> if (i == index) file else p }) }
    }

    fun setText(id: String, text: String, now: Long): Document? = replace(id, now) { it.copy(text = text) }

    /** Saves the library as text: a version line, then one tab-separated line per document. */
    fun encode(): String {
        val sb = StringBuilder("snapdoc 1\n")
        for (d in docs) {
            sb.append(listOf(d.id, d.name, d.pages.joinToString("|"), d.createdAt.toString(), d.updatedAt.toString(), d.text)
                .joinToString("\t") { escape(it) })
            sb.append('\n')
        }
        return sb.toString()
    }

    companion object {
        private val NAME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH.mm")
        const val MAX_NAME = 80

        fun defaultName(time: LocalDateTime): String = "Scan ${time.format(NAME_FORMAT)}"

        /** A tidy document name, or null if nothing usable is left. */
        fun cleanName(raw: String): String? {
            val s = raw.replace(Regex("[\\\\/:*?\"<>|\\t\\r\\n]"), " ").replace(Regex("\\s+"), " ").trim()
            if (s.isEmpty()) return null
            return if (s.length > MAX_NAME) s.substring(0, MAX_NAME).trim() else s
        }

        /** The file name to use when exporting a document as a PDF. */
        fun pdfFileName(name: String): String = (cleanName(name) ?: "Scan") + ".pdf"

        fun decode(text: String): Library {
            val lines = text.split('\n')
            if (lines.isEmpty() || !lines[0].startsWith("snapdoc ")) return Library()
            val out = mutableListOf<Document>()
            for (line in lines.drop(1)) {
                if (line.isBlank()) continue
                val f = line.split('\t').map { unescape(it) }
                if (f.size < 5) continue
                val pages = if (f[2].isEmpty()) emptyList() else f[2].split('|')
                out += Document(f[0], f[1], pages, f[3].toLongOrNull() ?: 0L, f[4].toLongOrNull() ?: 0L, f.getOrElse(5) { "" })
            }
            return Library(out)
        }

        private fun escape(s: String): String =
            s.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n").replace("\r", "\\r")

        private fun unescape(s: String): String {
            val sb = StringBuilder()
            var i = 0
            while (i < s.length) {
                val ch = s[i]
                if (ch == '\\' && i + 1 < s.length) {
                    when (s[i + 1]) {
                        't' -> sb.append('\t')
                        'n' -> sb.append('\n')
                        'r' -> sb.append('\r')
                        else -> sb.append(s[i + 1])
                    }
                    i += 2
                } else {
                    sb.append(ch)
                    i++
                }
            }
            return sb.toString()
        }
    }
}
