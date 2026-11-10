package com.hamxanadeem.spendwise.ui

import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.core.Budgets
import com.hamxanadeem.spendwise.core.Insights
import com.hamxanadeem.spendwise.core.Kind
import com.hamxanadeem.spendwise.data.Store
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale

/** Charts and findings: where the money went, daily pace, six-month trend, repeating payments and oddities. */
class InsightsPage(private val a: MainActivity) : Page {

    override val view: View = LayoutInflater.from(a).inflate(R.layout.page_insights, a.findViewById(R.id.pages), false)
    private val nav = MonthNav(view) { refresh() }

    override fun refresh() {
        nav.update()
        val l = Store.ledger(a)
        val month = nav.month
        val today = LocalDate.now()
        val isNow = month == YearMonth.from(today)
        val spent = l.total(month, Kind.EXPENSE)

        // Where it went.
        val by = Insights.byCategory(l, month)
        view.findViewById<DonutView>(R.id.donut).set(
            by.map { (id, v) -> (l.category(id)?.color ?: 0xFF757575).toInt() to v },
            Ui.money(a, spent), a.getString(R.string.spent_label))
        val legend = view.findViewById<LinearLayout>(R.id.legend)
        legend.removeAllViews()
        for ((id, v) in by.take(8)) {
            val row = LayoutInflater.from(a).inflate(R.layout.item_legend, legend, false)
            Ui.badge(row.findViewById(R.id.badge), l.category(id))
            row.findViewById<TextView>(R.id.name).text = l.category(id)?.name ?: a.getString(R.string.category_missing)
            row.findViewById<TextView>(R.id.share).text = Insights.pct(v.toDouble() / maxOf(spent, 1))
            row.findViewById<TextView>(R.id.value).text = Ui.money(a, v)
            legend.addView(row)
        }
        view.findViewById<View>(R.id.donut_empty).visibility = if (by.isEmpty()) View.VISIBLE else View.GONE

        // Daily pace against what the budgets allow per day.
        val budgets = Budgets.status(l, month)
        val perDay = if (budgets.isNotEmpty()) budgets.sumOf { it.available } / month.lengthOfMonth() else 0L
        view.findViewById<DailyBarsView>(R.id.daily).set(Insights.daily(l, month), if (isNow) today.dayOfMonth - 1 else -1, perDay)
        val days = if (isNow) today.dayOfMonth else month.lengthOfMonth()
        view.findViewById<TextView>(R.id.daily_note).text = buildString {
            append(a.getString(R.string.daily_average, Ui.money(a, spent / days)))
            if (isNow && spent > 0) append(" · ").append(a.getString(R.string.forecast_line, Ui.money(a, Insights.forecast(l, month, today))))
            if (perDay > 0) append(" · ").append(a.getString(R.string.pace_line, Ui.money(a, perDay)))
        }

        // Six months of income and spending.
        val six = Insights.months(l, month, 6)
        view.findViewById<TrendView>(R.id.trend).set(six.map { (m, inc, exp) ->
            Triple(m.month.getDisplayName(TextStyle.SHORT, Locale.getDefault()), inc, exp)
        })
        val avgSpend = six.filter { it.third > 0 }.map { it.third }.average().takeIf { !it.isNaN() } ?: 0.0
        val withIncome = six.filter { it.second > 0 }
        view.findViewById<TextView>(R.id.trend_note).text = buildString {
            append(a.getString(R.string.trend_avg, Ui.money(a, avgSpend.toLong())))
            if (withIncome.isNotEmpty()) {
                val rate = withIncome.sumOf { it.second - it.third }.toDouble() / withIncome.sumOf { it.second }
                append(" · ").append(a.getString(if (rate >= 0) R.string.trend_saved else R.string.trend_overspent, Insights.pct(rate)))
            }
        }

        // Repeating payments found in the history.
        val subs = Insights.subscriptions(l, today)
        val subList = view.findViewById<LinearLayout>(R.id.subscriptions)
        subList.removeAllViews()
        for (s in subs) {
            val row = LayoutInflater.from(a).inflate(R.layout.item_row, subList, false)
            Ui.badge(row.findViewById(R.id.badge), l.category(s.categoryId))
            row.findViewById<TextView>(R.id.title).text = s.name
            row.findViewById<TextView>(R.id.subtitle).text = a.getString(R.string.sub_line, a.getString(everyLabel(s.every)),
                Ui.day(a, s.next), Ui.money(a, s.yearly))
            row.findViewById<TextView>(R.id.trailing).text = Ui.money(a, s.amount)
            subList.addView(row)
        }
        view.findViewById<TextView>(R.id.subs_note).text =
            if (subs.isEmpty()) a.getString(R.string.subs_none)
            else a.getString(R.string.subs_total, Ui.money(a, subs.sumOf { it.yearly }))

        // Unusually large payments.
        val odd = Insights.anomalies(l, month)
        val oddList = view.findViewById<LinearLayout>(R.id.anomalies)
        oddList.removeAllViews()
        for (t in odd) {
            val row = TxnRows.inflate(a, oddList)
            TxnRows.bind(row, t, true) { a.startActivity(EditActivity.intent(a, it.id)) }
            oddList.addView(row)
        }
        view.findViewById<View>(R.id.anomalies_card).visibility = if (odd.isEmpty()) View.GONE else View.VISIBLE
    }

    companion object {
        fun everyLabel(e: com.hamxanadeem.spendwise.core.Every) = when (e) {
            com.hamxanadeem.spendwise.core.Every.WEEKLY -> R.string.weekly
            com.hamxanadeem.spendwise.core.Every.MONTHLY -> R.string.monthly
            com.hamxanadeem.spendwise.core.Every.YEARLY -> R.string.yearly
        }
    }
}
