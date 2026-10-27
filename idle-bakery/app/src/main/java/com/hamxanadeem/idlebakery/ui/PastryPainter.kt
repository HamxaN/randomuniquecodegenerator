package com.hamxanadeem.idlebakery.ui

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import kotlin.math.cos
import kotlin.math.sin

/** Draws each station's pastry, and the little baker who runs a managed station. */
class PastryPainter {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val path = Path()
    private val oval = RectF()

    /** Draws pastry [index] centred at ([cx], [cy]) fitting in [s] pixels. */
    fun draw(canvas: Canvas, index: Int, cx: Float, cy: Float, s: Float, time: Float, locked: Boolean) {
        val save = canvas.save()
        if (locked) paint.colorFilter = GREY
        when (index) {
            0 -> cookie(canvas, cx, cy, s)
            1 -> cupcake(canvas, cx, cy, s)
            2 -> donut(canvas, cx, cy, s)
            3 -> croissant(canvas, cx, cy, s)
            4 -> pie(canvas, cx, cy, s)
            5 -> layerCake(canvas, cx, cy, s, time)
            6 -> macarons(canvas, cx, cy, s)
            else -> weddingCake(canvas, cx, cy, s)
        }
        paint.colorFilter = null
        canvas.restoreToCount(save)
    }

    private fun fill(color: Int) {
        paint.style = Paint.Style.FILL
        paint.color = color
    }

    private fun ellipse(canvas: Canvas, cx: Float, cy: Float, rx: Float, ry: Float, color: Int) {
        fill(color)
        oval.set(cx - rx, cy - ry, cx + rx, cy + ry)
        canvas.drawOval(oval, paint)
    }

    private fun shine(canvas: Canvas, cx: Float, cy: Float, r: Float) {
        ellipse(canvas, cx, cy, r, r * 0.6f, 0x55FFFFFF)
    }

    private fun cookie(c: Canvas, x: Float, y: Float, s: Float) {
        val r = s * 0.42f
        ellipse(c, x, y + r * 0.08f, r, r * 0.95f, 0xFFB5793B.toInt())
        ellipse(c, x, y, r, r * 0.92f, 0xFFE0A85C.toInt())
        val chips = floatArrayOf(-0.4f, -0.3f, 0.25f, -0.45f, 0.1f, 0.05f, -0.2f, 0.4f, 0.45f, 0.3f, 0.5f, -0.15f, -0.55f, 0.15f)
        for (i in chips.indices step 2) ellipse(c, x + chips[i] * r, y + chips[i + 1] * r, r * 0.11f, r * 0.09f, 0xFF4E2A12.toInt())
        shine(c, x - r * 0.35f, y - r * 0.5f, r * 0.25f)
    }

    private fun cupcake(c: Canvas, x: Float, y: Float, s: Float) {
        val w = s * 0.62f
        // Wrapper.
        fill(0xFFF06292.toInt())
        path.reset()
        path.moveTo(x - w / 2, y)
        path.lineTo(x + w / 2, y)
        path.lineTo(x + w * 0.36f, y + s * 0.42f)
        path.lineTo(x - w * 0.36f, y + s * 0.42f)
        path.close()
        c.drawPath(path, paint)
        paint.color = 0xFFC2185B.toInt()
        paint.strokeWidth = s * 0.025f
        for (i in -2..2) c.drawLine(x + i * w * 0.18f, y, x + i * w * 0.13f, y + s * 0.42f, paint)
        // Swirl of frosting.
        ellipse(c, x, y - s * 0.02f, w * 0.58f, s * 0.13f, 0xFFFFF3E0.toInt())
        ellipse(c, x, y - s * 0.14f, w * 0.45f, s * 0.12f, 0xFFFFE0F0.toInt())
        ellipse(c, x, y - s * 0.25f, w * 0.3f, s * 0.1f, 0xFFFFF3E0.toInt())
        ellipse(c, x, y - s * 0.38f, s * 0.07f, s * 0.07f, 0xFFD32F2F.toInt())
        shine(c, x - w * 0.2f, y - s * 0.17f, s * 0.06f)
    }

