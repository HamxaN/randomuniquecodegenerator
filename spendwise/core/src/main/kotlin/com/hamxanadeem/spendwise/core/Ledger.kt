package com.hamxanadeem.spendwise.core

import java.time.LocalDate
import java.time.YearMonth

/**
 * Everything the app knows: settings, categories, transactions and repeating
 * rules. Stored as plain text, one tab-separated record per line (see [encode]).
 */
class Ledger(
    var currency: String = "USD",
    categories: List<Category> = Defaults.categories,
    txns: List<Txn> = emptyList(),
    recurring: List<Recurring> = emptyList(),
) {
    val categories = categories.toMutableList()
    val txns = txns.toMutableList()
    val recurring = recurring.toMutableList()

    fun category(id: String): Category? = categories.firstOrNull { it.id == id }

    fun categoriesOf(kind: Kind) = categories.filter { it.kind == kind && !it.archived }

    fun txn(id: String) = txns.firstOrNull { it.id == id }

    fun inMonth(month: YearMonth, kind: Kind? = null): List<Txn> =
        txns.filter { month.contains(it.date) && (kind == null || it.kind == kind) }

    fun total(month: YearMonth, kind: Kind): Long = inMonth(month, kind).sumOf { it.amount }

    fun upsertTxn(t: Txn) {
        val i = txns.indexOfFirst { it.id == t.id }
        if (i >= 0) txns[i] = t else txns += t
    }

    fun removeTxn(id: String) = txns.removeAll { it.id == id }

    fun upsertCategory(c: Category) {
        val i = categories.indexOfFirst { it.id == c.id }
        if (i >= 0) categories[i] = c else categories += c
    }

    /**
     * Deletes a category, moving its transactions and rules to [moveTo].
     * The last category of a kind can't be removed.
     */
    fun removeCategory(id: String, moveTo: String): Boolean {
        val c = category(id) ?: return false
        if (categoriesOf(c.kind).size <= 1 || id == moveTo || category(moveTo)?.kind != c.kind) return false
        txns.replaceAll { if (it.categoryId == id) it.copy(categoryId = moveTo) else it }
        recurring.replaceAll { if (it.categoryId == id) it.copy(categoryId = moveTo) else it }
        categories.removeAll { it.id == id }
        return true
    }

    fun upsertRecurring(r: Recurring) {
        val i = recurring.indexOfFirst { it.id == r.id }
        if (i >= 0) recurring[i] = r else recurring += r
    }

    fun removeRecurring(id: String) = recurring.removeAll { it.id == id }

    /**
     * Adds every repeating transaction that has fallen due up to [today].
     * Returns the new transactions. [newId] makes ids (injected for tests).
     */
    fun postDue(today: LocalDate, now: Long, newId: () -> String): List<Txn> {
        val added = mutableListOf<Txn>()
        recurring.replaceAll { r ->
            val dates = r.due(today)
            if (dates.isEmpty()) return@replaceAll r
            for (d in dates) {
                val t = Txn(newId(), r.amount, r.kind, r.categoryId, r.note, d, r.id, now)
                txns += t
                added += t
            }
            r.copy(lastPosted = dates.last())
        }
        return added
    }

    fun encode(): String {
        val sb = StringBuilder("spendwise 1\n")
        sb.append(row("S", currency)).append('\n')
        for (c in categories) {
            sb.append(row("C", c.id, c.name, c.icon, c.color.toString(), c.kind.name, c.budget.toString(),
                c.rollover.toString(), c.keywords.joinToString(","), c.archived.toString())).append('\n')
        }
        for (t in txns) {
            sb.append(row("T", t.id, t.amount.toString(), t.kind.name, t.categoryId, t.note, t.date.toString(),
                t.recurringId ?: "", t.createdAt.toString())).append('\n')
        }
        for (r in recurring) {
            sb.append(row("R", r.id, r.amount.toString(), r.kind.name, r.categoryId, r.note, r.start.toString(),
                r.every.name, r.lastPosted?.toString() ?: "")).append('\n')
        }
        return sb.toString()
    }

    companion object {

        fun decode(text: String): Ledger? {
            val lines = text.split('\n')
            if (lines.isEmpty() || !lines[0].startsWith("spendwise ")) return null
            val ledger = Ledger(categories = emptyList())
            for (line in lines.drop(1)) {
                if (line.isBlank()) continue
                val f = line.split('\t').map { unescape(it) }
                runCatching {
                    when (f[0]) {
                        "S" -> ledger.currency = f[1]
                        "C" -> ledger.categories += Category(f[1], f[2], f[3], f[4].toLong(), Kind.valueOf(f[5]), f[6].toLong(),
                            f[7].toBoolean(), if (f[8].isEmpty()) emptyList() else f[8].split(','), f.getOrElse(9) { "false" }.toBoolean())
                        "T" -> ledger.txns += Txn(f[1], f[2].toLong(), Kind.valueOf(f[3]), f[4], f[5], LocalDate.parse(f[6]),
                            f[7].ifEmpty { null }, f.getOrElse(8) { "0" }.toLong())
                        "R" -> ledger.recurring += Recurring(f[1], f[2].toLong(), Kind.valueOf(f[3]), f[4], f[5], LocalDate.parse(f[6]),
                            Every.valueOf(f[7]), f.getOrElse(8) { "" }.ifEmpty { null }?.let { LocalDate.parse(it) })
                    }
                }
            }
            if (ledger.categories.none { it.kind == Kind.EXPENSE } || ledger.categories.none { it.kind == Kind.INCOME }) {
                Defaults.categories.filter { d -> ledger.categories.none { it.id == d.id } }.forEach { ledger.categories += it }
            }
            return ledger
        }

        private fun row(vararg fields: String) = fields.joinToString("\t") { escape(it) }

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
