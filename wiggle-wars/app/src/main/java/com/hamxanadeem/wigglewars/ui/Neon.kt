package com.hamxanadeem.wigglewars.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import androidx.core.content.res.ResourcesCompat
import com.hamxanadeem.wigglewars.R

/**
 * The sci-fi look shared by every screen: dark glass panels with cut corners and
 * glowing neon edges, and the Orbitron typeface.
 */
object Neon {
    const val CYAN = 0xFF00E5FF.toInt()
    const val MAGENTA = 0xFFFF2BD6.toInt()
    const val VIOLET = 0xFF8C7CFF.toInt()
    const val LIME = 0xFF39FF88.toInt()
    const val AMBER = 0xFFFFC23D.toInt()
    const val RED = 0xFFFF3B6B.toInt()
    /** Dark glass behind panels. */
    const val GLASS = 0xE00A1024.toInt()
    const val GLASS_LIGHT = 0xE0142046.toInt()

    private var bold: Typeface? = null
    private var black: Typeface? = null

    fun bold(context: Context): Typeface =
        bold ?: (ResourcesCompat.getFont(context, R.font.orbitron_bold) ?: Typeface.DEFAULT_BOLD).also { bold = it }

    fun black(context: Context): Typeface =
        black ?: (ResourcesCompat.getFont(context, R.font.orbitron_black) ?: Typeface.DEFAULT_BOLD).also { black = it }

    /** A rectangle with its top-left and bottom-right corners cut off at 45°. */
    fun chamfer(path: Path, r: RectF, cut: Float) {
        val c = cut.coerceAtMost(minOf(r.width(), r.height()) / 2)
        path.reset()
        path.moveTo(r.left + c, r.top)
        path.lineTo(r.right, r.top)
        path.lineTo(r.right, r.bottom - c)
        path.lineTo(r.right - c, r.bottom)
        path.lineTo(r.left, r.bottom)
        path.lineTo(r.left, r.top + c)
        path.close()
    }

    /**
     * A glass panel with a glowing [accent] edge and little corner brackets.
     * [fill] and [paint] are scratch objects owned by the caller.
     */
    fun panel(canvas: Canvas, r: RectF, accent: Int, dp: Float, path: Path, paint: Paint, glass: Int = GLASS, glow: Boolean = true) {
        chamfer(path, r, 10 * dp)
        paint.style = Paint.Style.FILL
        paint.shader = null
        paint.color = glass
        canvas.drawPath(path, paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1.5f * dp
        paint.color = accent
        if (glow) paint.setShadowLayer(6 * dp, 0f, 0f, accent)
        canvas.drawPath(path, paint)
        paint.clearShadowLayer()
        // Brighter brackets on the two square corners.
        paint.strokeWidth = 2.5f * dp
        val b = minOf(14 * dp, r.width() / 4, r.height() / 3)
        canvas.drawLine(r.right - b, r.top, r.right, r.top, paint)
        canvas.drawLine(r.right, r.top, r.right, r.top + b, paint)
        canvas.drawLine(r.left, r.bottom - b, r.left, r.bottom, paint)
        canvas.drawLine(r.left, r.bottom, r.left + b, r.bottom, paint)
        paint.style = Paint.Style.FILL
    }

    /** Mixes [color] towards white, for text on dark glass. */
    fun light(color: Int, k: Float = 0.35f) = TerrainArt.mix(color, 0xFFFFFFFF.toInt(), k)

    fun withAlpha(color: Int, alpha: Int) = (color and 0x00FFFFFF) or (alpha.coerceIn(0, 255) shl 24)
}

/**
 * Background for neon buttons: a dark glass plate with cut corners, tinted by
 * [accent], with a glowing edge. Lights up while pressed.
 */
class NeonDrawable(private val accent: Int, private val dp: Float, private val cut: Float = 12f) : Drawable() {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val path = Path()
    private val rect = RectF()
    private var pressed = false
    private var enabled = true
    private var shader: Shader? = null

    override fun draw(canvas: Canvas) {
        val pad = 4 * dp
        rect.set(bounds.left + pad, bounds.top + pad, bounds.right - pad, bounds.bottom - pad)
        Neon.chamfer(path, rect, cut * dp)
        val a = if (enabled) 255 else 90
        if (shader == null) {
            shader = LinearGradient(
                0f, rect.top, 0f, rect.bottom,
                TerrainArt.mix(Neon.GLASS_LIGHT, accent, if (pressed) 0.55f else 0.28f),
                TerrainArt.mix(Neon.GLASS, accent, if (pressed) 0.35f else 0.1f),
                Shader.TileMode.CLAMP,
            )
        }
        paint.style = Paint.Style.FILL
        paint.shader = shader
        paint.alpha = if (enabled) 235 else 120
        canvas.drawPath(path, paint)
        paint.shader = null
        // A light sheen across the top.
        paint.color = 0x22FFFFFF
        canvas.drawRect(rect.left + cut * dp, rect.top + 2 * dp, rect.right - 2 * dp, rect.top + rect.height() * 0.38f, paint)
        // Glowing edge.
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = (if (pressed) 2.5f else 1.8f) * dp
        paint.color = Neon.withAlpha(accent, a)
        if (enabled) paint.setShadowLayer((if (pressed) 9 else 5) * dp, 0f, 0f, accent)
        canvas.drawPath(path, paint)
        paint.clearShadowLayer()
        // Accent tick on the left edge.
        paint.style = Paint.Style.FILL
        canvas.drawRect(rect.left, rect.top + cut * dp + 2 * dp, rect.left + 3 * dp, rect.bottom - 6 * dp, paint)
    }

    override fun isStateful() = true

    override fun onStateChange(state: IntArray): Boolean {
        val p = state.contains(android.R.attr.state_pressed)
        val e = state.contains(android.R.attr.state_enabled)
        if (p == pressed && e == enabled) return false
        pressed = p
        enabled = e
        shader = null
        invalidateSelf()
        return true
    }

    override fun onBoundsChange(bounds: android.graphics.Rect) {
        shader = null
    }

    override fun setAlpha(alpha: Int) = Unit
    override fun setColorFilter(colorFilter: ColorFilter?) = Unit

    @Deprecated("Deprecated in Java")
    override fun getOpacity() = PixelFormat.TRANSLUCENT
}
