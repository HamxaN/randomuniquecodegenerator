package com.hamxanadeem.snapdoc.ui

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import com.google.android.gms.tasks.Tasks
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.hamxanadeem.snapdoc.R
import com.hamxanadeem.snapdoc.core.Document
import com.hamxanadeem.snapdoc.data.Store
import com.hamxanadeem.snapdoc.data.Thumbs
import java.text.DateFormat
import java.util.Date
import java.util.concurrent.Executors

/** Small helpers shared by the screens. */
object Ui {

    private val ocrPool = Executors.newSingleThreadExecutor()

    /** Keeps content clear of the status and navigation bars (the app draws edge to edge). */
    fun fitSystemBars(root: View) {
        ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            v.updatePadding(left = bars.left, top = bars.top, right = bars.right, bottom = maxOf(bars.bottom, ime.bottom))
            insets
        }
    }

    fun dp(context: Context, v: Int): Int = (v * context.resources.displayMetrics.density).toInt()

    fun meta(context: Context, doc: Document): String {
        val date = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(doc.updatedAt))
        return if (doc.pages.size == 1) context.getString(R.string.page_count_one, date)
        else context.getString(R.string.pages_count, doc.pages.size, date)
    }

    fun toast(context: Context, text: String) = Toast.makeText(context, text, Toast.LENGTH_SHORT).show()

    fun sharePdf(activity: Activity, doc: Document) {
        toast(activity, activity.getString(R.string.making_pdf))
        Store.exportPdf(activity, doc) { result ->
            result.onSuccess { uri -> share(activity, uri, "application/pdf", doc.name) }
                .onFailure { toast(activity, activity.getString(R.string.pdf_failed)) }
        }
    }

    private fun share(activity: Activity, uri: Uri, type: String, subject: String) {
        val send = Intent(Intent.ACTION_SEND).apply {
            this.type = type
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, subject)
            clipData = ClipData.newRawUri(subject, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(send, activity.getString(R.string.share_pdf)))
    }

    fun renameDialog(activity: Activity, doc: Document, done: () -> Unit = {}) {
        val input = EditText(activity).apply {
            setText(doc.name)
            setSelection(doc.name.length)
            setSingleLine()
        }
        val box = FrameLayout(activity).apply {
            setPadding(dp(activity, 24), dp(activity, 8), dp(activity, 24), 0)
            addView(input, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        MaterialAlertDialogBuilder(activity)
            .setTitle(R.string.rename_title)
            .setView(box)
            .setPositiveButton(R.string.save) { _, _ ->
                if (Store.rename(activity, doc.id, input.text.toString())) done()
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    fun deleteDialog(activity: Activity, doc: Document, done: () -> Unit = {}) {
        MaterialAlertDialogBuilder(activity)
            .setTitle(activity.getString(R.string.delete_title, doc.name))
            .setMessage(R.string.delete_body)
            .setPositiveButton(R.string.delete) { _, _ ->
                Store.delete(activity, doc.id)
                done()
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    /**
     * Reads the text on the given pages with on-device text recognition, saves
     * it with the document (so search can find it) and shows it to copy or share.
     */
    fun recognizeText(activity: Activity, doc: Document, pageIndices: List<Int>) {
        toast(activity, activity.getString(R.string.reading_text))
        val app = activity.applicationContext
        ocrPool.execute {
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            val result = runCatching {
                pageIndices.joinToString("\n\n") { i ->
                    val bmp = Thumbs.decode(Store.pageFile(app, doc, i).path, 2400)
                        ?: throw IllegalStateException("Can't read page ${i + 1}")
                    val text = Tasks.await(recognizer.process(InputImage.fromBitmap(bmp, 0))).text
                    bmp.recycle()
                    text
                }.trim()
            }
            recognizer.close()
            activity.runOnUiThread {
                if (activity.isFinishing || activity.isDestroyed) return@runOnUiThread
                result.onSuccess { text ->
                    if (pageIndices.size == doc.pages.size && text.isNotEmpty()) Store.setText(activity, doc.id, text)
                    showText(activity, doc.name, text)
                }.onFailure { e ->
                    toast(activity, activity.getString(R.string.text_failed, e.message ?: ""))
                }
            }
        }
    }

    private fun showText(activity: Activity, title: String, text: String) {
        val body = TextView(activity).apply {
            setText(if (text.isEmpty()) activity.getString(R.string.text_none) else text)
            setTextIsSelectable(true)
            textSize = 15f
            setPadding(dp(activity, 24), dp(activity, 8), dp(activity, 24), dp(activity, 8))
        }
        val scroll = ScrollView(activity).apply { addView(body) }
        val dialog = MaterialAlertDialogBuilder(activity)
            .setTitle(R.string.text_title)
            .setView(scroll)
            .setNegativeButton(R.string.cancel, null)
        if (text.isNotEmpty()) {
            dialog.setPositiveButton(R.string.copy) { _, _ ->
                val cm = activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                cm.setPrimaryClip(ClipData.newPlainText(title, text))
                toast(activity, activity.getString(R.string.text_copied))
            }
            dialog.setNeutralButton(R.string.share) { _, _ ->
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                    putExtra(Intent.EXTRA_SUBJECT, title)
                }
                activity.startActivity(Intent.createChooser(send, activity.getString(R.string.share)))
            }
        }
        dialog.show()
    }
}
