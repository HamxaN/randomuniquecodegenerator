package com.hamxanadeem.spendwise.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.chip.Chip
import com.google.android.material.chip.ChipGroup
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.core.Category
import com.hamxanadeem.spendwise.core.Kind
import com.hamxanadeem.spendwise.data.Store

/** Add, rename, recolour or remove categories, and teach them keywords. */
class CategoriesActivity : BaseActivity() {

    private var kind = Kind.EXPENSE
    private var rows: List<Category> = emptyList()
    private val onChange: () -> Unit = { refresh() }
    private val adapter = object : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
        override fun getItemCount() = rows.size
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            object : RecyclerView.ViewHolder(LayoutInflater.from(parent.context).inflate(R.layout.item_row, parent, false)) {}

        override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
            val c = rows[position]
            val v = holder.itemView
            val l = Store.ledger(this@CategoriesActivity)
            Ui.badge(v.findViewById(R.id.badge), c)
            v.findViewById<TextView>(R.id.title).text = c.name
            val count = l.txns.count { it.categoryId == c.id }
            v.findViewById<TextView>(R.id.subtitle).text = buildList {
                add(resources.getQuantityString(R.plurals.txn_count, count, count))
                if (c.keywords.isNotEmpty()) add(c.keywords.take(4).joinToString(", "))
            }.joinToString(" · ")
            v.findViewById<TextView>(R.id.trailing).text =
                if (c.budget > 0) getString(R.string.per_month, Ui.money(this@CategoriesActivity, c.budget)) else ""
            v.setOnClickListener { edit(c) }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_categories)
        Ui.fitSystemBars(findViewById(R.id.root))
        findViewById<MaterialToolbar>(R.id.toolbar).setNavigationOnClickListener { finish() }
        findViewById<RecyclerView>(R.id.list).apply {
            layoutManager = LinearLayoutManager(this@CategoriesActivity)
            adapter = this@CategoriesActivity.adapter
        }
        findViewById<MaterialButtonToggleGroup>(R.id.type).addOnButtonCheckedListener { _, id, checked ->
            if (checked) {
                kind = if (id == R.id.type_income) Kind.INCOME else Kind.EXPENSE
                refresh()
            }
        }
        findViewById<View>(R.id.add).setOnClickListener { edit(null) }
        Store.addListener(onChange)
        refresh()
    }

    override fun onDestroy() {
        Store.removeListener(onChange)
        super.onDestroy()
    }

    private fun refresh() {
        rows = Store.ledger(this).categoriesOf(kind)
        @Suppress("NotifyDataSetChanged")
        adapter.notifyDataSetChanged()
    }

    private fun edit(existing: Category?) {
        val v = LayoutInflater.from(this).inflate(R.layout.dialog_category, null as ViewGroup?)
        val name = v.findViewById<EditText>(R.id.name)
        val keywords = v.findViewById<EditText>(R.id.keywords)
        val emojiGroup = v.findViewById<ChipGroup>(R.id.emoji)
        val colorGroup = v.findViewById<ChipGroup>(R.id.colors)
        var icon = existing?.icon ?: Ui.EMOJI.first()
        var color = existing?.color ?: Ui.COLORS[(rows.size) % Ui.COLORS.size]
        name.setText(existing?.name ?: "")
        keywords.setText(existing?.keywords?.joinToString(", ") ?: "")

        val emojis = (listOf(Ui.emoji(icon)) + Ui.EMOJI).distinct()
        for (e in emojis) {
            emojiGroup.addView(Chip(this).apply {
                id = View.generateViewId()
                text = e
                isCheckable = true
                isCheckedIconVisible = false
                isChecked = e == Ui.emoji(icon)
                setOnClickListener { icon = if (Ui.emoji(existing?.icon ?: "") == e) existing!!.icon else e }
            })
        }
        for (c in Ui.COLORS.let { if (color in it) it else listOf(color) + it }) {
            colorGroup.addView(Chip(this).apply {
                id = View.generateViewId()
                text = " "
                isCheckable = true
                chipBackgroundColor = android.content.res.ColorStateList.valueOf(c.toInt())
                isChecked = c == color
                contentDescription = getString(R.string.color_choice)
                setOnClickListener { color = c }
            })
        }

        val d = MaterialAlertDialogBuilder(this)
            .setTitle(if (existing == null) R.string.category_new else R.string.category_edit)
            .setView(v)
            .setPositiveButton(R.string.save) { _, _ ->
                val n = name.text.toString().trim()
                if (n.isEmpty()) return@setPositiveButton
                val words = keywords.text.toString().split(',').map { it.trim().lowercase() }.filter { it.isNotEmpty() }.distinct()
                val c = existing?.copy(name = n, icon = icon, color = color, keywords = words)
                    ?: Category("c_" + Store.newId(), n, icon, color, kind, keywords = words)
                Store.saveCategory(this, c)
            }
            .setNegativeButton(R.string.cancel, null)
        if (existing != null) d.setNeutralButton(R.string.delete) { _, _ -> remove(existing) }
        d.show()
    }

    private fun remove(c: Category) {
        val others = Store.ledger(this).categoriesOf(c.kind).filter { it.id != c.id }
        if (others.isEmpty()) {
            Ui.toast(this, getString(R.string.category_last))
            return
        }
        val count = Store.ledger(this).txns.count { it.categoryId == c.id }
        if (count == 0) {
            Store.deleteCategory(this, c.id, others.first().id)
            return
        }
        // Its transactions need a new home.
        MaterialAlertDialogBuilder(this)
            .setTitle(resources.getQuantityString(R.plurals.move_title, count, count))
            .setItems(others.map { "${Ui.emoji(it.icon)}  ${it.name}" }.toTypedArray()) { _, which ->
                Store.deleteCategory(this, c.id, others[which].id)
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }
}
