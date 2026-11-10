package com.hamxanadeem.spendwise.core

import java.time.LocalDate

object Fixtures {
    private var n = 0
    fun id() = "t${++n}"

    fun txn(amount: Long, cat: String, note: String, date: LocalDate, kind: Kind = Kind.EXPENSE, rec: String? = null) =
        Txn(id(), amount, kind, cat, note, date, rec)
}
