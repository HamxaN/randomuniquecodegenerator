package com.hamxanadeem.clipcraft.server

import com.hamxanadeem.clipcraft.core.AdvisorException
import com.hamxanadeem.clipcraft.core.ClipAdvisor
import com.hamxanadeem.clipcraft.core.ClipSource
import com.hamxanadeem.clipcraft.core.Scripts
import com.hamxanadeem.clipcraft.core.Wire
import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.time.LocalDate
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * A small server that holds the Claude API key, so app users don't need their own.
 * It accepts only the two jobs the app needs (find clips, convert caption script),
 * checks an optional shared app token, and limits requests per device per day.
 */
class ClipServer(
    private val source: ClipSource,
    private val appToken: String = "",
    private val dailyLimit: Int = 20,
    private val today: () -> LocalDate = { LocalDate.now() },
) {
    private val used = ConcurrentHashMap<String, Int>()
    private var day = today()

    data class Reply(val status: Int, val body: String)

    fun handle(method: String, path: String, headers: Map<String, String>, body: String, ip: String): Reply {
        if (method == "GET" && path == "/health") return Reply(200, "{\"ok\":true}")
        if (method != "POST") return Reply(405, Wire.error("Use POST."))
        if (path != "/v1/clips" && path != "/v1/script") return Reply(404, Wire.error("Unknown endpoint."))
        if (appToken.isNotEmpty() && headers["x-clipcraft-token"] != appToken) return Reply(401, Wire.error("This server needs the app's token."))
        if (body.length > 6_000_000) return Reply(413, Wire.error("Video transcript too large."))
        val who = (headers["x-device"]?.take(64) ?: "") + "@" + ip
        if (!allow(who)) return Reply(429, Wire.error("Daily limit reached. Try again tomorrow."))
        return try {
            when (path) {
                "/v1/clips" -> {
                    val r = Wire.parseClipsRequest(body)
                    Reply(200, Wire.clipsResponse(source.suggest(r.transcript, r.count, r.notes, r.loudness)))
                }
                else -> {
                    val (words, script) = Wire.parseScriptRequest(body)
                    if (words.size > 5000) return Reply(413, Wire.error("Too many words."))
                    Reply(200, "{\"words\":${Scripts.request(source.transliterate(words, script))}}")
                }
            }
        } catch (e: AdvisorException) {
            Reply(502, Wire.error(e.message ?: "AI error"))
        } catch (e: IllegalArgumentException) {
            Reply(400, Wire.error("Bad request: ${e.message}"))
        } catch (e: ClassCastException) {
            Reply(400, Wire.error("Bad request."))
        }
    }

    @Synchronized
    private fun allow(who: String): Boolean {
        val d = today()
        if (d != day) {
            day = d
            used.clear()
        }
        val n = (used[who] ?: 0) + 1
        if (n > dailyLimit) return false
        used[who] = n
        return true
    }
}

fun main() {
    val key = System.getenv("ANTHROPIC_API_KEY").orEmpty()
    require(key.isNotBlank()) { "Set ANTHROPIC_API_KEY." }
    val port = System.getenv("PORT")?.toIntOrNull() ?: 8080
    val server = ClipServer(
        ClipAdvisor(key),
        System.getenv("APP_TOKEN").orEmpty(),
        System.getenv("DAILY_LIMIT")?.toIntOrNull() ?: 20,
    )
    val http = HttpServer.create(InetSocketAddress(port), 0)
    http.executor = Executors.newFixedThreadPool(8)
    http.createContext("/") { ex ->
        val headers = ex.requestHeaders.entries.associate { it.key.lowercase() to (it.value.firstOrNull() ?: "") }
        val body = ex.requestBody.readNBytes(6_000_001).toString(Charsets.UTF_8)
        val ip = headers["x-forwarded-for"]?.substringBefore(',')?.trim() ?: ex.remoteAddress.address.hostAddress
        val reply = server.handle(ex.requestMethod, ex.requestURI.path, headers, body, ip)
        val bytes = reply.body.toByteArray()
        ex.responseHeaders.add("Content-Type", "application/json; charset=utf-8")
        ex.sendResponseHeaders(reply.status, bytes.size.toLong())
        ex.responseBody.use { it.write(bytes) }
    }
    http.start()
    println("ClipCraft server on port $port (daily limit per device: ${System.getenv("DAILY_LIMIT") ?: "20"})")
}
