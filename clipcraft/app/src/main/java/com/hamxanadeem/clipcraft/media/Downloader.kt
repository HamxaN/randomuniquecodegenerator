package com.hamxanadeem.clipcraft.media

import com.hamxanadeem.clipcraft.core.Links
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

/** Downloads a video file from a direct link (Dropbox, Google Drive, a website's .mp4). */
object Downloader {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .followRedirects(true)
        .build()

    /** Saves [url] to [out], reporting 0..1 (or -1 when the size is unknown). Throws IOException with a readable message. */
    fun fetch(url: String, out: File, onProgress: (Float) -> Unit) {
        val req = Request.Builder().url(url).header("User-Agent", "ClipCraft/1.0 (Android)").build()
        client.newCall(req).execute().use { r ->
            if (!r.isSuccessful) throw IOException("The link answered ${r.code}. Is it shared publicly?")
            val body = r.body ?: throw IOException("The link sent nothing.")
            if (!Links.looksLikeVideo(body.contentType()?.toString())) {
                throw IOException("That link opens a web page, not a video file. Use a direct or shared-file link to the video.")
            }
            val total = body.contentLength()
            val free = out.parentFile?.usableSpace ?: Long.MAX_VALUE
            if (total > 0 && total > free - 200_000_000L) throw IOException("Not enough free space on the phone for this video.")
            val tmp = File(out.parentFile, out.name + ".part")
            var done = 0L
            var lastPct = -1
            body.byteStream().use { input ->
                tmp.outputStream().use { o ->
                    val buf = ByteArray(256 * 1024)
                    while (true) {
                        if (Thread.currentThread().isInterrupted) throw IOException("Cancelled.")
                        val n = input.read(buf)
                        if (n < 0) break
                        o.write(buf, 0, n)
                        done += n
                        if (total > 0) {
                            val pct = (done * 100 / total).toInt()
                            if (pct != lastPct) {
                                lastPct = pct
                                onProgress(pct / 100f)
                            }
                        }
                    }
                }
            }
            if (done < 10_000) {
                tmp.delete()
                throw IOException("That link didn't give a video file.")
            }
            if (!tmp.renameTo(out)) {
                tmp.copyTo(out, overwrite = true)
                tmp.delete()
            }
        }
    }
}
