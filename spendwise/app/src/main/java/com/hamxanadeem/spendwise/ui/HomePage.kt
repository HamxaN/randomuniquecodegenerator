package com.hamxanadeem.spendwise.ui

import android.text.Editable
import android.text.TextWatcher
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.core.Budgets
import com.hamxanadeem.spendwise.core.Defaults
import com.hamxanadeem.spendwise.core.Draft
import com.hamxanadeem.spendwise.core.Insight
import com.hamxanadeem.spendwise.core.Insights
import com.hamxanadeem.spendwise.core.Kind
import com.hamxanadeem.spendwise.core.QuickAdd
import com.hamxanadeem.spendwise.core.Txn
import com.hamxanadeem.spendwise.data.Store
import java.time.LocalDate
import java.time.YearMonth

/** The month at a glance, a quick-add box that understands plain words, tips, and recent spending. */
class HomePage(private val a: MainActivity) : Page {

    override val view: View = LayoutInflater.from(a).inflate(R.layout.page_home, a.findViewById(R.id.pages), false)
    private val input = view.findViewById<EditText>(R.id.quick_input)
    private val preview = view.findViewById<TextView>(R.id.quick_preview)

    init {
        input.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) = updatePreview()
        })
        input.setOnEditorActionListener { _, actionId, event ->
            if (actionId == EditorInfo.IME_ACTION_DONE || event?.keyCode == KeyEvent.KEYCODE_ENTER) {
                commit()
                true
            } else false
        }
        view.findViewById<View>(R.id.quick_send).setOnClickListener { commit() }
        view.findViewById<View>(R.id.see_all).setOnClickListener { a.select(R.id.tab_activity) }
        view.findViewById<View>(R.id.summary).setOnClickListener { a.select(R.id.tab_budgets) }
    }

    private fun draft(): Draft? {
        val text = input.text.toString().trim()
        if (text.isEmpty()) return null
        return QuickAdd.parse(text, LocalDate.now(), Store.ledger(a), Store.categorizer(a))
    }

    private fun updatePreview() {
        val d = draft()
        if (d == null) {
            preview.visibility = View.GONE
            return
        }
        val cat = Store.ledger(a).category(d.categoryId ?: fallback(d.kind))
        val parts = mutableListOf<String>()
        parts += if (d.amount != null) (if (d.kind == Kind.INCOME) "+" else "−") + Ui.money(a, d.amount!!) else a.getString(R.string.quick_no_amount)
        parts += "${Ui.emoji(cat?.icon ?: "")} ${cat?.name ?: ""}"
        if (d.note.isNotBlank()) parts += "“${d.note}”"
        parts += Ui.day(a, d.date)
        preview.text = parts.joinToString("  ·  ")
        preview.visibility = View.VISIBLE
    }

    private fun fallback(kind: Kind) = if (kind == Kind.INCOME) Defaults.FALLBACK_INCOME else Defaults.FALLBACK_EXPENSE

    private fun commit() {
        val d = draft() ?: return
        val amount = d.amount
        if (amount == null) {
            // Nothing to save yet: finish it in the full editor.
            a.startActivity(EditActivity.intent(a, note = d.note, date = d.date, kind = d.kind))
            input.text.clear()
            return
        }
        val t = Txn(Store.newId(), amount, d.kind, d.categoryId ?: fallback(d.kind), d.note, d.date, createdAt = System.currentTimeMillis())
        val alert = Saving.save(a, t, null)
        input.text.clear()
        a.getSystemService(InputMethodManager::class.java)?.hideSoftInputFromWindow(input.windowToken, 0)
        val cat = Store.ledger(a).category(t.categoryId)?.name ?: ""
        a.snack(alert ?: a.getString(R.string.quick_added, Ui.money(a, amount), cat), a.getString(R.string.edit)) {
            a.startActivity(EditActivity.intent(a, t.id))
        }
    }

    override fun refresh() {
        val l = Store.ledger(a)
        val today = LocalDate.now()
        val month = YearMonth.from(today)
        val spent = l.total(month, Kind.EXPENSE)
        val income = l.total(month, Kind.INCOME)
        view.findViewById<TextView>(R.id.month_label).text = a.getString(R.string.spent_in, Ui.month(month))
        view.findViewById<TextView>(R.id.spent).text = Ui.money(a, spent)
        view.findViewById<TextView>(R.id.income_value).text = Ui.money(a, income)
        view.findViewById<TextView>(R.id.balance_value).text = Ui.money(a, income - spent)
        val budgets = Budgets.status(l, month)
        val bar = view.findViewById<BudgetBarView>(R.id.month_bar)
        val limit = if (budgets.isNotEmpty()) budgets.sumOf { it.available } else income
        if (limit > 0) {
            val f = spent.toDouble() / limit
            bar.set(f, if (f > 1) R.color.expense else if (f >= 0.8) R.color.warning else R.color.hero_bar,
                today.dayOfMonth.toDouble() / month.lengthOfMonth())
            bar.visibility = View.VISIBLE
        } else bar.visibility = View.GONE
        val safe = Budgets.safeToSpendPerDay(l, month, today)
        view.findViewById<TextView>(R.id.safe).text =
            if (limit > 0) a.getString(R.string.safe_to_spend, Ui.money(a, safe))
            else a.getString(R.string.safe_hint)

        val tips = view.findViewById<LinearLayout>(R.id.insights)
        tips.removeAllViews()
        val cards = Insights.cards(l, today) { Ui.money(a, it) }.take(4)
        for (c in cards) tips.addView(insightView(c))
        view.findViewById<View>(R.id.insights_title).visibility = if (cards.isEmpty()) View.GONE else View.VISIBLE

        val recent = view.findViewById<LinearLayout>(R.id.recent)
        recent.removeAllViews()
        val latest = l.txns.sortedWith(compareByDescending<Txn> { it.date }.thenByDescending { it.createdAt }).take(6)
        for (t in latest) {
            val row = TxnRows.inflate(a, recent)
            TxnRows.bind(row, t, true) { a.startActivity(EditActivity.intent(a, it.id)) }
            recent.addView(row)
        }
        view.findViewById<View>(R.id.empty).visibility = if (latest.isEmpty()) View.VISIBLE else View.GONE
        view.findViewById<View>(R.id.see_all).visibility = if (latest.isEmpty()) View.GONE else View.VISIBLE
    }

    private fun insightView(i: Insight): View {
        val v = LayoutInflater.from(a).inflate(R.layout.item_insight, view.findViewById(R.id.insights), false)
        v.findViewById<TextView>(R.id.icon).text = insightIcon(i.kind)
        v.findViewById<TextView>(R.id.title).text = i.title
        v.findViewById<TextView>(R.id.detail).text = i.detail
        v.setOnClickListener {
            a.select(
                when (i.kind) {
                    Insight.Type.BUDGET -> R.id.tab_budgets
                    else -> R.id.tab_insights
                }
            )
        }
        return v
    }

    private fun insightIcon(t: Insight.Type) = when (t) {
        Insight.Type.FORECAST -> "🔮"
        Insight.Type.BUDGET -> "🎯"
        Insight.Type.TREND -> "📈"
        Insight.Type.ANOMALY -> "⚠️"
        Insight.Type.SUBSCRIPTION -> "🔁"
        Insight.Type.SAVING -> "🌱"
    }
}

/** Saves a transaction and raises a budget alert if it tipped one over. */
object Saving {
    fun save(context: android.content.Context, t: Txn, repeat: com.hamxanadeem.spendwise.core.Every?): String? {
        val (before, after) = Store.saveTxn(context, t, repeat)
        val msg = Alerts.message(context, before, after)
        if (msg != null) Alerts.notify(context, msg)
        return msg
    }
}
