package com.hamxanadeem.spendwise.core

/** Spreadsheet export: one row per transaction, newest first. */
object Csv {

    fun export(ledger: Ledger): String {
        val sb = StringBuilder("Date,Type,Category,Amount,Currency,Note,Repeating\n")
        for (t in ledger.txns.sortedWith(compareByDescending<Txn> { it.date }.thenByDescending { it.createdAt })) {
            val signed = if (t.kind == Kind.EXPENSE) -t.amount else t.amount
            sb.append(listOf(
                t.date.toString(),
                if (t.kind == Kind.EXPENSE) "Expense" else "Income",
                ledger.category(t.categoryId)?.name ?: t.categoryId,
                Money.toDecimal(signed, ledger.currency).toPlainString(),
                ledger.currency,
                t.note,
                if (t.recurringId != null) "yes" else "",
            ).joinToString(",") { cell(it) }).append('\n')
        }
        return sb.toString()
    }

    /** Quotes a cell when needed, and defuses spreadsheet formulas. */
    fun cell(s: String): String {
        var v = s
        if (v.isNotEmpty() && v[0] in "=+-@" && v.toDoubleOrNull() == null) v = "'$v"
        return if (v.any { it == ',' || it == '"' || it == '\n' || it == '\r' }) "\"" + v.replace("\"", "\"\"") + "\"" else v
    }
}
