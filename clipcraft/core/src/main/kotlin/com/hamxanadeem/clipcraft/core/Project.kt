package com.hamxanadeem.clipcraft.core

/** One clip within a project, with the user's edits and what happened to it. */
data class ClipState(
    val plan: ClipPlan,
    /** Edited or transliterated caption words (video timeline); null = use the transcript. */
    val words: List<Word>? = null,
    val rendered: String? = null,
    val youtubeId: String? = null,
    val youtubeStatus: String? = null,
    val publishAt: String? = null,
)

/** A video being turned into shorts, saved so you can come back to it. */
data class Project(
    val id: String,
    val name: String,
    val video: String,
    val created: Long,
    val language: String,
    val status: String = NEW,
    val message: String = "",
    val aiUsed: Boolean = false,
    val clips: List<ClipState> = emptyList(),
) {
    companion object {
        const val NEW = "new"
        const val WORKING = "working"
        const val READY = "ready"
        const val ERROR = "error"
    }
}

/** Projects as JSON on disk. */
object ProjectCodec {
    fun encode(p: Project): String = buildString {
        append('{')
        append("\"v\":1,\"id\":").append(Json.quote(p.id))
        append(",\"name\":").append(Json.quote(p.name))
        append(",\"video\":").append(Json.quote(p.video))
        append(",\"created\":").append(p.created)
        append(",\"language\":").append(Json.quote(p.language))
        append(",\"status\":").append(Json.quote(p.status))
        append(",\"message\":").append(Json.quote(p.message))
        append(",\"ai\":").append(p.aiUsed)
        append(",\"clips\":[")
        p.clips.forEachIndexed { i, c ->
            if (i > 0) append(',')
            append(clip(c))
        }
        append("]}")
    }

    private fun clip(c: ClipState): String = buildString {
        val p = c.plan
        append("{\"start\":").append(p.start).append(",\"end\":").append(p.end)
        append(",\"title\":").append(Json.quote(p.title))
        append(",\"description\":").append(Json.quote(p.description))
        append(",\"hashtags\":[").append(p.hashtags.joinToString(",") { Json.quote(it) }).append(']')
        append(",\"score\":").append(p.score)
        append(",\"reason\":").append(Json.quote(p.reason))
        append(",\"hook\":").append(Json.quote(p.hook))
        c.words?.let { ws ->
            append(",\"words\":[").append(ws.joinToString(",") { w ->
                "{\"w\":${Json.quote(w.text)},\"s\":${w.start},\"e\":${w.end}}"
            }).append(']')
        }
        c.rendered?.let { append(",\"rendered\":").append(Json.quote(it)) }
        c.youtubeId?.let { append(",\"yt\":").append(Json.quote(it)) }
        c.youtubeStatus?.let { append(",\"ytStatus\":").append(Json.quote(it)) }
        c.publishAt?.let { append(",\"publishAt\":").append(Json.quote(it)) }
        append('}')
    }

    fun decode(text: String): Project? = runCatching {
        val o = Json.obj(Json.parse(text))
        Project(
            Json.str(o["id"]), Json.str(o["name"]), Json.str(o["video"]), Json.num(o["created"]).toLong(),
            Json.str(o["language"], "en"), Json.str(o["status"], Project.NEW), Json.str(o["message"]),
            o["ai"] == true,
            Json.arr(o["clips"]).map { c ->
                val m = Json.obj(c)
                val plan = ClipPlan(Json.num(m["start"]), Json.num(m["end"]), Json.str(m["title"]), Json.str(m["description"]),
                    Json.arr(m["hashtags"]).map { Json.str(it) }, Json.num(m["score"]).toInt(), Json.str(m["reason"]), Json.str(m["hook"]))
                val words = if (m.containsKey("words")) Json.arr(m["words"]).map { w ->
                    val wm = Json.obj(w)
                    Word(Json.str(wm["w"]), Json.num(wm["s"]), Json.num(wm["e"]))
                } else null
                ClipState(plan, words, m["rendered"] as? String, m["yt"] as? String, m["ytStatus"] as? String, m["publishAt"] as? String)
            },
        )
    }.getOrNull()
}
