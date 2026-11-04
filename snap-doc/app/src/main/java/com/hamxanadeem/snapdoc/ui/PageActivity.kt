package com.hamxanadeem.snapdoc.ui

import android.graphics.Color
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.PagerSnapHelper
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.hamxanadeem.snapdoc.R
import com.hamxanadeem.snapdoc.core.Document
import com.hamxanadeem.snapdoc.data.Store
import com.hamxanadeem.snapdoc.data.Thumbs

/** Pages full screen, swiping between them, with rotate, read text and delete. */
class PageActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_PAGE = "page"
    }

    private lateinit var id: String
    private lateinit var pager: RecyclerView
    private lateinit var title: TextView
    private val adapter = ViewerAdapter()
    private val onChange: () -> Unit = { refresh() }

    private fun doc(): Document? = Store.library(this).get(id)

    private fun current(): Int {
        val lm = pager.layoutManager as LinearLayoutManager
        val p = lm.findFirstCompletelyVisibleItemPosition()
        return if (p >= 0) p else lm.findFirstVisibleItemPosition().coerceAtLeast(0)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Light icons on the dark viewer.
        enableEdgeToEdge(SystemBarStyle.dark(Color.TRANSPARENT), SystemBarStyle.dark(Color.TRANSPARENT))
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_page)
        Ui.fitSystemBars(findViewById(R.id.root))
        id = intent.getStringExtra(DocumentActivity.EXTRA_ID) ?: run {
            finish()
            return
        }
        title = findViewById(R.id.title)
        pager = findViewById(R.id.pager)
        pager.layoutManager = LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false)
        pager.adapter = adapter
        PagerSnapHelper().attachToRecyclerView(pager)
        pager.addOnScrollListener(object : RecyclerView.OnScrollListener() {
            override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) {
                if (newState == RecyclerView.SCROLL_STATE_IDLE) updateTitle()
            }
        })
        findViewById<View>(R.id.back).setOnClickListener { finish() }
        findViewById<View>(R.id.rotate_left).setOnClickListener { rotate(false) }
        findViewById<View>(R.id.rotate_right).setOnClickListener { rotate(true) }
        findViewById<View>(R.id.text).setOnClickListener { doc()?.let { Ui.recognizeText(this, it, listOf(current())) } }
        findViewById<View>(R.id.delete).setOnClickListener { deletePage() }
        Store.addListener(onChange)
        refresh()
        pager.scrollToPosition(intent.getIntExtra(EXTRA_PAGE, 0))
        pager.post { updateTitle() }
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
        adapter.submit(d)
        updateTitle()
    }

    private fun updateTitle() {
        val d = doc() ?: return
        title.text = getString(R.string.page_of, current() + 1, d.pages.size)
    }

    private fun rotate(clockwise: Boolean) {
        Store.rotatePage(this, id, current(), clockwise) { }
    }

    private fun deletePage() {
        val d = doc() ?: return
        if (d.pages.size <= 1) {
            Ui.toast(this, getString(R.string.last_page))
            return
        }
        val index = current()
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.delete_page_title)
            .setPositiveButton(R.string.delete) { _, _ -> Store.deletePage(this, id, index) }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private inner class ViewerAdapter : RecyclerView.Adapter<ViewerAdapter.Holder>() {
        private var doc: Document? = null

        fun submit(d: Document) {
            doc = d
            notifyDataSetChanged()
        }

        inner class Holder(v: View) : RecyclerView.ViewHolder(v) {
            val image: ImageView = v as ImageView
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder {
            val v = LayoutInflater.from(parent.context).inflate(R.layout.item_viewer_page, parent, false)
            v.layoutParams = RecyclerView.LayoutParams(parent.width, ViewGroup.LayoutParams.MATCH_PARENT)
            return Holder(v)
        }

        override fun getItemCount() = doc?.pages?.size ?: 0

        override fun onBindViewHolder(h: Holder, position: Int) {
            val d = doc ?: return
            Thumbs.load(h.image, Store.pageFile(this@PageActivity, d, position).path, 2048)
        }
    }
}
