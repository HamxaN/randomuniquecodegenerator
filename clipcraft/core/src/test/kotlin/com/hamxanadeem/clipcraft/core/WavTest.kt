package com.hamxanadeem.clipcraft.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.io.ByteArrayOutputStream

class WavTest {
    private fun wav(rate: Int, channels: Int, samples: ShortArray, dataSize: Long? = null, extra: Boolean = false): ByteArray {
        val o = ByteArrayOutputStream()
        fun s(t: String) = o.write(t.toByteArray(Charsets.US_ASCII))
        fun i32(v: Long) = repeat(4) { o.write(((v shr (8 * it)) and 0xFF).toInt()) }
        fun i16(v: Int) = repeat(2) { o.write((v shr (8 * it)) and 0xFF) }
        s("RIFF"); i32(0); s("WAVE")
        if (extra) { s("LIST"); i32(3); o.write(byteArrayOf(1, 2, 3, 0)) }
        s("fmt "); i32(16); i16(1); i16(channels); i32(rate.toLong()); i32(rate * 2L * channels); i16(2 * channels); i16(16)
        s("data"); i32(dataSize ?: (samples.size * 2L))
        for (v in samples) i16(v.toInt())
        return o.toByteArray()
    }

    private fun decode(bytes: ByteArray): Pair<ShortArray, Double> {
        val out = ByteArrayOutputStream()
        val secs = Wav.read(bytes.inputStream(), bytes.size.toLong(), {}) { out.write(it) }
        val b = out.toByteArray()
        return ShortArray(b.size / 2) { ((b[it * 2 + 1].toInt() shl 8) or (b[it * 2].toInt() and 0xFF)).toShort() } to secs
    }

    @Test
    fun monoPassesThrough() {
        val samples = ShortArray(32000) { (it % 200 - 100).toShort() }
        val (got, secs) = decode(wav(16000, 1, samples))
        assertEquals(samples.toList(), got.toList())
        assertEquals(2.0, secs, 1e-9)
    }

    @Test
    fun stereoIsMixedAndUnknownSizeAndExtraChunksWork() {
        val stereo = ShortArray(400) { if (it % 2 == 0) 1000 else -3000 }
        val (got, _) = decode(wav(16000, 2, stereo, dataSize = 0xFFFFFFFFL, extra = true))
        assertEquals(200, got.size)
        assertEquals(-1000, got[0].toInt())
    }

    @Test
    fun wrongRateIsRefused() {
        assertThrows<IllegalArgumentException> { decode(wav(44100, 1, ShortArray(10))) }
        assertThrows<IllegalArgumentException> { decode("nope".toByteArray()) }
    }
}
