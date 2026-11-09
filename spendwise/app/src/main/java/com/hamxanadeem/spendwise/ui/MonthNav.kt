package com.hamxanadeem.spendwise.ui

import android.view.View
import android.widget.TextView
import com.hamxanadeem.spendwise.R
import java.time.YearMonth

/** The "‹ November ›" row at the top of a tab. Can't go past the current month. */
class MonthNav(root: View, private val changed: (YearMonth) -> Unit) {
    var month: YearMonth = YearMonth.now()
        private set
    private val label = root.findViewById<TextView>(R.id.month_name)
    private val next = root.findViewById<View>(R.id.month_next)

    init {
        root.findViewById<View>(R.id.month_prev).setOnClickListener { go(month.minusMonths(1)) }
        next.setOnClickListener { go(month.plusMonths(1)) }
        label.setOnClickListener { go(YearMonth.now()) }
        update()
    }

    private fun go(m: YearMonth) {
        if (m.isAfter(YearMonth.now())) return
        month = m
        update()
        changed(m)
    }

    fun update() {
        label.text = Ui.month(month)
        next.isEnabled = month.isBefore(YearMonth.now())
        next.alpha = if (next.isEnabled) 1f else 0.3f
    }
}
