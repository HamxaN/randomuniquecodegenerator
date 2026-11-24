package com.hamxanadeem.clipcraft.media

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.net.Uri
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.hamxanadeem.clipcraft.core.FaceSample
import com.hamxanadeem.clipcraft.core.PanPath
import com.hamxanadeem.clipcraft.core.Reframe
import java.util.concurrent.TimeUnit

/**
 * Finds where the speaker is in a clip so the vertical crop can follow them. Looks at
 * about one frame a second with ML Kit's on-device face detector and follows the
 * biggest face. Runs on a background thread; returns null when it can't help (no
 * faces, already-vertical video, detector unavailable).
 */
object FaceTracker {
    fun pan(context: Context, video: Uri, start: Double, end: Double, cancelled: () -> Boolean = { false }): PanPath? {
        val r = MediaMetadataRetriever()
        val detector = FaceDetection.getClient(
            FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                .setMinFaceSize(0.08f)
                .build()
        )
        try {
            r.setDataSource(context, video)
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: return null
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: return null
            val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            val (dw, dh) = if (rot == 90 || rot == 270) h to w else w to h
            val crop = Reframe.cropFraction(dw, dh)
            if (crop >= 0.999) return null
            val samples = mutableListOf<FaceSample>()
            val step = if (end - start > 120) 2.0 else 1.0
            var t = start
            var found = 0
            while (t < end && !cancelled()) {
                val frame = r.getFrameAtTime((t * 1_000_000).toLong(), MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                var x: Double? = null
                if (frame != null) {
                    val img = upright(small(frame), dw, dh, rot)
                    val faces = runCatching { Tasks.await(detector.process(InputImage.fromBitmap(img, 0)), 10, TimeUnit.SECONDS) }.getOrNull()
                    val face = faces?.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }
                    if (face != null) {
                        x = face.boundingBox.exactCenterX().toDouble() / img.width
                        found++
                    }
                    if (img !== frame) img.recycle()
                    frame.recycle()
                }
                samples += FaceSample(t - start, x)
                t += step
            }
            if (found == 0) return null
            return Reframe.path(samples, crop)
        } catch (_: Exception) {
            return null
        } finally {
            detector.close()
            runCatching { r.release() }
        }
    }

    /** Shrinks a frame to about 480 px wide; faces are still easy to find and it's much faster. */
    private fun small(b: Bitmap): Bitmap {
        val longSide = maxOf(b.width, b.height)
        if (longSide <= 640) return b
        val k = 640f / longSide
        return Bitmap.createScaledBitmap(b, (b.width * k).toInt().coerceAtLeast(1), (b.height * k).toInt().coerceAtLeast(1), true)
    }

    /** Some phones return frames before rotation; turn them the way the video is shown. */
    private fun upright(b: Bitmap, dw: Int, dh: Int, rot: Int): Bitmap {
        if (rot == 0) return b
        val framePortrait = b.height > b.width
        val shownPortrait = dh > dw
        if (framePortrait == shownPortrait) return b
        val m = Matrix().apply { postRotate(rot.toFloat()) }
        return Bitmap.createBitmap(b, 0, 0, b.width, b.height, m, true)
    }
}
