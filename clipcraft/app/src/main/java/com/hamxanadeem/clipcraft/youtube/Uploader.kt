package com.hamxanadeem.clipcraft.youtube

import com.hamxanadeem.clipcraft.core.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okio.BufferedSink
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

/** Uploads a video to the signed-in user's channel with the YouTube Data API's resumable upload. */
object Uploader {
    private val http = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(5, TimeUnit.MINUTES)
        .readTimeout(2, TimeUnit.MINUTES)
        .build()

    /** Blocks; call off the main thread. Returns the new video's id. */
    fun upload(token: String, file: File, metadataJson: String, onProgress: (Float) -> Unit): String {
        val start = Request.Builder()
            .url("https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status")
            .header("Authorization", "Bearer $token")
            .header("X-Upload-Content-Type", "video/mp4")
            .header("X-Upload-Content-Length", file.length().toString())
            .post(metadataJson.toRequestBody("application/json; charset=UTF-8".toMediaType()))
            .build()
        val location = http.newCall(start).execute().use { r ->
            if (!r.isSuccessful) throw IOException(error(r.code, r.body?.string()))
            r.header("Location") ?: throw IOException("YouTube didn't return an upload address.")
        }
        val body = object : RequestBody() {
            override fun contentType() = "video/mp4".toMediaType()
            override fun contentLength() = file.length()
            override fun writeTo(sink: BufferedSink) {
                val total = file.length().toFloat()
                var sent = 0L
                file.inputStream().use { input ->
                    val buf = ByteArray(256 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        sink.write(buf, 0, n)
                        sent += n
                        onProgress(sent / total)
                    }
                }
            }
        }
        val put = Request.Builder().url(location).header("Authorization", "Bearer $token").put(body).build()
        http.newCall(put).execute().use { r ->
            val text = r.body?.string().orEmpty()
            if (!r.isSuccessful) throw IOException(error(r.code, text))
            val id = Json.str(Json.obj(Json.parse(text))["id"])
            if (id.isEmpty()) throw IOException("Upload finished but YouTube returned no video id.")
            return id
        }
    }

    private fun error(code: Int, body: String?): String {
        val msg = runCatching { Json.str(Json.obj(Json.obj(Json.parse(body ?: ""))["error"])["message"]) }.getOrDefault("")
        return when (code) {
            401 -> "YouTube sign-in expired. Try again."
            403 -> "YouTube refused the upload: ${msg.ifBlank { "check that the YouTube Data API is enabled and your channel exists." }}"
            else -> "YouTube upload failed ($code) ${msg}".trim()
        }
    }
}
