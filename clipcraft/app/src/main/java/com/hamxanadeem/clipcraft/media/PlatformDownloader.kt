package com.hamxanadeem.clipcraft.media

import android.content.Context
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import java.io.File
import java.io.IOException

/**
 * Internal testing only: fetches a video from a platform page (YouTube, TikTok,
 * Instagram…) with yt-dlp. Off unless switched on in Settings, and projects made this
 * way can't be posted to YouTube.
 */
object PlatformDownloader {
    private var ready = false
    private const val UPDATED_AT = "ytdl_updated"

    @Synchronized
    private fun init(c: Context) {
        if (ready) return
        YoutubeDL.getInstance().init(c)
        FFmpeg.getInstance().init(c)
        ready = true
        // Sites change often; keep yt-dlp current (at most once a day, best effort).
        val prefs = c.getSharedPreferences("clipcraft", Context.MODE_PRIVATE)
        if (System.currentTimeMillis() - prefs.getLong(UPDATED_AT, 0) > 24 * 3600_000L) {
            runCatching {
                YoutubeDL.getInstance().updateYoutubeDL(c, YoutubeDL.UpdateChannel._STABLE)
                prefs.edit().putLong(UPDATED_AT, System.currentTimeMillis()).apply()
            }
        }
    }

    /** Downloads [url] into [dir] as video.mp4 (best quality up to 1080p) and returns the file. */
    fun fetch(c: Context, url: String, dir: File, onStatus: (String?, Int) -> Unit): File {
        onStatus(null, -1)
        try {
            init(c.applicationContext)
        } catch (e: Exception) {
            throw IOException("The downloader couldn't start: ${e.message}", e)
        }
        dir.listFiles { f -> f.name.startsWith("video.") }?.forEach { it.delete() }
        val req = YoutubeDLRequest(url)
            .addOption("--no-playlist")
            .addOption("--no-mtime")
            .addOption("-f", "bv*[height<=1080][ext=mp4]+ba[ext=m4a]/bv*[height<=1080]+ba/b[height<=1080]/b")
            .addOption("--merge-output-format", "mp4")
            .addOption("-o", File(dir, "video.%(ext)s").absolutePath)
        try {
            YoutubeDL.getInstance().execute(req, "dl-" + dir.name) { progress, _, _ ->
                onStatus(null, progress.toInt().coerceIn(0, 100))
            }
        } catch (e: Exception) {
            val msg = e.message?.lineSequence()?.lastOrNull { it.contains("ERROR") }?.substringAfter("ERROR:")?.trim()
            throw IOException(msg ?: "The video couldn't be downloaded. It may be private, age-restricted or region-locked.", e)
        }
        return dir.listFiles { f -> f.name.startsWith("video.") && !f.name.endsWith(".part") }?.maxByOrNull { it.length() }
            ?: throw IOException("The download finished but no video file was found.")
    }
}
