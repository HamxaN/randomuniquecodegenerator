package com.hamxanadeem.snapdoc.data

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import android.widget.ImageView
import java.util.concurrent.Executors

/** Loads page images scaled down to fit their view, off the main thread, with a small memory cache. */
object Thumbs {

    private val pool = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())
    private val cache = object : LruCache<String, Bitmap>((Runtime.getRuntime().maxMemory() / 8).toInt()) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

    fun forget(path: String) {
        cache.snapshot().keys.filter { it.startsWith("$path@") }.forEach { cache.remove(it) }
    }

    /** Shows the image at [path] in [view], decoded to about [maxSide] pixels on its longer side. */
    fun load(view: ImageView, path: String, maxSide: Int) {
        val key = "$path@$maxSide"
        view.tag = key
        cache.get(key)?.let {
            view.setImageBitmap(it)
            return
        }
        view.setImageDrawable(null)
        pool.execute {
            val bmp = decode(path, maxSide) ?: return@execute
            cache.put(key, bmp)
            main.post { if (view.tag == key) view.setImageBitmap(bmp) }
        }
    }

    fun decode(path: String, maxSide: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxSide) sample *= 2
        return BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
    }
}
