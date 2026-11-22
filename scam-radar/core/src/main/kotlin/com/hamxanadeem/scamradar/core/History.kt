package com.hamxanadeem.scamradar.core

/** Past checks, saved on the phone as tab-separated lines. */
data class Check(val time: Long, val verdict: Verdict, val score: Int, val type: ScamType, val text: String)

object History {
    const val LIMIT = 200

    fun encode(list: List<Check>): String = buildString {
        append("scamradar 1\n")
        for (c in list.take(LIMIT)) {
            append(c.time).append('\t').append(c.verdict.name).append('\t').append(c.score).append('\t')
                .append(c.type.name).append('\t').append(escape(c.text)).append('\n')
        }
    }

    fun decode(text: String): List<Check> {
        val lines = text.split('\n')
        if (lines.isEmpty() || !lines[0].startsWith("scamradar ")) return emptyList()
        return lines.drop(1).mapNotNull { line ->
            val p = line.split('\t')
            if (p.size < 5) return@mapNotNull null
            runCatching {
                Check(p[0].toLong(), Verdict.valueOf(p[1]), p[2].toInt(), ScamType.valueOf(p[3]), unescape(p[4]))
            }.getOrNull()
        }
    }

    fun add(list: List<Check>, c: Check): List<Check> = (listOf(c) + list.filter { it.text != c.text }).take(LIMIT)

    private fun escape(s: String) = s.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n")

    private fun unescape(s: String): String {
        val sb = StringBuilder()
        var i = 0
        while (i < s.length) {
            val ch = s[i]
            if (ch == '\\' && i + 1 < s.length) {
                when (s[i + 1]) {
                    'n' -> sb.append('\n')
                    't' -> sb.append('\t')
                    else -> sb.append(s[i + 1])
                }
                i += 2
            } else {
                sb.append(ch)
                i++
            }
        }
        return sb.toString()
    }
}
