package com.hamxanadeem.spendwise.ui

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.core.Kind
import com.hamxanadeem.spendwise.core.Txn
import com.hamxanadeem.spendwise.data.Store
import java.time.LocalDate

/** Shows one transaction in an `item_txn` row. */
object TxnRows {
    fun bind(view: View, t: Txn, showDate: Boolean, onClick: (Txn) -> Unit) {
        val c = view.context
        val cat = Store.ledger(c).category(t.categoryId)
        Ui.badge(view.findViewById(R.id.badge), cat)
        val catName = cat?.name ?: c.getString(R.string.category_missing)
        view.findViewById<TextView>(R.id.title).text = t.note.ifBlank { catName }
        val parts = mutableListOf<String>()
        if (t.note.isNotBlank()) parts += catName
        if (showDate) parts += Ui.day(c, t.date)
        if (t.recurringId != null) parts += c.getString(R.string.repeats_short)
        view.findViewById<TextView>(R.id.subtitle).apply {
            text = parts.joinToString(" · ")
            visibility = if (parts.isEmpty()) View.GONE else View.VISIBLE
        }
        view.findViewById<TextView>(R.id.amount).apply {
            text = Ui.signed(c, t)
            setTextColor(ContextCompat.getColor(c, if (t.kind == Kind.INCOME) R.color.income else R.color.ink))
        }
        view.setOnClickListener { onClick(t) }
    }

    fun inflate(context: Context, parent: ViewGroup): View =
        LayoutInflater.from(context).inflate(R.layout.item_txn, parent, false)
}

/** Transactions grouped under day headings, newest first. */
class TxnAdapter(private val onClick: (Txn) -> Unit) : RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    private sealed interface Item
    private data class Header(val date: LocalDate, val spent: Long) : Item
    private data class Row(val txn: Txn) : Item

    private var items: List<Item> = emptyList()

    fun submit(txns: List<Txn>) {
        val out = mutableListOf<Item>()
        txns.groupBy { it.date }.toSortedMap(compareByDescending { it }).forEach { (d, list) ->
            out += Header(d, list.filter { it.kind == Kind.EXPENSE }.sumOf { it.amount })
            list.sortedByDescending { it.createdAt }.forEach { out += Row(it) }
        }
        items = out
        @Suppress("NotifyDataSetChanged")
        notifyDataSetChanged()
    }

    override fun getItemCount() = items.size

    override fun getItemViewType(position: Int) = if (items[position] is Header) 0 else 1

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val v = if (viewType == 0) LayoutInflater.from(parent.context).inflate(R.layout.item_header, parent, false)
        else TxnRows.inflate(parent.context, parent)
        return object : RecyclerView.ViewHolder(v) {}
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        val v = holder.itemView
        when (val item = items[position]) {
            is Header -> {
                v.findViewById<TextView>(R.id.label).text = Ui.day(v.context, item.date)
                v.findViewById<TextView>(R.id.value).text =
                    if (item.spent > 0) "−" + Ui.money(v.context, item.spent) else ""
            }
            is Row -> TxnRows.bind(v, item.txn, false, onClick)
        }
    }
}
