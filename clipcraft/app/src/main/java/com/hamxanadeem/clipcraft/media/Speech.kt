package com.hamxanadeem.clipcraft.media

import android.content.Context
import android.net.Uri
import com.hamxanadeem.clipcraft.core.Copyright
import com.hamxanadeem.clipcraft.core.Json
import com.hamxanadeem.clipcraft.core.Transcript
import com.hamxanadeem.clipcraft.core.Word
import com.hamxanadeem.clipcraft.data.SpeechModel
import org.vosk.LibVosk
import org.vosk.LogLevel
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream
import kotlin.math.sqrt

/** On-device transcription with word timings (Vosk). Call from a background thread. */
object Speech {

    fun modelDir(context: Context, m: SpeechModel): File = File(context.filesDir, "models/${m.code}")

    fun hasModel(context: Context, m: SpeechModel): Boolean = File(modelDir(context, m), "ready").exists()

    /** Downloads and unpacks a speech model the first time it's needed. */
    fun download(context: Context, m: SpeechModel, onProgress: (Float) -> Unit) {
        val dir = modelDir(context, m)
        if (hasModel(context, m)) return
        dir.deleteRecursively()
        dir.mkdirs()
        val conn = URL(m.url).openConnection() as HttpURLConnection
        conn.connectTimeout = 20_000
        conn.readTimeout = 60_000
        val total = conn.contentLengthLong.takeIf { it > 0 } ?: (m.sizeMb * 1_000_000L)
        var read = 0L
        val counting = object : java.io.FilterInputStream(conn.inputStream.buffered()) {
            override fun read(b: ByteArray, off: Int, len: Int): Int {
                val n = super.read(b, off, len)
                if (n > 0) {
                    read += n
                    onProgress((read.toFloat() / total).coerceIn(0f, 1f))
                }
                return n
            }
        }
        ZipInputStream(counting).use { zip ->
            var e = zip.nextEntry
            while (e != null) {
                // Strip the top folder ("vosk-model-small-en-us-0.15/...").
                val rel = e.name.substringAfter('/', "")
                if (rel.isNotEmpty() && !rel.contains("..")) {
                    val f = File(dir, rel)
                    if (e.isDirectory) f.mkdirs() else {
                        f.parentFile?.mkdirs()
                        f.outputStream().use { zip.copyTo(it) }
                    }
                }
                e = zip.nextEntry
            }
        }
        conn.disconnect()
        File(dir, "ready").writeText("ok")
    }

    /** A transcript plus the soundtrack's loudness every half second (for the music check). */
    class Result(val transcript: Transcript, val loudness: FloatArray)

    fun transcribe(context: Context, uri: Uri, m: SpeechModel, onProgress: (Float) -> Unit): Result {
        LibVosk.setLogLevel(LogLevel.WARNINGS)
        val model = Model(modelDir(context, m).absolutePath)
        val rec = Recognizer(model, AudioDecoder.RATE.toFloat())
        rec.setWords(true)
        val results = mutableListOf<String>()
        val loudness = ArrayList<Float>()
        val perWindow = (AudioDecoder.RATE * Copyright.WINDOW).toInt()
        var sumSq = 0.0
        var count = 0
        try {
            AudioDecoder.decode(context, uri, onProgress) { pcm ->
                var i = 0
                while (i + 1 < pcm.size) {
                    val v = ((pcm[i + 1].toInt() shl 8) or (pcm[i].toInt() and 0xFF)) / 32768.0
                    sumSq += v * v
                    count++
                    if (count == perWindow) {
                        loudness += sqrt(sumSq / count).toFloat()
                        sumSq = 0.0
                        count = 0
                    }
                    i += 2
                }
                if (rec.acceptWaveForm(pcm, pcm.size)) results += rec.result
            }
            results += rec.finalResult
            if (count > 0) loudness += sqrt(sumSq / count).toFloat()
        } finally {
            rec.close()
            model.close()
        }
        return Result(Transcript.fromVosk(results), loudness.toFloatArray())
    }

    fun saveLoudness(file: File, l: FloatArray) {
        file.parentFile?.mkdirs()
        file.writeText(Copyright.encode(l))
    }

    fun loadLoudness(file: File): FloatArray? = if (file.exists()) runCatching { Copyright.decode(file.readText()) }.getOrNull() else null

    /** Saves a transcript so reopening a video doesn't transcribe it again. */
    fun save(file: File, t: Transcript) {
        file.parentFile?.mkdirs()
        file.writeText(t.words.joinToString(",", "[", "]") { w ->
            "{\"w\":${Json.quote(w.text)},\"s\":${w.start},\"e\":${w.end},\"c\":${w.conf}}"
        })
    }

    fun load(file: File): Transcript? {
        if (!file.exists()) return null
        return runCatching {
            Transcript(Json.arr(Json.parse(file.readText())).map {
                val o = Json.obj(it)
                Word(Json.str(o["w"]), Json.num(o["s"]), Json.num(o["e"]), Json.num(o["c"], 1.0))
            })
        }.getOrNull()
    }
}
