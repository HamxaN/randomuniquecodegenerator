package com.hamxanadeem.clipcraft.core

/** Builds the YouTube upload metadata for a short. */
object YouTube {
    const val TITLE_MAX = 100
    const val DESC_MAX = 5000

    fun title(p: ClipPlan): String {
        val base = p.title.trim().ifBlank { "Highlight" }
        val withTag = if (base.contains("#shorts", ignoreCase = true)) base else "$base #shorts"
        return if (withTag.length <= TITLE_MAX) withTag else base.take(TITLE_MAX)
    }

    fun description(p: ClipPlan, extra: String = ""): String {
        val tags = (p.hashtags + "#shorts").distinctBy { it.lowercase() }.joinToString(" ")
        return listOf(p.description.trim(), extra.trim(), tags).filter { it.isNotEmpty() }.joinToString("\n\n").take(DESC_MAX)
    }

    fun tags(p: ClipPlan): List<String> = (p.hashtags.map { it.trimStart('#') } + "shorts").distinctBy { it.lowercase() }.take(15)

    /**
     * The JSON body for videos.insert (snippet + status). With [publishAt] the video
     * is uploaded private and YouTube makes it public at that time.
     */
    fun metadata(p: ClipPlan, privacy: String, extra: String = "", publishAt: String? = null): String {
        val tags = tags(p).joinToString(",") { Json.quote(it) }
        val status = if (publishAt != null) {
            """"status":{"privacyStatus":"private","publishAt":${Json.quote(publishAt)},"selfDeclaredMadeForKids":false}"""
        } else {
            """"status":{"privacyStatus":${Json.quote(privacy)},"selfDeclaredMadeForKids":false}"""
        }
        return """{"snippet":{"title":${Json.quote(title(p))},"description":${Json.quote(description(p, extra))},"tags":[$tags],"categoryId":"22"},$status}"""
    }
}
