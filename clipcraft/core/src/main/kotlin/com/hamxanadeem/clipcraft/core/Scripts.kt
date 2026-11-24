package com.hamxanadeem.clipcraft.core

/** Which writing system captions use. Vosk's Hindi/Urdu model writes in Hindi script. */
enum class Script(val label: String, val instruction: String) {
    AS_SPOKEN("As transcribed", ""),
    URDU("Urdu script", "Rewrite each word in Urdu (Nastaliq/Perso-Arabic) script, spelled the way Urdu speakers write it."),
    ROMAN_URDU("Roman Urdu", "Rewrite each word in Roman Urdu: Latin letters the way Pakistanis type it in chats (e.g. \"kya\", \"hai\", \"bohat\")."),
    ;

    companion object {
        fun of(name: String): Script = entries.firstOrNull { it.name == name } ?: AS_SPOKEN
    }
}

object Scripts {
    /** The words as a JSON array for the request. */
    fun request(words: List<String>): String = words.joinToString(",", "[", "]") { Json.quote(it) }

    /** Reads {"words":[...]} back; returns null unless it has exactly [count] words. */
    fun parse(json: String, count: Int): List<String>? = runCatching {
        val list = Json.arr(Json.obj(Json.parse(json))["words"]).map { Json.str(it).trim() }
        if (list.size == count && list.none { it.isEmpty() }) list else null
    }.getOrNull()

    /** Keeps timings, swaps text. */
    fun apply(words: List<Word>, texts: List<String>): List<Word> = words.mapIndexed { i, w -> w.copy(text = texts.getOrElse(i) { w.text }) }
}
