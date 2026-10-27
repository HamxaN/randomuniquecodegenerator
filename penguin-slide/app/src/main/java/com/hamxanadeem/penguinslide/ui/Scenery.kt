package com.hamxanadeem.penguinslide.ui

import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.Shader
import kotlin.math.sin

/**
 * The backdrop: a sky that fades from bright day to sunset to dusk, a sun that sinks,
 * two layers of mountains and drifting clouds, all with parallax.
 */
class Scenery {

    private val skyPaint = Paint()
    private val sunPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val farPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val nearPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val cloudPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val starPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFFFFFFF.toInt() }
    private val path = Path()
    private var width = 0
    private var height = 0
    private var lastDay = -1f
    private var sunX = 0f
    private var sunY = 0f
    private var sunR = 0f

    fun resize(w: Int, h: Int) {
        width = w
        height = h
        lastDay = -1f
    }

    /**
     * [day] is 1 for full daylight down to 0 for dusk. [scroll] is the camera's x in
     * pixels, used for parallax.
     */
    fun draw(canvas: Canvas, day: Float, scroll: Float, time: Float) {
        if (width == 0) return
        val d = day.coerceIn(0f, 1f)
        if (kotlin.math.abs(d - lastDay) > 0.01f) updateColors(d)

        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), skyPaint)

        // Stars fade in at dusk.
        if (d < 0.35f) {
            starPaint.alpha = ((0.35f - d) / 0.35f * 200).toInt()
            for (i in 0 until 30) {
                val sx = (i * 137.5f * 7 + 40) % width
                val sy = (i * 61.3f * 3) % (height * 0.45f)
                val twinkle = 1f + 0.5f * sin(time * 3f + i)
                canvas.drawCircle(sx, sy, 1.5f * twinkle, starPaint)
            }
        }

        // The sun sinks as the time runs out.
        canvas.drawCircle(sunX, sunY, sunR * 2.4f, sunPaint)

        drawMountains(canvas, scroll * 0.08f, height * 0.42f, height * 0.18f, 380f, farPaint)
        drawClouds(canvas, scroll * 0.15f + time * 12f)
        drawMountains(canvas, scroll * 0.2f, height * 0.55f, height * 0.16f, 240f, nearPaint)
    }

    private fun updateColors(d: Float) {
        lastDay = d
        sunX = width * 0.78f
        sunY = height * (0.12f + (1f - d) * 0.5f)
        sunR = height * 0.07f
        sunPaint.shader = RadialGradient(
            sunX, sunY, sunR * 2.4f,
            intArrayOf(lerpColor(0xFFFF7043, 0xFFFFF59D, d), lerpColor(0x66FF7043, 0x66FFF59D, d), 0x00FFFFFF),
            floatArrayOf(0.38f, 0.42f, 1f),
            Shader.TileMode.CLAMP,
        )
        val top = lerpColor(0xFF2B1B55, 0xFF4FC3F7, d)
        val bottom = lerpColor(0xFFFF8A65, 0xFFE1F5FE, d)
        skyPaint.shader = LinearGradient(0f, 0f, 0f, height.toFloat(), top, bottom, Shader.TileMode.CLAMP)
        farPaint.color = lerpColor(0xFF5C4B8A, 0xFFB3C7E6, d)
        nearPaint.color = lerpColor(0xFF7E6BA8, 0xFFD6E4F5, d)
        cloudPaint.color = lerpColor(0xCCFFCCBC, 0xE6FFFFFF, d)
    }

    private fun drawMountains(canvas: Canvas, offset: Float, baseY: Float, peak: Float, spacing: Float, paint: Paint) {
        val dp = spacing
        val start = -((offset % dp) + dp)
        path.reset()
        path.moveTo(start, height.toFloat())
        var x = start
        var i = kotlin.math.floor((offset) / dp).toInt()
        while (x < width + dp) {
            val tall = 0.6f + 0.4f * (((i * 7919) % 5 + 5) % 5) / 4f
            path.lineTo(x, baseY)
            path.lineTo(x + dp / 2f, baseY - peak * tall)
            x += dp
            i++
        }
        path.lineTo(x, baseY)
        path.lineTo(x, height.toFloat())
        path.close()
        canvas.drawPath(path, paint)
    }

    private fun drawClouds(canvas: Canvas, offset: Float) {
        val spacing = width * 0.7f
        val start = -(offset % spacing)
        var x = start - spacing
        var i = kotlin.math.floor(offset / spacing).toInt()
        while (x < width + spacing) {
            val y = height * (0.12f + 0.12f * (((i * 31) % 3 + 3) % 3))
            val r = height * 0.035f
            canvas.drawCircle(x, y, r, cloudPaint)
            canvas.drawCircle(x + r * 1.1f, y - r * 0.5f, r * 1.3f, cloudPaint)
            canvas.drawCircle(x + r * 2.3f, y, r * 1.05f, cloudPaint)
            canvas.drawRect(x, y, x + r * 2.3f, y + r, cloudPaint)
            x += spacing
            i++
        }
    }

    companion object {
        fun lerpColor(from: Long, to: Long, t: Float): Int {
            val a = from.toInt()
            val b = to.toInt()
            fun ch(shift: Int) = ((a shr shift and 0xFF) + ((b shr shift and 0xFF) - (a shr shift and 0xFF)) * t).toInt() and 0xFF
            return (ch(24) shl 24) or (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
        }
    }
}
