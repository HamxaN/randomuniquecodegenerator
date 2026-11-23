package com.hamxanadeem.clipcraft.core

/** A small JSON reader (objects, arrays, strings, numbers, booleans, null) so the core needs no extra libraries. */
object Json {
    fun parse(text: String): Any? {
        val p = Parser(text)
        p.ws()
        val v = p.value()
        p.ws()
        if (p.i != text.length) throw IllegalArgumentException("Trailing characters at ${p.i}")
        return v
    }

    @Suppress("UNCHECKED_CAST")
    fun obj(v: Any?): Map<String, Any?> = v as? Map<String, Any?> ?: emptyMap()

    @Suppress("UNCHECKED_CAST")
    fun arr(v: Any?): List<Any?> = v as? List<Any?> ?: emptyList()

    fun num(v: Any?, default: Double = 0.0): Double = (v as? Number)?.toDouble() ?: (v as? String)?.toDoubleOrNull() ?: default

    fun str(v: Any?, default: String = ""): String = v as? String ?: v?.toString() ?: default

    /** Writes a string as a JSON string literal. */
    fun quote(s: String): String {
        val sb = StringBuilder("\"")
        for (c in s) {
            when (c) {
                '"' -> sb.append("\\\"")
                '\\' -> sb.append("\\\\")
                '\n' -> sb.append("\\n")
                '\r' -> sb.append("\\r")
                '\t' -> sb.append("\\t")
                else -> if (c < ' ') sb.append(String.format("\\u%04x", c.code)) else sb.append(c)
            }
        }
        return sb.append('"').toString()
    }

    private class Parser(val s: String) {
        var i = 0

        fun ws() {
            while (i < s.length && s[i].isWhitespace()) i++
        }

        fun value(): Any? {
            ws()
            if (i >= s.length) throw IllegalArgumentException("Unexpected end")
            return when (val c = s[i]) {
                '{' -> obj()
                '[' -> arr()
                '"' -> string()
                't' -> lit("true", true)
                'f' -> lit("false", false)
                'n' -> lit("null", null)
                else -> if (c == '-' || c.isDigit()) number() else throw IllegalArgumentException("Bad character '$c' at $i")
            }
        }

        fun lit(word: String, v: Any?): Any? {
            if (!s.startsWith(word, i)) throw IllegalArgumentException("Expected $word at $i")
            i += word.length
            return v
        }

        fun obj(): Map<String, Any?> {
            val m = LinkedHashMap<String, Any?>()
            i++
            ws()
            if (s[i] == '}') {
                i++
                return m
            }
            while (true) {
                ws()
                val k = string()
                ws()
                if (s[i] != ':') throw IllegalArgumentException("Expected : at $i")
                i++
                m[k] = value()
                ws()
                when (s[i]) {
                    ',' -> i++
                    '}' -> {
                        i++
                        return m
                    }
                    else -> throw IllegalArgumentException("Expected , or } at $i")
                }
            }
        }

        fun arr(): List<Any?> {
            val l = ArrayList<Any?>()
            i++
            ws()
            if (s[i] == ']') {
                i++
                return l
            }
            while (true) {
                l.add(value())
                ws()
                when (s[i]) {
                    ',' -> i++
                    ']' -> {
                        i++
                        return l
                    }
                    else -> throw IllegalArgumentException("Expected , or ] at $i")
                }
            }
        }

        fun string(): String {
            if (s[i] != '"') throw IllegalArgumentException("Expected string at $i")
            i++
            val sb = StringBuilder()
            while (true) {
                val c = s[i++]
                when (c) {
                    '"' -> return sb.toString()
                    '\\' -> {
                        when (val e = s[i++]) {
                            'n' -> sb.append('\n')
                            't' -> sb.append('\t')
                            'r' -> sb.append('\r')
                            'b' -> sb.append('\b')
                            'f' -> sb.append('\u000C')
                            'u' -> {
                                sb.append(s.substring(i, i + 4).toInt(16).toChar())
                                i += 4
                            }
                            else -> sb.append(e)
                        }
                    }
                    else -> sb.append(c)
                }
            }
        }

        fun number(): Double {
            val start = i
            if (s[i] == '-') i++
            while (i < s.length && (s[i].isDigit() || s[i] in ".eE+-")) i++
            return s.substring(start, i).toDouble()
        }
    }
}
