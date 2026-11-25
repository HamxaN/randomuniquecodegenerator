package com.hamxanadeem.clipcraft.core

/**
 * The JSON spoken between the app and the optional ClipCraft server, which holds
 * the Claude key so users don't need their own.
 */
object Wire {
    fun clipsRequest(t: Transcript, loudness: FloatArray, count: Int, notes: String): String = buildString {
        append("{\"count\":").append(count)
        append(",\"notes\":").append(Json.quote(notes))
        append(",\"words\":").append(words(t.words))
        append(",\"loudness\":[").append(loudness.joinToString(",") { "%.4f".format(java.util.Locale.ROOT, it) }).append("]}")
    }

    data class ClipsRequest(val transcript: Transcript, val loudness: FloatArray, val count: Int, val notes: String)

    fun parseClipsRequest(json: String): ClipsRequest {
        val o = Json.obj(Json.parse(json))
        val words = readWords(o["words"])
        val loud = Json.arr(o["loudness"]).map { Json.num(it).toFloat() }.toFloatArray()
        return ClipsRequest(Transcript(words), loud, Json.num(o["count"], 5.0).toInt().coerceIn(1, 10), Json.str(o["notes"]).take(500))
    }

    fun clipsResponse(plans: List<ClipPlan>): String = buildString {
        append("{\"clips\":[")
        plans.forEachIndexed { i, p ->
            if (i > 0) append(',')
            append("{\"start\":").append(p.start).append(",\"end\":").append(p.end)
            append(",\"title\":").append(Json.quote(p.title)).append(",\"hook\":").append(Json.quote(p.hook))
            append(",\"description\":").append(Json.quote(p.description))
            append(",\"hashtags\":[").append(p.hashtags.joinToString(",") { Json.quote(it) }).append(']')
            append(",\"score\":").append(p.score).append(",\"reason\":").append(Json.quote(p.reason)).append('}')
        }
        append("]}")
    }

    fun scriptRequest(words: List<String>, script: Script): String =
        "{\"script\":${Json.quote(script.name)},\"words\":${Scripts.request(words)}}"

    fun parseScriptRequest(json: String): Pair<List<String>, Script> {
        val o = Json.obj(Json.parse(json))
        return Json.arr(o["words"]).map { Json.str(it) } to Script.of(Json.str(o["script"]))
    }

    fun error(message: String): String = "{\"error\":${Json.quote(message)}}"

    private fun words(ws: List<Word>): String =
        ws.joinToString(",", "[", "]") { "{\"w\":${Json.quote(it.text)},\"s\":${it.start},\"e\":${it.end},\"c\":${it.conf}}" }

    private fun readWords(v: Any?): List<Word> = Json.arr(v).map { w ->
        val m = Json.obj(w)
        Word(Json.str(m["w"]), Json.num(m["s"]), Json.num(m["e"]), Json.num(m["c"], 1.0))
    }
}
