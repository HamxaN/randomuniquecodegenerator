package com.hamxanadeem.clipcraft.media

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import java.nio.ByteOrder

/**
 * Decodes a video's soundtrack to 16 kHz mono 16-bit PCM, the format the speech
 * recogniser wants, handing it over in chunks as it goes.
 */
object AudioDecoder {
    const val RATE = 16000

    /** [onChunk] gets little-endian PCM bytes; [onProgress] 0..1. Returns the duration in seconds. */
    fun decode(context: Context, uri: Uri, onProgress: (Float) -> Unit, onChunk: (ByteArray) -> Unit): Double {
        val ex = MediaExtractor()
        ex.setDataSource(context, uri, null)
        var track = -1
        for (i in 0 until ex.trackCount) {
            val mime = ex.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) {
                track = i
                break
            }
        }
        if (track < 0) {
            ex.release()
            throw IllegalStateException("This video has no sound track.")
        }
        ex.selectTrack(track)
        val fmt = ex.getTrackFormat(track)
        val durationUs = if (fmt.containsKey(MediaFormat.KEY_DURATION)) fmt.getLong(MediaFormat.KEY_DURATION) else 0L
        val codec = MediaCodec.createDecoderByType(fmt.getString(MediaFormat.KEY_MIME)!!)
        codec.configure(fmt, null, null, 0)
        codec.start()
        var inRate = fmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var channels = fmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        // Resampler state: position in the input stream, in output-sample units.
        var phase = 0.0
        var prev = 0f
        try {
            while (!outputDone) {
                if (!inputDone) {
                    val ii = codec.dequeueInputBuffer(10_000)
                    if (ii >= 0) {
                        val buf = codec.getInputBuffer(ii)!!
                        val n = ex.readSampleData(buf, 0)
                        if (n < 0) {
                            codec.queueInputBuffer(ii, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(ii, 0, n, ex.sampleTime, 0)
                            ex.advance()
                        }
                    }
                }
                val oi = codec.dequeueOutputBuffer(info, 10_000)
                when {
                    oi == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val of = codec.outputFormat
                        inRate = of.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = of.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                    oi >= 0 -> {
                        val buf = codec.getOutputBuffer(oi)!!
                        buf.position(info.offset)
                        buf.limit(info.offset + info.size)
                        val shorts = buf.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                        val frames = shorts.remaining() / maxOf(channels, 1)
                        val step = inRate.toDouble() / RATE
                        val out = java.io.ByteArrayOutputStream(frames * 2)
                        for (f in 0 until frames) {
                            var sum = 0f
                            for (ch in 0 until channels) sum += shorts.get(f * channels + ch)
                            val mono = sum / channels
                            // Linear-interpolated resampling to 16 kHz.
                            while (phase <= 1.0) {
                                val v = (prev + (mono - prev) * phase.toFloat()).toInt().coerceIn(-32768, 32767)
                                out.write(v and 0xFF)
                                out.write((v shr 8) and 0xFF)
                                phase += step
                            }
                            phase -= 1.0
                            prev = mono
                        }
                        if (out.size() > 0) onChunk(out.toByteArray())
                        if (durationUs > 0) onProgress((info.presentationTimeUs.toFloat() / durationUs).coerceIn(0f, 1f))
                        codec.releaseOutputBuffer(oi, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            }
        } finally {
            codec.stop()
            codec.release()
            ex.release()
        }
        return durationUs / 1_000_000.0
    }
}
