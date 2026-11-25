package com.hamxanadeem.clipcraft.media

import android.content.Context
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Typeface
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.text.SpannableString
import android.text.Spanned
import android.text.style.AbsoluteSizeSpan
import android.text.style.BackgroundColorSpan
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.OverlaySettings
import androidx.media3.effect.Presentation
import androidx.media3.effect.TextOverlay
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import com.google.common.collect.ImmutableList
import com.hamxanadeem.clipcraft.core.Caption
import com.hamxanadeem.clipcraft.core.Captions
import com.hamxanadeem.clipcraft.core.ClipPlan
import com.hamxanadeem.clipcraft.core.PanPath
import java.io.File
import java.util.Locale

/**
 * How a clip should look. [preset] is "karaoke" (white words on a dark band, the spoken
 * word coloured), "boxed" (the spoken word in a coloured box) or "clean" (no band).
 * [position] is "low", "middle" or "top".
 */
data class Style(
    val captions: Boolean,
    val hook: Boolean,
    val highlight: Int,
    val preset: String = "karaoke",
    val position: String = "low",
) {
    val anchorY: Float get() = when (position) {
        "middle" -> 0f
        "top" -> 0.45f
        else -> -0.42f
    }
}

/**
 * Cuts one clip out of the video and turns it into a vertical 1080x1920 short with
 * word-by-word captions and an optional hook title. Runs on the main thread (Media3
 * Transformer needs a Looper) and reports back through callbacks.
 */
@OptIn(UnstableApi::class)
class ClipRenderer(private val context: Context) {

    private var transformer: Transformer? = null
    private val handler = Handler(Looper.getMainLooper())

    fun render(
        video: Uri,
        plan: ClipPlan,
        captions: List<Caption>,
        style: Style,
        pan: PanPath?,
        out: File,
        onProgress: (Int) -> Unit,
        onDone: (Result<File>) -> Unit,
    ) {
        out.parentFile?.mkdirs()
        out.delete()
        val item = MediaItem.Builder()
            .setUri(video)
            .setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs((plan.start * 1000).toLong())
                    .setEndPositionMs((plan.end * 1000).toLong())
                    .build()
            )
            .build()
        val overlays = mutableListOf<TextureOverlay>()
        if (style.captions && captions.isNotEmpty()) overlays += CaptionOverlay(captions, style)
        if (style.hook && (plan.hook.isNotBlank() || plan.title.isNotBlank())) overlays += HookOverlay(plan.hook.ifBlank { plan.title })
        val effects = mutableListOf<androidx.media3.common.Effect>()
        // Follow the speaker's face: slide the picture sideways before the centre 9:16 crop.
        if (pan != null && !pan.still) effects += FacePan(pan)
        effects += Presentation.createForWidthAndHeight(1080, 1920, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP)
        if (overlays.isNotEmpty()) effects += OverlayEffect(ImmutableList.copyOf(overlays))
        val edited = EditedMediaItem.Builder(item)
            .setEffects(Effects(ImmutableList.of(), ImmutableList.copyOf(effects)))
            .build()
        val t = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    stopPolling()
                    onDone(Result.success(out))
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    stopPolling()
                    onDone(Result.failure(exportException))
                }
            })
            .build()
        transformer = t
        t.start(edited, out.absolutePath)
        poll(onProgress)
    }

    private var poller: Runnable? = null

    private fun poll(onProgress: (Int) -> Unit) {
        val holder = ProgressHolder()
        val r = object : Runnable {
            override fun run() {
                val t = transformer ?: return
                if (t.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) onProgress(holder.progress)
                handler.postDelayed(this, 300)
            }
        }
        poller = r
        handler.post(r)
    }

    private fun stopPolling() {
        poller?.let { handler.removeCallbacks(it) }
        poller = null
        transformer = null
    }

    fun cancel() {
        transformer?.cancel()
        stopPolling()
    }

    /** Shifts each frame horizontally along [pan] (in normalised device coordinates). */
    private class FacePan(private val pan: PanPath) : MatrixTransformation {
        private var firstUs = -1L
        private val m = Matrix()

        override fun getMatrix(presentationTimeUs: Long): Matrix {
            if (firstUs < 0) firstUs = presentationTimeUs
            m.reset()
            m.setTranslate(pan.at((presentationTimeUs - firstUs) / 1_000_000.0).toFloat(), 0f)
            return m
        }
    }

    /** Word-by-word captions in the chosen style, with the word being spoken highlighted. */
    private class CaptionOverlay(private val captions: List<Caption>, private val style: Style) : TextOverlay() {
        private var firstUs = -1L
        private val settings = OverlaySettings.Builder().setBackgroundFrameAnchor(0f, style.anchorY).build()

        override fun getText(presentationTimeUs: Long): SpannableString {
            if (firstUs < 0) firstUs = presentationTimeUs
            // Timestamps may or may not start at zero after clipping; measure from the first frame.
            val t = (presentationTimeUs - firstUs) / 1_000_000.0
            val cap = Captions.at(captions, t) ?: return SpannableString(" ")
            val words = cap.words.map { it.text.uppercase(Locale.getDefault()) }
            val text = " " + words.joinToString(" ") + " "
            val s = SpannableString(text)
            val all = Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            s.setSpan(AbsoluteSizeSpan(if (style.preset == "clean") 100 else 92), 0, text.length, all)
            s.setSpan(StyleSpan(Typeface.BOLD), 0, text.length, all)
            s.setSpan(ForegroundColorSpan(Color.WHITE), 0, text.length, all)
            when (style.preset) {
                "boxed" -> s.setSpan(BackgroundColorSpan(0x66000000), 0, text.length, all)
                "clean" -> Unit
                else -> s.setSpan(BackgroundColorSpan(0x99000000.toInt()), 0, text.length, all)
            }
            val active = cap.active(t)
            if (active >= 0) {
                var start = 1
                for (i in 0 until active) start += words[i].length + 1
                val end = start + words[active].length
                if (style.preset == "boxed") {
                    s.setSpan(BackgroundColorSpan(style.highlight), start, end, all)
                    s.setSpan(ForegroundColorSpan(Color.BLACK), start, end, all)
                } else {
                    s.setSpan(ForegroundColorSpan(style.highlight), start, end, all)
                }
            }
            return s
        }

        override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings = settings
    }

    /** The hook line at the top, for the whole clip. */
    private class HookOverlay(hook: String) : TextOverlay() {
        private val text: SpannableString
        private val settings = OverlaySettings.Builder().setBackgroundFrameAnchor(0f, 0.72f).build()

        init {
            val line = " " + hook.trim().take(48) + " "
            text = SpannableString(line)
            val all = Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            text.setSpan(AbsoluteSizeSpan(64), 0, line.length, all)
            text.setSpan(StyleSpan(Typeface.BOLD), 0, line.length, all)
            text.setSpan(ForegroundColorSpan(Color.BLACK), 0, line.length, all)
            text.setSpan(BackgroundColorSpan(Color.WHITE), 0, line.length, all)
        }

        override fun getText(presentationTimeUs: Long): SpannableString = text

        override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings = settings
    }
}
