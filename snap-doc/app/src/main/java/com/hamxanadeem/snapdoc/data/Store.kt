package com.hamxanadeem.snapdoc.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import com.hamxanadeem.snapdoc.core.Document
import com.hamxanadeem.snapdoc.core.Library
import com.hamxanadeem.snapdoc.core.PdfWriter
import java.io.File
import java.io.OutputStream
import java.time.LocalDateTime
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Where documents live: the library file plus each document's page images,
 * all in the app's private storage. File work happens on a background thread;
 * results come back on the main thread.
 */
object Store {

    private const val LIBRARY_FILE = "library.txt"
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var library: Library? = null
    private val listeners = mutableSetOf<() -> Unit>()

    fun library(context: Context): Library {
        library?.let { return it }
        val f = File(context.filesDir, LIBRARY_FILE)
        val lib = if (f.exists()) Library.decode(f.readText()) else Library()
        library = lib
        return lib
    }

    fun addListener(l: () -> Unit) {
        listeners += l
    }

    fun removeListener(l: () -> Unit) {
        listeners -= l
    }

    private fun changed(context: Context) {
        val text = library(context).encode()
        val f = File(context.filesDir, LIBRARY_FILE)
        val tmp = File(context.filesDir, "$LIBRARY_FILE.tmp")
        tmp.writeText(text)
        tmp.renameTo(f)
        main.post { listeners.toList().forEach { it() } }
    }

    fun docDir(context: Context, id: String): File = File(File(context.filesDir, "docs"), id).apply { mkdirs() }

    fun pageFile(context: Context, doc: Document, index: Int): File = File(docDir(context, doc.id), doc.pages[index])

    private fun now() = System.currentTimeMillis()

    private fun newPageName() = "p_${UUID.randomUUID().toString().take(12)}.jpg"

    /** Copies scanned page images into storage. Returns the new file names. */
    private fun copyIn(context: Context, id: String, uris: List<Uri>): List<String> {
        val dir = docDir(context, id)
        return uris.map { uri ->
            val name = newPageName()
            context.contentResolver.openInputStream(uri)?.use { input ->
                File(dir, name).outputStream().use { input.copyTo(it) }
            } ?: throw IllegalStateException("Can't read $uri")
            name
        }
    }

    fun createDocument(context: Context, uris: List<Uri>, done: (Result<Document>) -> Unit) {
        val app = context.applicationContext
        io.execute {
            val result = runCatching {
                val id = UUID.randomUUID().toString()
                val pages = copyIn(app, id, uris)
                val t = now()
                val doc = Document(id, Library.defaultName(LocalDateTime.now()), pages, t, t)
                library(app).add(doc)
                changed(app)
                doc
            }
            main.post { done(result) }
        }
    }

    fun addPages(context: Context, id: String, uris: List<Uri>, done: (Result<Document>) -> Unit) {
        val app = context.applicationContext
        io.execute {
            val result = runCatching {
                val pages = copyIn(app, id, uris)
                val doc = library(app).addPages(id, pages, now()) ?: throw IllegalStateException("Document gone")
                changed(app)
                doc
            }
            main.post { done(result) }
        }
    }

    fun rename(context: Context, id: String, name: String): Boolean {
        val ok = library(context).rename(id, name, now()) != null
        if (ok) changed(context)
        return ok
    }

    fun delete(context: Context, id: String) {
        library(context).remove(id) ?: return
        docDir(context, id).deleteRecursively()
        changed(context)
    }

    fun movePage(context: Context, id: String, from: Int, to: Int) {
        if (library(context).movePage(id, from, to, now()) != null) changed(context)
    }

    fun deletePage(context: Context, id: String, index: Int): Boolean {
        val lib = library(context)
        val doc = lib.get(id) ?: return false
        val file = doc.pages.getOrNull(index) ?: return false
        if (lib.removePage(id, index, now()) == null) return false
        File(docDir(context, id), file).delete()
        changed(context)
        return true
    }

    /** Turns a page by 90 degrees (left or right) and saves it under a new name. */
    fun rotatePage(context: Context, id: String, index: Int, clockwise: Boolean, done: (Boolean) -> Unit) {
        val app = context.applicationContext
        io.execute {
            val ok = runCatching {
                val doc = library(app).get(id) ?: return@runCatching false
                val src = pageFile(app, doc, index)
                val bmp = BitmapFactory.decodeFile(src.path) ?: return@runCatching false
                val m = Matrix().apply { postRotate(if (clockwise) 90f else -90f) }
                val turned = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
                val name = newPageName()
                File(docDir(app, id), name).outputStream().use { turned.compress(Bitmap.CompressFormat.JPEG, 92, it) }
                bmp.recycle()
                turned.recycle()
                library(app).replacePage(id, index, name, now())
                src.delete()
                Thumbs.forget(src.path)
                changed(app)
                true
            }.getOrDefault(false)
            main.post { done(ok) }
        }
    }

    fun setText(context: Context, id: String, text: String) {
        if (library(context).setText(id, text, now()) != null) changed(context)
    }

    /** Writes the document as a PDF to [out]. */
    fun writePdf(context: Context, doc: Document, out: OutputStream) {
        val pages = doc.pages.indices.map { PdfWriter.Page(pageFile(context, doc, it).readBytes()) }
        PdfWriter.write(pages, out, doc.name)
    }

    /** Builds the PDF in the shareable cache folder and returns a content URI for it. */
    fun exportPdf(context: Context, doc: Document, done: (Result<Uri>) -> Unit) {
        val app = context.applicationContext
        io.execute {
            val result = runCatching {
                val dir = File(app.cacheDir, "exports").apply { mkdirs() }
                dir.listFiles()?.forEach { it.delete() }
                val file = File(dir, Library.pdfFileName(doc.name))
                file.outputStream().buffered().use { writePdf(app, doc, it) }
                FileProvider.getUriForFile(app, "${app.packageName}.files", file)
            }
            main.post { done(result) }
        }
    }

    /** Writes the PDF to a place the user picked with "Save as". */
    fun savePdfTo(context: Context, doc: Document, target: Uri, done: (Boolean) -> Unit) {
        val app = context.applicationContext
        io.execute {
            val ok = runCatching {
                app.contentResolver.openOutputStream(target, "wt")?.buffered()?.use { writePdf(app, doc, it) }
                    ?: throw IllegalStateException("Can't write")
            }.isSuccess
            main.post { done(ok) }
        }
    }
}
