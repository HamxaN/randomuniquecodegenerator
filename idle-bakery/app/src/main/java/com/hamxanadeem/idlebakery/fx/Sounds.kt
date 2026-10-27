package com.hamxanadeem.idlebakery.fx

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.util.Log
import java.io.File

/**
 * Plays short sound effects. Each effect is synthesised once into the cache folder
 * and loaded into a low-latency [SoundPool], so the app ships no audio files.
 */
object Sounds {

    var enabled = true

    private var pool: SoundPool? = null
    private val ids = HashMap<String, Int>()

    /** [effects] maps a name to a function that makes the WAV bytes. */
    fun init(context: Context, effects: Map<String, () -> ByteArray>) {
        if (pool != null) return
        val app = context.applicationContext
        val soundPool = SoundPool.Builder()
            .setMaxStreams(6)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .build()
        pool = soundPool
        Thread {
            for ((name, make) in effects) {
                try {
                    val file = File(app.cacheDir, "sfx_v1_$name.wav")
                    if (!file.exists()) {
                        val tmp = File(app.cacheDir, "sfx_v1_$name.tmp")
                        tmp.writeBytes(make())
                        tmp.renameTo(file)
                    }
                    val id = soundPool.load(file.path, 1)
                    synchronized(ids) { ids[name] = id }
                } catch (e: Exception) {
                    Log.w("Sounds", "Could not prepare $name", e)
                }
            }
        }.start()
    }

    fun play(name: String, rate: Float = 1f, volume: Float = 1f) {
        if (!enabled) return
        val id = synchronized(ids) { ids[name] } ?: return
        pool?.play(id, volume, volume, 1, 0, rate.coerceIn(0.5f, 2f))
    }
}
