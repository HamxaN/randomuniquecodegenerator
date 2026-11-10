package com.hamxanadeem.spendwise.ui

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.materialswitch.MaterialSwitch
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.core.BudgetState
import com.hamxanadeem.spendwise.core.BudgetStatus
import com.hamxanadeem.spendwise.core.Budgets
import com.hamxanadeem.spendwise.core.Category
import com.hamxanadeem.spendwise.core.Kind
import com.hamxanadeem.spendwise.core.Money
import com.hamxanadeem.spendwise.data.Store
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.LocalDate
import java.time.YearMonth

/** A monthly budget per category, with optional rollover, and a daily safe-to-spend. */
class BudgetsPage(private val a: MainActivity) : Page {

    override val view: View = LayoutInflater.from(a).inflate(R.layout.page_budgets, a.findViewById(R.id.pages), false)
    private val nav = MonthNav(view) { refresh() }
    private var rows: List<BudgetStatus> = emptyList()
    private val adapter = object : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
        override fun getItemCount() = rows.size
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            object : RecyclerView.ViewHolder(LayoutInflater.from(parent.context).inflate(R.layout.item_budget, parent, false)) {}

        override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) = bind(holder.itemView, rows[position])
    }

    init {
        view.findViewById<RecyclerView>(R.id.list).apply {
            layoutManager = LinearLayoutManager(a)
            adapter = this@BudgetsPage.adapter
        }
    }

    override fun refresh() {
        nav.update()
        val l = Store.ledger(a)
        val month = nav.month
        val today = LocalDate.now()
        // Budgeted categories first (most used first), then the rest by spending.
        rows = l.categoriesOf(Kind.EXPENSE).map { Budgets.status(l, it, month) }
            .sortedWith(compareByDescending<BudgetStatus> { it.budget > 0 }.thenByDescending { it.spent })
        @Suppress("NotifyDataSetChanged")
        adapter.notifyDataSetChanged()

        val budgeted = rows.filter { it.budget > 0 }
        val title = view.findViewById<TextView>(R.id.safe_title)
        val detail = view.findViewById<TextView>(R.id.safe_detail)
        if (budgeted.isEmpty()) {
            title.setText(R.string.budgets_none_title)
            detail.setText(R.string.budgets_none_body)
        } else {
            val available = budgeted.sumOf { it.available }
            val spent = budgeted.sumOf { it.spent }
            if (month == YearMonth.from(today)) {
                val daysLeft = month.lengthOfMonth() - today.dayOfMonth + 1
                title.text = a.getString(R.string.safe_to_spend, Ui.money(a, Budgets.safeToSpendPerDay(l, month, today)))
                detail.text = a.resources.getQuantityString(R.plurals.budget_summary, daysLeft,
                    Ui.money(a, spent), Ui.money(a, available), daysLeft)
            } else {
                title.text = a.getString(R.string.budget_month_result, Ui.money(a, spent), Ui.money(a, available))
                detail.text = if (spent <= available) a.getString(R.string.budget_month_under, Ui.money(a, available - spent))
                else a.getString(R.string.budget_month_over, Ui.money(a, spent - available))
            }
        }
    }

    private fun bind(v: View, s: BudgetStatus) {
        val c = s.category
        Ui.badge(v.findViewById(R.id.badge), c)
        v.findViewById<TextView>(R.id.name).text = c.name
        val amount = v.findViewById<TextView>(R.id.amount)
        val detail = v.findViewById<TextView>(R.id.detail)
        val bar = v.findViewById<BudgetBarView>(R.id.bar)
        val month = nav.month
        val today = LocalDate.now()
        val pace = if (month == YearMonth.from(today)) today.dayOfMonth.toDouble() / month.lengthOfMonth() else -1.0
        if (c.budget > 0) {
            amount.text = a.getString(R.string.of_amount, Ui.money(a, s.spent), Ui.money(a, s.available))
            bar.visibility = View.VISIBLE
            bar.set(s.fraction, when (s.state) {
                BudgetState.OVER -> R.color.expense
                BudgetState.WARNING -> R.color.warning
                BudgetState.OK -> R.color.brand
            }, pace)
            val parts = mutableListOf(
                if (s.remaining >= 0) a.getString(R.string.left_amount, Ui.money(a, s.remaining))
                else a.getString(R.string.over_amount, Ui.money(a, -s.remaining))
            )
            if (c.rollover && s.carried != 0L) parts += a.getString(
                if (s.carried > 0) R.string.carried_in else R.string.carried_debt, Ui.money(a, kotlin.math.abs(s.carried)))
            detail.text = parts.joinToString(" · ")
        } else {
            amount.text = Ui.money(a, s.spent)
            bar.visibility = View.GONE
            detail.setText(R.string.no_budget)
        }
        v.setOnClickListener { edit(c) }
    }

    /** What this category usually costs: the average of the last three months, rounded up to a tidy number. */
    private fun suggestion(c: Category): Long {
        val l = Store.ledger(a)
        val now = YearMonth.now()
        val months = (1..3).map { now.minusMonths(it.toLong()) }
        val spent = months.map { Budgets.spent(l, c.id, it) }.filter { it > 0 }
        if (spent.isEmpty()) return 0
        val avg = Money.toDecimal(spent.sum() / spent.size, l.currency)
        val step = when {
            avg < BigDecimal(100) -> BigDecimal(5)
            avg < BigDecimal(1000) -> BigDecimal(10)
            avg < BigDecimal(10000) -> BigDecimal(50)
            else -> BigDecimal(500)
        }
        val rounded = avg.divide(step, 0, RoundingMode.CEILING).multiply(step)
        return Money.toMinor(rounded, l.currency)
    }

    private fun edit(c: Category) {
        val v = LayoutInflater.from(a).inflate(R.layout.dialog_budget, null as ViewGroup?)
        val input = v.findViewById<EditText>(R.id.amount)
        val roll = v.findViewById<MaterialSwitch>(R.id.rollover)
        val hint = v.findViewById<TextView>(R.id.suggestion)
        if (c.budget > 0) input.setText(Ui.plain(a, c.budget))
        roll.isChecked = c.rollover
        val s = suggestion(c)
        if (s > 0) {
            hint.text = a.getString(R.string.budget_suggestion, Ui.money(a, s))
            hint.setOnClickListener { input.setText(Ui.plain(a, s)) }
        } else hint.visibility = View.GONE
        val d = MaterialAlertDialogBuilder(a)
            .setTitle(a.getString(R.string.budget_for, c.name))
            .setView(v)
            .setPositiveButton(R.string.save) { _, _ ->
                val amount = Ui.amountOf(a, input) ?: 0
                Store.saveCategory(a, c.copy(budget = amount, rollover = roll.isChecked))
            }
            .setNegativeButton(R.string.cancel, null)
        if (c.budget > 0) d.setNeutralButton(R.string.remove_budget) { _, _ -> Store.saveCategory(a, c.copy(budget = 0, rollover = false)) }
        d.show()
    }
}
