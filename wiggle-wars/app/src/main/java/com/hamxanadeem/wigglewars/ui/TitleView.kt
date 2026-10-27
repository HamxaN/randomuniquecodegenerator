package com.hamxanadeem.wigglewars.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.os.SystemClock
import android.util.AttributeSet
import android.view.View
import com.hamxanadeem.wigglewars.core.Weapon
import com.hamxanadeem.wigglewars.core.Worm
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * The menu backdrop, synthwave style: a striped neon sun over a glowing grid that
 * rolls towards you, stars, three worms on a light bridge and a glowing logo.
 */
class TitleView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    private val dp = resources.displayMetrics.density
    private val painter = WormPainter()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val path = Path()
    private val random = Random(7)
    private val worms = List(3) { Worm(it, it, "", 0.0, 0.0).apply { facing = if (it == 2) -1 else 1 } }
    private var sky: Shader? = null
    private var sun: Shader? = null
    private var floor: Shader? = null
    private var logo: Shader? = null
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Neon.black(context); textAlign = Paint.Align.CENTER }
    private val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Neon.black(context)
        textAlign = Paint.Align.CENTER
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
    }
    private val sub = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Neon.bold(context); textAlign = Paint.Align.CENTER }
    private class Burst(val x: Float, val y: Float, val color: Int, val start: Long)
    private val bursts = ArrayList<Burst>()
    private val stars = List(70) { Triple(random.nextFloat(), random.nextFloat() * 0.55f, random.nextFloat()) }

    /** Pixels on the right covered by a menu panel; the logo and worms centre in the rest. */
    var reservedRight = 0f
        set(value) {
            field = value
            onSizeChanged(width, height, width, height)
            invalidate()
        }

    private val areaWidth: Float get() = (width - reservedRight).coerceAtLeast(width * 0.4f)
    private val horizon: Float get() = height * 0.62f
    private var nextBurst = 0L

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        val hz = h * 0.62f
        sky = LinearGradient(0f, 0f, 0f, hz, intArrayOf(0xFF05021A.toInt(), 0xFF1E0A4A.toInt(), 0xFF5A1470.toInt(), 0xFFB0306E.toInt()), floatArrayOf(0f, 0.45f, 0.8f, 1f), Shader.TileMode.CLAMP)
        val r = min(w, h) * 0.24f
        sun = LinearGradient(0f, hz - r * 1.6f, 0f, hz, 0xFFFFE66D.toInt(), 0xFFFF2BD6.toInt(), Shader.TileMode.CLAMP)
        floor = LinearGradient(0f, hz, 0f, h.toFloat(), 0xFF1A0638.toInt(), 0xFF05021A.toInt(), Shader.TileMode.CLAMP)
        var size = h * 0.17f
        // Orbitron is wide: shrink the logo until it fits the free space with a margin.
        fill.textSize = size
        val room = (w - reservedRight).coerceAtLeast(w * 0.4f) * 0.88f
        val textWidth = fill.measureText(TITLE)
        if (textWidth > room) size *= room / textWidth
        fill.textSize = size
        glow.textSize = size
        glow.strokeWidth = size * 0.08f
        sub.textSize = size * 0.22f
        logo = LinearGradient(0f, h * 0.1f, 0f, h * 0.1f + size, 0xFF9CFBFF.toInt(), 0xFFFF2BD6.toInt(), Shader.TileMode.CLAMP)
    }

    override fun onDraw(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        val t = now / 1000f
        val w = width.toFloat()
        val h = height.toFloat()
        val hz = horizon

        // Sky and stars.
        paint.shader = sky
        canvas.drawRect(0f, 0f, w, hz, paint)
        paint.shader = null
        for ((i, s) in stars.withIndex()) {
            paint.color = 0xFFFFFFFF.toInt()
            paint.alpha = (110 + 145 * (0.5f + 0.5f * sin(t * (1f + s.third * 2f) + i))).toInt()
            canvas.drawCircle(s.first * w, s.second * h, (0.6f + s.third * 1.2f) * dp, paint)
        }
        paint.alpha = 255

        // Striped sun sitting on the horizon behind the worms.
        val cx = areaWidth / 2f
        val r = min(w, h) * 0.24f
        val sunY = hz - r * 0.35f
        canvas.save()
        canvas.clipRect(0f, 0f, w, hz)
        paint.shader = sun
        paint.setShadowLayer(28 * dp, 0f, 0f, 0xAAFF2BD6.toInt())
        canvas.drawCircle(cx, sunY, r, paint)
        paint.clearShadowLayer()
        paint.shader = null
        paint.color = 0xFF2A0B4F.toInt()
        for (i in 0 until 7) {
            val y = sunY + r * (0.05f + i * 0.14f)
            val gap = r * (0.025f + i * 0.012f)
            canvas.drawRect(cx - r, y, cx + r, y + gap, paint)
        }
        canvas.restore()

        // Neon grid floor rolling towards the viewer.
        paint.shader = floor
        canvas.drawRect(0f, hz, w, h, paint)
        paint.shader = null
        line.strokeWidth = 1.4f * dp
        line.color = 0xCCFF2BD6.toInt()
        line.setShadowLayer(5 * dp, 0f, 0f, 0xFFFF2BD6.toInt())
        val vanishX = cx
        for (i in -14..14) {
            val bottomX = vanishX + i * w * 0.12f
            canvas.drawLine(vanishX + i * w * 0.012f, hz, bottomX, h, line)
        }
        val scroll = (t * 0.6f) % 1f
        for (i in 0 until 10) {
            val k = ((i + scroll) / 10f)
            val y = hz + (h - hz) * k * k
            line.alpha = (60 + 195 * k).toInt()
            canvas.drawLine(0f, y, w, y, line)
        }
        line.alpha = 255
        line.color = 0xFF00E5FF.toInt()
        line.setShadowLayer(8 * dp, 0f, 0f, 0xFF00E5FF.toInt())
        line.strokeWidth = 2.2f * dp
        canvas.drawLine(0f, hz, w, hz, line)
        line.clearShadowLayer()

        // Neon fireworks.
        if (now > nextBurst) {
            bursts += Burst(areaWidth * (0.1f + random.nextFloat() * 0.8f), h * (0.3f + random.nextFloat() * 0.18f), BURST_COLORS[random.nextInt(BURST_COLORS.size)], now)
            nextBurst = now + 800 + random.nextInt(800)
        }
        val it = bursts.iterator()
        while (it.hasNext()) {
            val b = it.next()
            val k = (now - b.start) / 900f
            if (k >= 1f) {
                it.remove()
                continue
            }
            paint.color = b.color
            paint.alpha = (255 * (1 - k)).toInt()
            for (i in 0 until 14) {
                val a = i * 0.4488f
                val rr = k * 46 * dp
                canvas.drawCircle(b.x + kotlin.math.cos(a) * rr, b.y + sin(a) * rr, 2.4f * dp * (1 - k) + 0.8f, paint)
            }
            paint.alpha = 255
        }

        // Three worms on a glowing light bridge.
        val s = h / 72f
        val bridgeY = hz + 26 * dp
        paint.color = 0x5500E5FF
        canvas.drawRect(areaWidth * 0.18f, bridgeY, areaWidth * 0.82f, bridgeY + 6 * dp, paint)
        line.color = 0xFF00E5FF.toInt()
        line.strokeWidth = 2 * dp
        line.setShadowLayer(10 * dp, 0f, 0f, 0xFF00E5FF.toInt())
        canvas.drawLine(areaWidth * 0.18f, bridgeY, areaWidth * 0.82f, bridgeY, line)
        line.clearShadowLayer()
        for ((i, worm) in worms.withIndex()) {
            val wx = areaWidth * (0.3f + i * 0.2f)
            val hop = maxOf(0f, sin(t * 3f + i * 2f)) * 6 * s
            worm.aim = sin(t + i) * 0.5
            canvas.save()
            canvas.translate(wx, bridgeY - Worm.RADIUS.toFloat() * s - hop)
            canvas.scale(s, s)
            worm.x = 0.0
            worm.y = 0.0
            worm.onGround = hop < 0.5f
            painter.draw(canvas, worm, i, t + i, true, HELD[i], false)
            canvas.restore()
        }

        // Logo with a neon glow and a slow pulse.
        val y1 = h * 0.1f + fill.textSize
        val pulse = 0.75f + 0.25f * sin(t * 2.2f)
        glow.color = 0xFF00E5FF.toInt()
        glow.setShadowLayer(18 * dp * pulse, 0f, 0f, 0xFF00E5FF.toInt())
        canvas.drawText(TITLE, areaWidth / 2f, y1, glow)
        glow.clearShadowLayer()
        fill.shader = logo
        canvas.drawText(TITLE, areaWidth / 2f, y1, fill)
        fill.shader = null
        sub.color = 0xFFFF9CF0.toInt()
        sub.setShadowLayer(6 * dp, 0f, 0f, 0xFFFF2BD6.toInt())
        sub.letterSpacing = 0.5f
        canvas.drawText("WORM ARTILLERY", areaWidth / 2f, y1 + sub.textSize * 1.9f, sub)
        sub.clearShadowLayer()

        if (isShown) postInvalidateOnAnimation()
    }

    private companion object {
        const val TITLE = "WIGGLE WARS"
        val BURST_COLORS = intArrayOf(Neon.CYAN, Neon.MAGENTA, Neon.LIME, Neon.AMBER)
        val HELD = listOf(Weapon.BAZOOKA, Weapon.SNIPER, Weapon.BANANA)
    }
}
