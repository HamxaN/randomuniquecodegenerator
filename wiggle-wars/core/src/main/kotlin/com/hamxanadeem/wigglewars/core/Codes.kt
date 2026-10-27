package com.hamxanadeem.wigglewars.core

import kotlin.random.Random

/**
 * Short codes people read out or type: room codes (5 letters) and friend codes
 * (6 letters). Letters that look alike (I, L, O) and all digits are left out.
 */
object Codes {

    const val ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ"
    const val ROOM_LENGTH = 5
    const val FRIEND_LENGTH = 6

    fun room(random: Random = Random.Default) = make(ROOM_LENGTH, random)

    fun friend(random: Random = Random.Default) = make(FRIEND_LENGTH, random)

    private fun make(length: Int, random: Random) = String(CharArray(length) { ALPHABET[random.nextInt(ALPHABET.length)] })

    /**
     * Cleans up what someone typed: ignores spaces, dashes and case, and maps
     * look-alike characters that are never generated to the letter they were
     * probably meant to be. Returns null if it can't be a code.
     */
    fun normalize(input: String, length: Int): String? {
        val cleaned = input.uppercase().filter { !it.isWhitespace() && it != '-' }
            .map { c ->
                when (c) {
                    '1', 'I', 'L' -> 'J' // never generated; most often a mistyped J
                    '0', 'O' -> 'Q'
                    '5' -> 'S'
                    '8' -> 'B'
                    else -> c
                }
            }.joinToString("")
        return cleaned.takeIf { it.length == length && it.all { c -> c in ALPHABET } }
    }

    /** Friend codes are shown in two halves, like "ABC-DEF", so they're easy to read out. */
    fun pretty(code: String) = if (code.length == FRIEND_LENGTH) code.substring(0, 3) + "-" + code.substring(3) else code
}
