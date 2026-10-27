package com.hamxanadeem.wigglewars.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.graphics.Typeface
import android.os.SystemClock
import android.util.AttributeSet
import android.view.View
import com.hamxanadeem.wigglewars.core.Worm
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/** The menu backdrop: a hill with three bobbing worms, bursts of fireworks and the logo. */
class TitleView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    private val dp = resources.displayMetrics.density
    private val painter = WormPainter()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val path = Path()
    private val random = Random(7)
    private val worms = List(3) { Worm(it, it, "", 0.0, 0.0).apply { facing = if (it == 2) -1 else 1 } }
    private var sky: Shader? = null
    private var logo: Shader? = null
    private val black = Typeface.create("sans-serif-black", Typeface.NORMAL)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = black; textAlign = Paint.Align.CENTER }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = black
        textAlign = Paint.Align.CENTER
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
        color = 0xFF3E2723.toInt()
    }
    private class Burst(val x: Float, val y: Float, val color: Int, val start: Long)
    private val bursts = ArrayList<Burst>()
    private var nextBurst = 0L

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        sky = LinearGradient(0f, 0f, 0f, h.toFloat(), 0xFF5EC4FF.toInt(), 0xFFFFE0B2.toInt(), Shader.TileMode.CLAMP)
        val size = min(w / 7.5f, h * 0.2f)
        fill.textSize = size
        stroke.textSize = size
        stroke.strokeWidth = size * 0.16f
        logo = LinearGradient(0f, h * 0.12f, 0f, h * 0.12f + size, 0xFFFFF59D.toInt(), 0xFFFF6F00.toInt(), Shader.TileMode.CLAMP)
    }

    override fun onDraw(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        val t = now / 1000f
        paint.shader = sky
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        paint.shader = null

        // Fireworks in the sky.
        if (now > nextBurst) {
            bursts += Burst(width * (0.1f + random.nextFloat() * 0.8f), height * (0.35f + random.nextFloat() * 0.2f), TeamColors.colors[random.nextInt(4)], now)
            nextBurst = now + 700 + random.nextInt(700)
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
            for (i in 0 until 12) {
                val a = i * 0.5236f
                val r = k * 50 * dp
                canvas.drawCircle(b.x + kotlin.math.cos(a) * r, b.y + sin(a) * r, 3 * dp * (1 - k) + 1, paint)
            }
            paint.alpha = 255
        }

        // Rolling hill.
        paint.color = 0xFF8BD653.toInt()
        path.reset()
        path.moveTo(0f, height.toFloat())
        var x = 0f
        while (x <= width) {
            path.lineTo(x, height * 0.78f - sin(x / width * 3.14f) * height * 0.12f)
            x += 8 * dp
        }
        path.lineTo(width.toFloat(), height.toFloat())
        path.close()
        canvas.drawPath(path, paint)
        paint.color = 0xFF96612F.toInt()
        canvas.save()
        canvas.translate(0f, 16 * dp)
        canvas.drawPath(path, paint)
        canvas.restore()

        // Three worms bobbing on the hill.
        val s = height / 70f
        for ((i, w) in worms.withIndex()) {
            val wx = width * (0.3f + i * 0.2f)
            val ground = height * 0.78f - sin(wx / width * 3.14f) * height * 0.12f
            val hop = maxOf(0f, sin(t * 3f + i * 2f)) * 6 * s
            w.aim = sin(t + i) * 0.5
            canvas.save()
            canvas.translate(wx, ground - Worm.RADIUS.toFloat() * s - hop)
            canvas.scale(s, s)
            w.x = 0.0
            w.y = 0.0
            w.onGround = hop < 0.5f
            painter.draw(canvas, w, i, t + i, true, com.hamxanadeem.wigglewars.core.Weapon.entries[(i * 3) % 9], false)
            canvas.restore()
        }

        // Logo.
        val y1 = height * 0.12f + fill.textSize
        val wobble = sin(t * 2f) * 2f
        canvas.save()
        canvas.rotate(wobble, width / 2f, y1)
        canvas.drawText("WIGGLE WARS", width / 2f, y1, stroke)
        fill.shader = logo
        canvas.drawText("WIGGLE WARS", width / 2f, y1, fill)
        canvas.restore()

        if (isShown) postInvalidateOnAnimation()
    }
}
