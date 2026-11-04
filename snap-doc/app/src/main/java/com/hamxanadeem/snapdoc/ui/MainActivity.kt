package com.hamxanadeem.snapdoc.ui

import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.PopupMenu
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.hamxanadeem.snapdoc.R
import com.hamxanadeem.snapdoc.ads.AdsManager
import com.hamxanadeem.snapdoc.core.Document
import com.hamxanadeem.snapdoc.data.Store
import com.hamxanadeem.snapdoc.data.Thumbs

/** The document library: search, the list of scans, and the Scan button. */
class MainActivity : AppCompatActivity() {

    private lateinit var adapter: DocAdapter
    private lateinit var search: EditText
    private lateinit var empty: View
    private lateinit var emptyTitle: TextView
    private lateinit var emptyBody: TextView
    private lateinit var scanner: Scanner
    private val onChange: () -> Unit = { refresh() }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        Ui.fitSystemBars(findViewById(R.id.root))
        search = findViewById(R.id.search)
        empty = findViewById(R.id.empty)
        emptyTitle = findViewById(R.id.empty_title)
        emptyBody = findViewById(R.id.empty_body)
        adapter = DocAdapter()
        findViewById<RecyclerView>(R.id.list).apply {
            layoutManager = LinearLayoutManager(this@MainActivity)
            adapter = this@MainActivity.adapter
        }
        scanner = Scanner(this) { uris ->
            Ui.toast(this, getString(R.string.saving))
            Store.createDocument(this, uris) { result ->
                result.onSuccess { open(it) }
                    .onFailure { Ui.toast(this, getString(R.string.scan_failed, it.message ?: "")) }
            }
        }
        findViewById<View>(R.id.scan).setOnClickListener { scanner.start() }
        search.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) = refresh()
        })
        val privacy = findViewById<ImageButton>(R.id.privacy)
        privacy.setOnClickListener { AdsManager.showPrivacyOptions(this) }
        AdsManager.initialize(this)
        AdsManager.loadBanner(this, findViewById<FrameLayout>(R.id.ad_container))
        privacy.post { privacy.visibility = if (AdsManager.isPrivacyOptionsRequired(this)) View.VISIBLE else View.GONE }
        Store.addListener(onChange)
        refresh()
    }

    override fun onDestroy() {
        Store.removeListener(onChange)
        super.onDestroy()
    }

    private fun refresh() {
        val lib = Store.library(this)
        val query = search.text.toString()
        val docs = lib.search(query)
        adapter.submit(docs)
        empty.visibility = if (docs.isEmpty()) View.VISIBLE else View.GONE
        if (lib.documents.isEmpty()) {
            emptyTitle.setText(R.string.empty_title)
            emptyBody.visibility = View.VISIBLE
        } else {
            emptyTitle.setText(R.string.no_results)
            emptyBody.visibility = View.GONE
        }
    }

    private fun open(doc: Document) {
        startActivity(Intent(this, DocumentActivity::class.java).putExtra(DocumentActivity.EXTRA_ID, doc.id))
    }

    private inner class DocAdapter : RecyclerView.Adapter<DocAdapter.Holder>() {
        private var items: List<Document> = emptyList()

        fun submit(list: List<Document>) {
            items = list
            notifyDataSetChanged()
        }

        inner class Holder(v: View) : RecyclerView.ViewHolder(v) {
            val thumb: ImageView = v.findViewById(R.id.thumb)
            val name: TextView = v.findViewById(R.id.name)
            val meta: TextView = v.findViewById(R.id.meta)
            val share: ImageButton = v.findViewById(R.id.share)
            val more: ImageButton = v.findViewById(R.id.more)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            Holder(LayoutInflater.from(parent.context).inflate(R.layout.item_document, parent, false))

        override fun getItemCount() = items.size

        override fun onBindViewHolder(h: Holder, position: Int) {
            val doc = items[position]
            h.name.text = doc.name
            h.meta.text = Ui.meta(this@MainActivity, doc)
            Thumbs.load(h.thumb, Store.pageFile(this@MainActivity, doc, 0).path, 256)
            h.itemView.setOnClickListener { open(doc) }
            h.share.setOnClickListener { Ui.sharePdf(this@MainActivity, doc) }
            h.more.setOnClickListener { v ->
                PopupMenu(this@MainActivity, v).apply {
                    menu.add(0, 1, 0, R.string.rename)
                    menu.add(0, 2, 1, R.string.extract_text)
                    menu.add(0, 3, 2, R.string.delete)
                    setOnMenuItemClickListener { item ->
                        when (item.itemId) {
                            1 -> Ui.renameDialog(this@MainActivity, doc)
                            2 -> Ui.recognizeText(this@MainActivity, doc, doc.pages.indices.toList())
                            3 -> Ui.deleteDialog(this@MainActivity, doc)
                        }
                        true
                    }
                    show()
                }
            }
        }
    }
}