    private fun donut(c: Canvas, x: Float, y: Float, s: Float) {
        val r = s * 0.42f
        ellipse(c, x, y + r * 0.08f, r, r * 0.9f, 0xFFC68642.toInt())
        // Icing with a wavy edge.
        fill(0xFFF48FB1.toInt())
        path.reset()
        for (i in 0..36) {
            val a = i / 36f * 6.2832f
            val rr = r * (0.84f + 0.05f * sin(a * 7))
            if (i == 0) path.moveTo(x + cos(a) * rr, y + sin(a) * rr * 0.86f) else path.lineTo(x + cos(a) * rr, y + sin(a) * rr * 0.86f)
        }
        path.close()
        c.drawPath(path, paint)
        val sprinkles = intArrayOf(0xFFFFEB3B.toInt(), 0xFF4FC3F7.toInt(), 0xFFFFFFFF.toInt(), 0xFF81C784.toInt())
        paint.strokeWidth = s * 0.03f
        paint.strokeCap = Paint.Cap.ROUND
        for (i in 0 until 14) {
            val a = i * 2.4f
            val d = r * (0.45f + 0.28f * ((i * 37) % 10) / 10f)
            paint.color = sprinkles[i % sprinkles.size]
            val px = x + cos(a) * d
            val py = y + sin(a) * d * 0.86f
            c.drawLine(px, py, px + cos(a * 3) * s * 0.04f, py + sin(a * 3) * s * 0.04f, paint)
        }
        ellipse(c, x, y, r * 0.3f, r * 0.26f, 0xFF5D4037.toInt())
        ellipse(c, x, y + r * 0.03f, r * 0.27f, r * 0.22f, 0xFFFFF8E1.toInt())
        shine(c, x - r * 0.45f, y - r * 0.45f, r * 0.2f)
    }

    private fun croissant(c: Canvas, x: Float, y: Float, s: Float) {
        val colors = intArrayOf(0xFFD4892F.toInt(), 0xFFE9A84C.toInt())
        for (i in -2..2) {
            val k = kotlin.math.abs(i)
            val rx = s * (0.17f - k * 0.03f)
            val ry = s * (0.24f - k * 0.05f)
            val px = x + i * s * 0.15f
            val py = y + k * k * s * 0.04f
            ellipse(c, px, py, rx, ry, colors[(i + 2) % 2])
            ellipse(c, px - rx * 0.2f, py - ry * 0.4f, rx * 0.4f, ry * 0.25f, 0x40FFFFFF)
        }
    }

    private fun pie(c: Canvas, x: Float, y: Float, s: Float) {
        val r = s * 0.44f
        ellipse(c, x, y + r * 0.25f, r, r * 0.42f, 0xFF90A4AE.toInt())
        ellipse(c, x, y + r * 0.12f, r * 0.92f, r * 0.38f, 0xFFD4892F.toInt())
        ellipse(c, x, y + r * 0.08f, r * 0.8f, r * 0.3f, 0xFF8E2434.toInt())
        // Lattice.
        paint.color = 0xFFF0B866.toInt()
        paint.strokeWidth = s * 0.05f
        for (i in -2..2) {
            c.drawLine(x + i * r * 0.28f - r * 0.12f, y - r * 0.15f, x + i * r * 0.28f + r * 0.12f, y + r * 0.33f, paint)
            c.drawLine(x - r * 0.7f, y + r * 0.08f + i * r * 0.09f, x + r * 0.7f, y + r * 0.08f + i * r * 0.09f, paint)
        }
        shine(c, x - r * 0.4f, y - r * 0.05f, r * 0.15f)
    }

    private fun layerCake(c: Canvas, x: Float, y: Float, s: Float, time: Float) {
        val w = s * 0.7f
        fill(0xFF6D4C41.toInt())
        c.drawRect(x - w / 2, y - s * 0.05f, x + w / 2, y + s * 0.35f, paint)
        fill(0xFFFFF8E1.toInt())
        c.drawRect(x - w / 2, y + s * 0.1f, x + w / 2, y + s * 0.16f, paint)
        ellipse(c, x, y - s * 0.05f, w / 2, s * 0.09f, 0xFF8D6E63.toInt())
        // Drips.
        fill(0xFF5D4037.toInt())
        for (i in 0 until 5) {
            val dx = x - w / 2 + w * (i + 0.5f) / 5
            oval.set(dx - s * 0.04f, y - s * 0.05f, dx + s * 0.04f, y + s * (0.05f + 0.03f * (i % 2)))
            c.drawOval(oval, paint)
        }
        // Candle with a flickering flame.
        fill(0xFF64B5F6.toInt())
        c.drawRect(x - s * 0.025f, y - s * 0.3f, x + s * 0.025f, y - s * 0.08f, paint)
        val flicker = 1f + 0.15f * sin(time * 20f)
        ellipse(c, x, y - s * 0.35f, s * 0.04f * flicker, s * 0.07f * flicker, 0xFFFFB300.toInt())
        ellipse(c, x, y - s * 0.34f, s * 0.02f, s * 0.035f, 0xFFFFF59D.toInt())
    }

