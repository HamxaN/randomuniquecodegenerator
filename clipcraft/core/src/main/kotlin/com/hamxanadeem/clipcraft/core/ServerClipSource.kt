package com.hamxanadeem.clipcraft.core

import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * Asks a ClipCraft server (which holds the Claude key) instead of calling Claude
 * directly. Uses HttpURLConnection so it works on Android and the JVM alike.
 */
class ServerClipSource(
    baseUrl: String,
    private val token: String = "",
    private val device: String = "",
    private val timeoutMs: Int = 180_000,
) : ClipSource {
    private val base = baseUrl.trim().trimEnd('/')

    override fun suggest(t: Transcript, count: Int, notes: String, loudness: FloatArray): List<ClipPlan> {
        val reply = post("/v1/clips", Wire.clipsRequest(t, loudness, count, notes))
        val plans = runCatching { Clips.fromJson(reply) }.getOrElse { throw AdvisorException("The server sent an unreadable reply.") }
        return Clips.tidy(plans, t, count)
    }

    override fun transliterate(words: List<String>, script: Script): List<String> {
        if (script == Script.AS_SPOKEN || words.isEmpty()) return words
        val out = mutableListOf<String>()
        for (chunk in words.chunked(300)) {
            val reply = post("/v1/script", Wire.scriptRequest(chunk, script))
            out += Scripts.parse(reply, chunk.size) ?: chunk
        }
        return out
    }

    private fun post(path: String, body: String): String {
        if (!base.startsWith("https://") && !base.startsWith("http://")) throw AdvisorException("The server address should start with https://")
        val c = try {
            URL(base + path).openConnection() as HttpURLConnection
        } catch (e: Exception) {
            throw AdvisorException("Bad server address.", e)
        }
        try {
            c.requestMethod = "POST"
            c.connectTimeout = 20_000
            c.readTimeout = timeoutMs
            c.doOutput = true
            c.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            if (token.isNotEmpty()) c.setRequestProperty("X-ClipCraft-Token", token)
            if (device.isNotEmpty()) c.setRequestProperty("X-Device", device)
            c.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val code = c.responseCode
            val stream = if (code in 200..299) c.inputStream else c.errorStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
            if (code !in 200..299) {
                val msg = runCatching { Json.str(Json.obj(Json.parse(text))["error"]) }.getOrNull()?.takeIf { it.isNotBlank() }
                throw AdvisorException(msg ?: "The ClipCraft server answered $code.")
            }
            return text
        } catch (e: IOException) {
            throw AdvisorException("Couldn't reach the ClipCraft server: ${e.message}", e)
        } finally {
            c.disconnect()
        }
    }
}
