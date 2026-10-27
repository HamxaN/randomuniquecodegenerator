package com.hamxanadeem.wigglewars.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.hamxanadeem.wigglewars.core.Arena
import com.hamxanadeem.wigglewars.core.Terrain
import java.util.concurrent.Executors

/**
 * Shows the chosen arena as a little picture of a real map from it, with arrows to
 * flip through the arenas. The first choice is "Random".
 */
class ArenaCardView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    /** null means a random arena each match. */
    var arena: Arena? = null
        set(value) {
            field = value
            contentDescription = "Arena: ${value?.displayName ?: "Random"}. Tap the sides to change."
            invalidate()
        }
    var onChange: ((Arena?) -> Unit)? = null

    private val dp = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val black = Typeface.create("sans-serif-black", Typeface.NORMAL)
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = black }
    private val rect = RectF()
    private val clip = Path()
    private val arrow = Path()
    private var shade: Shader? = null

    private val main = Handler(Looper.getMainLooper())
    private val previews = HashMap<Arena, Bitmap>()

    init {
        arena = null
        // Draw a sample map of every arena once, off the main thread.
        val worker = Executors.newSingleThreadExecutor()
        for (a in Arena.entries) {
            worker.execute {
                val bmp = TerrainArt.preview(Terrain.generate(PREVIEW_SEED, a), MapTheme.forArena(a), 360, 180)
                main.post {
                    previews[a] = bmp
                    invalidate()
                }
            }
        }
        worker.shutdown()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        clip.reset()
        rect.set(0f, 0f, w.toFloat(), h.toFloat())
        clip.addRoundRect(rect, 16 * dp, 16 * dp, Path.Direction.CW)
        shade = LinearGradient(0f, h * 0.45f, 0f, h.toFloat(), 0x00000000, 0xCC000000.toInt(), Shader.TileMode.CLAMP)
    }

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        val save = canvas.save()
        canvas.clipPath(clip)
        paint.color = 0xFF241A5C.toInt()
        canvas.drawRect(0f, 0f, w, h, paint)

        val current = arena
        // Random flicks through all the arenas.
        val shown = current ?: Arena.entries[((SystemClock.uptimeMillis() / 700) % Arena.entries.size).toInt()]
        previews[shown]?.let { bmp ->
            paint.alpha = if (current == null) 110 else 255
            // Crop the map to fill the card.
            val scale = maxOf(w / bmp.width, h / bmp.height)
            val bw = bmp.width * scale
            val bh = bmp.height * scale
            rect.set((w - bw) / 2, (h - bh) / 2, (w + bw) / 2, (h + bh) / 2)
            canvas.drawBitmap(bmp, null, rect, paint)
            paint.alpha = 255
        }
        paint.shader = shade
        canvas.drawRect(0f, 0f, w, h, paint)
        paint.shader = null

        if (current == null) {
            text.textAlign = Paint.Align.CENTER
            text.textSize = 44 * dp
            text.color = 0xFFFFD54F.toInt()
            canvas.drawText("?", w / 2, h * 0.52f, text)
            postInvalidateDelayed(120)
        }

        text.textAlign = Paint.Align.CENTER
        text.textSize = 17 * dp
        text.color = 0xFFFFFFFF.toInt()
        canvas.drawText(current?.displayName ?: "Random Arena", w / 2, h - 26 * dp, text)
        text.textSize = 10.5f * dp
        text.color = 0xFFFFE082.toInt()
        val tagline = current?.tagline ?: "A surprise every battle"
        canvas.drawText(fit(tagline, w - 70 * dp), w / 2, h - 10 * dp, text)

        // Arrows on both sides.
        for (side in intArrayOf(-1, 1)) {
            val cx = if (side < 0) 20 * dp else w - 20 * dp
            val cy = h / 2
            paint.color = 0x88000000.toInt()
            canvas.drawCircle(cx, cy, 15 * dp, paint)
            paint.color = 0xFFFFFFFF.toInt()
            val a = 5 * dp
            arrow.reset()
            arrow.moveTo(cx - side * a * 0.6f, cy - a)
            arrow.lineTo(cx + side * a, cy)
            arrow.lineTo(cx - side * a * 0.6f, cy + a)
            arrow.close()
            canvas.drawPath(arrow, paint)
        }
        canvas.restoreToCount(save)

        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 2 * dp
        paint.color = 0x88FFFFFF.toInt()
        rect.set(dp, dp, w - dp, h - dp)
        canvas.drawRoundRect(rect, 15 * dp, 15 * dp, paint)
        paint.style = Paint.Style.FILL
    }

    private fun fit(s: String, max: Float): String {
        if (text.measureText(s) <= max) return s
        var end = s.length
        while (end > 1 && text.measureText(s, 0, end) + text.measureText("…") > max) end--
        return s.substring(0, end) + "…"
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_UP) {
            performClick()
            step(if (event.x < width / 2f) -1 else 1)
        }
        return true
    }

    override fun performClick(): Boolean = super.performClick()

    private fun step(dir: Int) {
        val options = listOf<Arena?>(null) + Arena.entries
        val i = options.indexOf(arena)
        arena = options[(i + dir + options.size) % options.size]
        onChange?.invoke(arena)
    }

    private companion object {
        const val PREVIEW_SEED = 7L
    }
}
