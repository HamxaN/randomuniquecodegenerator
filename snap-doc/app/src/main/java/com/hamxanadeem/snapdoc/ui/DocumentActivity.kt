package com.hamxanadeem.snapdoc.ui

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.ItemTouchHelper
import androidx.recyclerview.widget.RecyclerView
import com.hamxanadeem.snapdoc.R
import com.hamxanadeem.snapdoc.ads.AdsManager
import com.hamxanadeem.snapdoc.core.Document
import com.hamxanadeem.snapdoc.core.Library
import com.hamxanadeem.snapdoc.data.Store
import com.hamxanadeem.snapdoc.data.Thumbs

/** One document: its pages in a grid (drag to reorder) and the PDF, text and page actions. */
class DocumentActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_ID = "doc_id"
    }

    private lateinit var id: String
    private lateinit var title: TextView
    private lateinit var adapter: PageAdapter
    private lateinit var scanner: Scanner
    private val onChange: () -> Unit = { refresh() }

    private val saveAs = registerForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")) { uri ->
        val doc = doc() ?: return@registerForActivityResult
        if (uri == null) return@registerForActivityResult
        Ui.toast(this, getString(R.string.making_pdf))
        Store.savePdfTo(this, doc, uri) { ok ->
            Ui.toast(this, getString(if (ok) R.string.pdf_saved else R.string.pdf_failed))
        }
    }

    private fun doc(): Document? = Store.library(this).get(id)

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_document)
        Ui.fitSystemBars(findViewById(R.id.root))
        id = intent.getStringExtra(EXTRA_ID) ?: run {
            finish()
            return
        }
        title = findViewById(R.id.title)
        adapter = PageAdapter()
        val grid = findViewById<RecyclerView>(R.id.pages)
        grid.layoutManager = GridLayoutManager(this, 2)
        grid.adapter = adapter
        ItemTouchHelper(object : ItemTouchHelper.SimpleCallback(
            ItemTouchHelper.UP or ItemTouchHelper.DOWN or ItemTouchHelper.LEFT or ItemTouchHelper.RIGHT, 0,
        ) {
            override fun onMove(rv: RecyclerView, from: RecyclerView.ViewHolder, to: RecyclerView.ViewHolder): Boolean {
                adapter.move(from.bindingAdapterPosition, to.bindingAdapterPosition)
                return true
            }

            override fun onSwiped(viewHolder: RecyclerView.ViewHolder, direction: Int) = Unit

            override fun clearView(rv: RecyclerView, viewHolder: RecyclerView.ViewHolder) {
                super.clearView(rv, viewHolder)
                adapter.commitMove()
            }
        }).attachToRecyclerView(grid)

        scanner = Scanner(this) { uris ->
            Ui.toast(this, getString(R.string.saving))
            Store.addPages(this, id, uris) { }
        }
        findViewById<View>(R.id.back).setOnClickListener { finish() }
        findViewById<View>(R.id.rename).setOnClickListener { doc()?.let { Ui.renameDialog(this, it) } }
        findViewById<View>(R.id.delete).setOnClickListener { doc()?.let { Ui.deleteDialog(this, it) { finish() } } }
        findViewById<View>(R.id.add).setOnClickListener { scanner.start() }
        findViewById<View>(R.id.share).setOnClickListener { doc()?.let { Ui.sharePdf(this, it) } }
        findViewById<View>(R.id.save).setOnClickListener { doc()?.let { saveAs.launch(Library.pdfFileName(it.name)) } }
        findViewById<View>(R.id.text).setOnClickListener { doc()?.let { Ui.recognizeText(this, it, it.pages.indices.toList()) } }
        AdsManager.loadBanner(this, findViewById<FrameLayout>(R.id.ad_container))
        Store.addListener(onChange)
        refresh()
    }

    override fun onDestroy() {
        Store.removeListener(onChange)
        super.onDestroy()
    }

    private fun refresh() {
        val d = doc() ?: run {
            finish()
            return
        }
        title.text = d.name
        adapter.submit(d)
    }

    private inner class PageAdapter : RecyclerView.Adapter<PageAdapter.Holder>() {
        private var doc: Document? = null
        private var order: MutableList<Int> = mutableListOf()
        private var dragFrom = -1
        private var dragTo = -1

        fun submit(d: Document) {
            doc = d
            order = d.pages.indices.toMutableList()
            notifyDataSetChanged()
        }

        fun move(from: Int, to: Int) {
            if (from < 0 || to < 0) return
            if (dragFrom < 0) dragFrom = from
            dragTo = to
            order.add(to, order.removeAt(from))
            notifyItemMoved(from, to)
        }

        fun commitMove() {
            if (dragFrom >= 0 && dragTo >= 0 && dragFrom != dragTo) {
                Store.movePage(this@DocumentActivity, id, dragFrom, dragTo)
            }
            dragFrom = -1
            dragTo = -1
        }

        inner class Holder(v: View) : RecyclerView.ViewHolder(v) {
            val image: ImageView = v.findViewById(R.id.image)
            val number: TextView = v.findViewById(R.id.number)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            Holder(LayoutInflater.from(parent.context).inflate(R.layout.item_page, parent, false))

        override fun getItemCount() = order.size

        override fun onBindViewHolder(h: Holder, position: Int) {
            val d = doc ?: return
            val page = order[position]
            h.number.text = (position + 1).toString()
            Thumbs.load(h.image, Store.pageFile(this@DocumentActivity, d, page).path, 512)
            h.itemView.setOnClickListener {
                startActivity(
                    Intent(this@DocumentActivity, PageActivity::class.java)
                        .putExtra(EXTRA_ID, id)
                        .putExtra(PageActivity.EXTRA_PAGE, h.bindingAdapterPosition),
                )
            }
        }
    }
}