    private fun macarons(c: Canvas, x: Float, y: Float, s: Float) {
        val colors = intArrayOf(0xFFF8BBD0.toInt(), 0xFFB2EBF2.toInt(), 0xFFDCEDC8.toInt())
        for (i in 0 until 3) {
            val py = y + s * 0.25f - i * s * 0.2f
            val px = x + (i - 1) * s * 0.04f
            ellipse(c, px, py + s * 0.04f, s * 0.3f, s * 0.08f, colors[i])
            ellipse(c, px, py, s * 0.28f, s * 0.04f, 0xFFFFFDE7.toInt())
            ellipse(c, px, py - s * 0.04f, s * 0.3f, s * 0.08f, colors[i])
            shine(c, px - s * 0.1f, py - s * 0.07f, s * 0.07f)
        }
    }

    private fun weddingCake(c: Canvas, x: Float, y: Float, s: Float) {
        val tiers = floatArrayOf(0.8f, 0.6f, 0.4f)
        var top = y + s * 0.42f
        for ((i, w) in tiers.withIndex()) {
            val h = s * 0.2f
            fill(0xFFFFFFFF.toInt())
            c.drawRect(x - s * w / 2, top - h, x + s * w / 2, top, paint)
            fill(0xFFFFD54F.toInt())
            c.drawRect(x - s * w / 2, top - h * 0.35f, x + s * w / 2, top - h * 0.2f, paint)
            ellipse(c, x, top - h, s * w / 2, s * 0.04f, 0xFFF5F5F5.toInt())
            top -= h
            if (i == 2) {
                // Two hearts on top.
                ellipse(c, x - s * 0.04f, top - s * 0.06f, s * 0.04f, s * 0.04f, 0xFFE91E63.toInt())
                ellipse(c, x + s * 0.04f, top - s * 0.06f, s * 0.04f, s * 0.04f, 0xFFE91E63.toInt())
            }
        }
    }

    /** A small chef with a tall hat, bobbing as they work. */
    fun baker(canvas: Canvas, cx: Float, bottom: Float, s: Float, time: Float) {
        val bob = sin(time * 6f) * s * 0.04f
        val y = bottom + bob
        ellipse(canvas, cx, y - s * 0.22f, s * 0.26f, s * 0.24f, 0xFFFFFFFF.toInt())
        ellipse(canvas, cx, y - s * 0.55f, s * 0.2f, s * 0.2f, 0xFFFFCC9A.toInt())
        // Eyes and smile.
        ellipse(canvas, cx - s * 0.07f, y - s * 0.58f, s * 0.025f, s * 0.035f, 0xFF3E2723.toInt())
        ellipse(canvas, cx + s * 0.07f, y - s * 0.58f, s * 0.025f, s * 0.035f, 0xFF3E2723.toInt())
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = s * 0.025f
        paint.color = 0xFF3E2723.toInt()
        oval.set(cx - s * 0.07f, y - s * 0.56f, cx + s * 0.07f, y - s * 0.44f)
        canvas.drawArc(oval, 20f, 140f, false, paint)
        paint.style = Paint.Style.FILL
        ellipse(canvas, cx - s * 0.12f, y - s * 0.5f, s * 0.035f, s * 0.025f, 0x55FF7043)
        ellipse(canvas, cx + s * 0.12f, y - s * 0.5f, s * 0.035f, s * 0.025f, 0x55FF7043)
        // Hat.
        fill(0xFFFFFFFF.toInt())
        canvas.drawRect(cx - s * 0.15f, y - s * 0.82f, cx + s * 0.15f, y - s * 0.7f, paint)
        ellipse(canvas, cx - s * 0.1f, y - s * 0.9f, s * 0.11f, s * 0.11f, 0xFFFFFFFF.toInt())
        ellipse(canvas, cx + s * 0.1f, y - s * 0.9f, s * 0.11f, s * 0.11f, 0xFFFFFFFF.toInt())
        ellipse(canvas, cx, y - s * 0.97f, s * 0.13f, s * 0.12f, 0xFFFFFFFF.toInt())
        // A waving whisk arm.
        val wave = sin(time * 9f) * 25f
        canvas.save()
        canvas.rotate(-30f + wave, cx + s * 0.2f, y - s * 0.3f)
        fill(0xFFFFFFFF.toInt())
        canvas.drawRect(cx + s * 0.18f, y - s * 0.34f, cx + s * 0.4f, y - s * 0.26f, paint)
        fill(0xFF9E9E9E.toInt())
        canvas.drawRect(cx + s * 0.4f, y - s * 0.32f, cx + s * 0.5f, y - s * 0.28f, paint)
        canvas.restore()
    }

    private companion object {
        val GREY = android.graphics.ColorMatrixColorFilter(android.graphics.ColorMatrix().apply { setSaturation(0f) })
    }
}
