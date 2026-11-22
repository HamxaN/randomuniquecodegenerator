package com.hamxanadeem.scamradar.ui

import android.content.Intent
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.format.DateUtils
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.hamxanadeem.scamradar.R
import com.hamxanadeem.scamradar.core.Check
import com.hamxanadeem.scamradar.data.Store

/** Messages checked on this phone, newest first. Tap one to check it again. */
class HistoryActivity : AppCompatActivity() {

    private var rows: List<Check> = emptyList()
    private val adapter = object : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
        override fun getItemCount() = rows.size

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            object : RecyclerView.ViewHolder(LayoutInflater.from(parent.context).inflate(R.layout.item_history, parent, false)) {}

        override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
            val c = rows[position]
            val v = holder.itemView
            val a = this@HistoryActivity
            val urdu = Store.urdu(a)
            v.findViewById<View>(R.id.dot).background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Ui.color(a, c.verdict))
            }
            v.findViewById<TextView>(R.id.title).text = Ui.verdictText(a, c.verdict, urdu) +
                (if (c.type.name != "NONE") "  ·  " + (if (urdu) c.type.ur else c.type.en) else "")
            v.findViewById<TextView>(R.id.excerpt).text = c.text.trim().replace(Regex("\\s+"), " ")
            v.findViewById<TextView>(R.id.time).text = DateUtils.getRelativeTimeSpanString(c.time)
            v.setOnClickListener {
                startActivity(Intent(a, MainActivity::class.java).putExtra(MainActivity.EXTRA_CHECK, c.text)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                finish()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_list)
        Ui.fitSystemBars(findViewById(R.id.root))
        val toolbar = findViewById<MaterialToolbar>(R.id.toolbar)
        toolbar.setTitle(R.string.history)
        toolbar.setNavigationOnClickListener { finish() }
        toolbar.inflateMenu(R.menu.history)
        toolbar.setOnMenuItemClickListener {
            if (it.itemId == R.id.action_clear) {
                MaterialAlertDialogBuilder(this)
                    .setTitle(R.string.clear_title)
                    .setPositiveButton(R.string.clear) { _, _ ->
                        Store.clear(this)
                        refresh()
                    }
                    .setNegativeButton(R.string.cancel, null)
                    .show()
            }
            true
        }
        findViewById<RecyclerView>(R.id.list).apply {
            layoutManager = LinearLayoutManager(this@HistoryActivity)
            adapter = this@HistoryActivity.adapter
        }
        refresh()
    }

    private fun refresh() {
        rows = Store.history(this)
        @Suppress("NotifyDataSetChanged")
        adapter.notifyDataSetChanged()
        findViewById<View>(R.id.empty).visibility = if (rows.isEmpty()) View.VISIBLE else View.GONE
    }
}
