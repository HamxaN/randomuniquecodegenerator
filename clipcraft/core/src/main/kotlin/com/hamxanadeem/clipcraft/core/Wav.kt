package com.hamxanadeem.clipcraft.core

import java.io.DataInputStream
import java.io.EOFException
import java.io.InputStream

/**
 * Reads a 16 kHz, 16-bit PCM WAV (what FFmpeg writes for the speech recogniser) and
 * hands over mono little-endian PCM in chunks. Stereo is mixed down.
 */
object Wav {
    const val RATE = 16000

    /** Returns the duration in seconds. [totalBytes] (if known) drives [onProgress]. */
    fun read(input: InputStream, totalBytes: Long, onProgress: (Float) -> Unit, onChunk: (ByteArray) -> Unit): Double {
        val d = DataInputStream(input.buffered(256 * 1024))
        fun tag(): String = String(ByteArray(4).also { d.readFully(it) }, Charsets.US_ASCII)
        fun u32(): Long = Integer.reverseBytes(d.readInt()).toLong() and 0xFFFFFFFFL
        fun u16(): Int = java.lang.Short.reverseBytes(d.readShort()).toInt() and 0xFFFF
        require(tag() == "RIFF") { "Not a WAV file." }
        u32()
        require(tag() == "WAVE") { "Not a WAV file." }
        var channels = 0
        var bits = 0
        var rate = 0
        var read = 12L
        while (true) {
            val id = try {
                tag()
            } catch (_: EOFException) {
                throw IllegalArgumentException("The WAV file has no sound data.")
            }
            val size = u32()
            read += 8
            if (id == "fmt ") {
                val format = u16()
                channels = u16()
                rate = u32().toInt()
                u32()
                u16()
                bits = u16()
                d.skipBytes((size - 16).toInt().coerceAtLeast(0))
                require(format == 1 || format == 0xFFFE) { "The WAV isn't plain PCM." }
                read += size
            } else if (id == "data") {
                require(bits == 16 && rate == RATE && channels >= 1) { "The WAV must be 16-bit, 16 kHz (got $bits-bit, $rate Hz)." }
                // FFmpeg writes 0 or 0xFFFFFFFF when it couldn't go back and fill in the size.
                val dataSize = if (size == 0L || size == 0xFFFFFFFFL) Long.MAX_VALUE else size
                return stream(d, channels, dataSize, read, totalBytes, onProgress, onChunk)
            } else {
                d.skipBytes(size.toInt() + (size and 1).toInt())
                read += size + (size and 1)
            }
        }
    }

    private fun stream(
        d: DataInputStream, channels: Int, dataSize: Long, headerBytes: Long, totalBytes: Long,
        onProgress: (Float) -> Unit, onChunk: (ByteArray) -> Unit,
    ): Double {
        val frameBytes = 2 * channels
        val buf = ByteArray(frameBytes * 8000)
        var left = dataSize
        var frames = 0L
        var lastPct = -1
        while (left > 0) {
            val want = minOf(buf.size.toLong(), left).toInt() / frameBytes * frameBytes
            if (want <= 0) break
            var got = 0
            while (got < want) {
                val n = d.read(buf, got, want - got)
                if (n < 0) break
                got += n
            }
            val whole = got / frameBytes
            if (whole == 0) break
            val out = if (channels == 1) buf.copyOf(whole * 2) else ByteArray(whole * 2).also { o ->
                for (f in 0 until whole) {
                    var sum = 0
                    for (c in 0 until channels) {
                        val i = f * frameBytes + c * 2
                        sum += (buf[i + 1].toInt() shl 8) or (buf[i].toInt() and 0xFF)
                    }
                    val v = sum / channels
                    o[f * 2] = (v and 0xFF).toByte()
                    o[f * 2 + 1] = ((v shr 8) and 0xFF).toByte()
                }
            }
            onChunk(out)
            frames += whole
            left -= got
            if (totalBytes > 0) {
                val pct = ((headerBytes + frames * frameBytes) * 100 / totalBytes).toInt()
                if (pct != lastPct) {
                    lastPct = pct
                    onProgress((pct / 100f).coerceIn(0f, 1f))
                }
            }
            if (got < want) break
        }
        return frames.toDouble() / RATE
    }
}
