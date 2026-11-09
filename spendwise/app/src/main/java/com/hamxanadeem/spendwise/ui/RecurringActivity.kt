package com.hamxanadeem.spendwise.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.core.Kind
import com.hamxanadeem.spendwise.core.Recurring
import com.hamxanadeem.spendwise.data.Store
import java.time.LocalDate

/** Bills, salary and subscriptions that are added automatically when due. */
class RecurringActivity : BaseActivity() {

    private var rows: List<Recurring> = emptyList()
    private val onChange: () -> Unit = { refresh() }
    private val adapter = object : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
        override fun getItemCount() = rows.size
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            object : RecyclerView.ViewHolder(LayoutInflater.from(parent.context).inflate(R.layout.item_row, parent, false)) {}

        override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
            val r = rows[position]
            val v = holder.itemView
            val a = this@RecurringActivity
            val cat = Store.ledger(a).category(r.categoryId)
            Ui.badge(v.findViewById(R.id.badge), cat)
            v.findViewById<TextView>(R.id.title).text = r.note.ifBlank { cat?.name ?: "" }
            v.findViewById<TextView>(R.id.subtitle).text =
                getString(R.string.rule_line, getString(InsightsPage.everyLabel(r.every)), Ui.day(a, r.next(LocalDate.now())))
            v.findViewById<TextView>(R.id.trailing).text = (if (r.kind == Kind.INCOME) "+" else "−") + Ui.money(a, r.amount)
            v.setOnClickListener { stop(r) }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_recurring)
        Ui.fitSystemBars(findViewById(R.id.root))
        findViewById<MaterialToolbar>(R.id.toolbar).setNavigationOnClickListener { finish() }
        findViewById<RecyclerView>(R.id.list).apply {
            layoutManager = LinearLayoutManager(this@RecurringActivity)
            adapter = this@RecurringActivity.adapter
        }
        Store.addListener(onChange)
        refresh()
    }

    override fun onDestroy() {
        Store.removeListener(onChange)
        super.onDestroy()
    }

    private fun refresh() {
        val today = LocalDate.now()
        rows = Store.ledger(this).recurring.sortedBy { it.next(today) }
        @Suppress("NotifyDataSetChanged")
        adapter.notifyDataSetChanged()
        findViewById<View>(R.id.empty).visibility = if (rows.isEmpty()) View.VISIBLE else View.GONE
        val monthly = rows.filter { it.kind == Kind.EXPENSE }.sumOf { Math.round(it.amount * it.every.perYear / 12) }
        findViewById<TextView>(R.id.summary).apply {
            text = getString(R.string.recurring_summary, Ui.money(this@RecurringActivity, monthly))
            visibility = if (rows.isEmpty()) View.GONE else View.VISIBLE
        }
    }

    private fun stop(r: Recurring) {
        MaterialAlertDialogBuilder(this)
            .setTitle(getString(R.string.stop_title, r.note.ifBlank { Store.ledger(this).category(r.categoryId)?.name ?: "" }))
            .setMessage(R.string.stop_body)
            .setPositiveButton(R.string.stop) { _, _ -> Store.deleteRecurring(this, r.id) }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }
}
