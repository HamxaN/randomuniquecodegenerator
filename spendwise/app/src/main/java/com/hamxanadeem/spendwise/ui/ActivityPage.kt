package com.hamxanadeem.spendwise.ui

import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.widget.EditText
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.chip.ChipGroup
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.core.Kind
import com.hamxanadeem.spendwise.core.Txn
import com.hamxanadeem.spendwise.data.Store
import java.util.Locale

/** Every transaction, by day: browse a month, filter by type, or search all of them. */
class ActivityPage(private val a: MainActivity) : Page {

    override val view: View = LayoutInflater.from(a).inflate(R.layout.page_activity, a.findViewById(R.id.pages), false)
    private val adapter = TxnAdapter { a.startActivity(EditActivity.intent(a, it.id)) }
    private val search = view.findViewById<EditText>(R.id.search)
    private val filter = view.findViewById<ChipGroup>(R.id.filter)
    private val nav = MonthNav(view) { refresh() }

    init {
        view.findViewById<RecyclerView>(R.id.list).apply {
            layoutManager = LinearLayoutManager(a)
            adapter = this@ActivityPage.adapter
        }
        search.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) = refresh()
        })
        filter.setOnCheckedStateChangeListener { _, _ -> refresh() }
    }

    override fun refresh() {
        nav.update()
        val l = Store.ledger(a)
        val q = search.text.toString().trim().lowercase(Locale.getDefault())
        val kind = when (filter.checkedChipId) {
            R.id.chip_expense -> Kind.EXPENSE
            R.id.chip_income -> Kind.INCOME
            else -> null
        }
        // A search looks through every month; otherwise show the chosen month.
        val txns = (if (q.isEmpty()) l.inMonth(nav.month) else l.txns.toList())
            .filter { kind == null || it.kind == kind }
            .filter { q.isEmpty() || matches(it, q) }
        adapter.submit(txns)
        val spent = txns.filter { it.kind == Kind.EXPENSE }.sumOf { it.amount }
        val earned = txns.filter { it.kind == Kind.INCOME }.sumOf { it.amount }
        view.findViewById<TextView>(R.id.totals).text = buildString {
            if (q.isNotEmpty()) append(a.resources.getQuantityString(R.plurals.results, txns.size, txns.size)).append(" · ")
            append(a.getString(R.string.totals, Ui.money(a, spent), Ui.money(a, earned)))
        }
        view.findViewById<View>(R.id.month_nav).visibility = if (q.isEmpty()) View.VISIBLE else View.INVISIBLE
        view.findViewById<TextView>(R.id.empty).apply {
            visibility = if (txns.isEmpty()) View.VISIBLE else View.GONE
            setText(if (q.isEmpty()) R.string.empty_month else R.string.empty_search)
        }
    }

    private fun matches(t: Txn, q: String): Boolean {
        val l = Store.ledger(a)
        val cat = l.category(t.categoryId)?.name ?: ""
        return t.note.lowercase(Locale.getDefault()).contains(q) ||
            cat.lowercase(Locale.getDefault()).contains(q) ||
            Ui.plain(a, t.amount).startsWith(q)
    }
}
