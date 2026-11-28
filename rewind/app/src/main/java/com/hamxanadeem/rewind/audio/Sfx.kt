package com.hamxanadeem.rewind.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.SystemClock
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin
import kotlin.random.Random

/**
 * Sound effects, synthesised once on first launch (so the APK needs no audio files)
 * and played through a SoundPool. Rapid repeats are throttled so a big fight doesn't
 * turn into noise.
 */
object Sfx {
    const val SHOOT = 0
    const val CANNON = 1
    const val BOOM = 2
    const val ZAP = 3
    const val FROST = 4
    const val SNIPER = 5
    const val POP = 6
    const val COIN = 7
    const val LEAK = 8
    const val REWIND = 9
    const val WIN = 10
    const val LOSE = 11
    const val BUILD = 12
    const val TAP = 13
    private const val COUNT = 14
    private const val RATE = 22050

    @Volatile var enabled = true
    private var pool: SoundPool? = null
    private val ids = IntArray(COUNT)
    private val last = LongArray(COUNT)
    private val gap = longArrayOf(70, 120, 90, 90, 110, 150, 45, 200, 250, 0, 0, 0, 60, 40)
    private val volume = floatArrayOf(0.25f, 0.4f, 0.55f, 0.35f, 0.3f, 0.45f, 0.35f, 0.6f, 0.7f, 0.8f, 0.8f, 0.8f, 0.5f, 0.4f)

    fun init(context: Context) {
        if (pool != null) return
        val p = SoundPool.Builder()
            .setMaxStreams(10)
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            .build()
        pool = p
        val dir = File(context.cacheDir, "sfx").apply { mkdirs() }
        Thread {
            for (i in 0 until COUNT) {
                val f = File(dir, "s${i}_v2.wav")
                if (!f.exists()) runCatching { write(f, synth(i)) }
                ids[i] = p.load(f.absolutePath, 1)
            }
        }.start()
    }

    fun play(id: Int) {
        if (!enabled) return
        val p = pool ?: return
        val now = SystemClock.uptimeMillis()
        if (now - last[id] < gap[id]) return
        last[id] = now
        if (ids[id] != 0) p.play(ids[id], volume[id], volume[id], 1, 0, 1f)
    }

    // ---- Synthesis --------------------------------------------------------------

    private fun synth(id: Int): FloatArray {
        val rnd = Random(id * 97 + 5)
        fun buf(sec: Double) = FloatArray((sec * RATE).toInt())
        fun env(t: Double, len: Double, attack: Double = 0.004) = (if (t < attack) t / attack else 1.0) * exp(-5.0 * t / len)
        return when (id) {
            SHOOT -> buf(0.08).also { b -> for (i in b.indices) { val t = i.toDouble() / RATE; b[i] = (sq(t * (1400 - 6000 * t)) * env(t, 0.08)).toFloat() } }
            CANNON -> buf(0.18).also { b -> for (i in b.indices) { val t = i.toDouble() / RATE; b[i] = ((sin(2 * PI * (110 - 300 * t) * t) * 0.7 + (rnd.nextDouble() * 2 - 1) * 0.5) * env(t, 0.18)).toFloat() } }
            BOOM -> buf(0.35).also { b -> var lp = 0.0; for (i in b.indices) { val t = i.toDouble() / RATE; lp += ((rnd.nextDouble() * 2 - 1) - lp) * 0.08; b[i] = ((lp * 2.2 + sin(2 * PI * 55 * t) * 0.5) * env(t, 0.35)).toFloat() } }
            ZAP -> buf(0.16).also { b -> for (i in b.indices) { val t = i.toDouble() / RATE; b[i] = ((sq(t * 900) * 0.4 + (rnd.nextDouble() * 2 - 1) * 0.4) * (0.6 + 0.4 * sin(2 * PI * 60 * t)) * env(t, 0.16)).toFloat() } }
            FROST -> buf(0.22).also { b -> for (i in b.indices) { val t = i.toDouble() / RATE; b[i] = ((sin(2 * PI * 1760 * t) + sin(2 * PI * 2637 * t) * 0.5) * 0.4 * env(t, 0.22)).toFloat() } }
            SNIPER -> buf(0.25).also { b -> for (i in b.indices) { val t = i.toDouble() / RATE; b[i] = (((rnd.nextDouble() * 2 - 1) * exp(-40 * t) + sin(2 * PI * (300 - 600 * t) * t) * 0.5) * env(t, 0.25)).toFloat() } }
            POP -> buf(0.09).also { b -> for (i in b.indices) { val t = i.toDouble() / RATE; b[i] = (sin(2 * PI * (500 + 2500 * t) * t) * env(t, 0.09)).toFloat() } }
            COIN -> notes(listOf(988.0, 1319.0), 0.09)
            LEAK -> buf(0.3).also { b -> for (i in b.indices) { val t = i.toDouble() / RATE; b[i] = (sq(t * (180 - 150 * t)) * 0.6 * env(t, 0.3)).toFloat() } }
            REWIND -> buf(1.0).also { b ->
                var ph = 0.0
                for (i in b.indices) {
                    val t = i.toDouble() / RATE
                    val f = 1400 * exp(-2.2 * t) + 120
                    ph += 2 * PI * f / RATE
                    val wob = 0.7 + 0.3 * sin(2 * PI * 18 * t)
                    b[i] = ((sin(ph) * 0.6 + sin(ph * 1.5) * 0.25) * wob * (if (t < 0.05) t / 0.05 else 1.0) * (1 - t)).toFloat()
                }
            }
            WIN -> notes(listOf(523.0, 659.0, 784.0, 1047.0), 0.14)
            LOSE -> notes(listOf(392.0, 330.0, 262.0, 196.0), 0.18)
            BUILD -> buf(0.12).also { b -> for (i in b.indices) { val t = i.toDouble() / RATE; b[i] = ((sin(2 * PI * 220 * t) * 0.6 + (rnd.nextDouble() * 2 - 1) * 0.3 * exp(-30 * t)) * env(t, 0.12)).toFloat() } }
            else -> buf(0.04).also { b -> for (i in b.indices) { val t = i.toDouble() / RATE; b[i] = (sin(2 * PI * 1200 * t) * env(t, 0.04)).toFloat() } }
        }
    }

    private fun sq(phase: Double): Double = if ((phase % 1.0) < 0.5) 0.6 else -0.6

    private fun notes(freqs: List<Double>, each: Double): FloatArray {
        val n = (each * RATE).toInt()
        val out = FloatArray(n * freqs.size + n)
        freqs.forEachIndexed { k, f ->
            for (i in 0 until n * 2) {
                val idx = k * n + i
                if (idx >= out.size) break
                val t = i.toDouble() / RATE
                out[idx] += ((sin(2 * PI * f * t) * 0.5 + sin(4 * PI * f * t) * 0.15) * exp(-4.0 * t / (each * 2)) * 0.7).toFloat()
            }
        }
        return out
    }

    private fun write(f: File, samples: FloatArray) {
        val data = ByteBuffer.allocate(44 + samples.size * 2).order(ByteOrder.LITTLE_ENDIAN)
        data.put("RIFF".toByteArray()).putInt(36 + samples.size * 2).put("WAVE".toByteArray())
        data.put("fmt ".toByteArray()).putInt(16).putShort(1).putShort(1).putInt(RATE).putInt(RATE * 2).putShort(2).putShort(16)
        data.put("data".toByteArray()).putInt(samples.size * 2)
        for (s in samples) data.putShort((s.coerceIn(-1f, 1f) * 32000).toInt().toShort())
        FileOutputStream(f).use { it.write(data.array()) }
    }
}
