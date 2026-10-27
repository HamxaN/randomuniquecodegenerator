package com.hamxanadeem.idlebakery.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.SystemClock
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.hamxanadeem.idlebakery.core.Bakery
import com.hamxanadeem.idlebakery.core.Menu
import com.hamxanadeem.idlebakery.core.Numbers
import kotlin.math.min
import kotlin.math.sin

/**
 * One bakery counter: the pastry (tap it to bake), its level, the batch progress bar,
 * what a batch earns, and the baker once a manager is hired.
 */
class StationView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    var index = 0
    var bakery: Bakery? = null
    var onBake: ((Int) -> Unit)? = null

    private val dp = resources.displayMetrics.density
    private val painter = PastryPainter()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rect = RectF()
    private val black = Typeface.create("sans-serif-black", Typeface.NORMAL)
    private val title = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = black; color = 0xFF4E342E.toInt() }
    private val small = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = black; color = 0xFF6D4C41.toInt() }
    private val barText = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = black; color = 0xFFFFFFFF.toInt(); textAlign = Paint.Align.CENTER }
    private var cardShader: Shader? = null
    private var barShader: Shader? = null
    private var popAt = 0L
    private var lastAmount = 0.0
    private var lastAmountAt = 0L

    /** Called when a batch pays out. */
    fun pop(amount: Double) {
        popAt = SystemClock.uptimeMillis()
        lastAmount = amount
        lastAmountAt = popAt
    }

    /** Centre of the pastry in window coordinates, for flying coins. */
    fun pastryCenterInWindow(out: IntArray) {
        getLocationInWindow(out)
        out[0] += (height * 0.55f).toInt()
        out[1] += height / 2
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        val tint = TINTS[index % TINTS.size]
        cardShader = LinearGradient(0f, 0f, 0f, h.toFloat(), 0xFFFFFDF7.toInt(), tint, Shader.TileMode.CLAMP)
        barShader = LinearGradient(0f, 0f, w.toFloat(), 0f, 0xFFFFB74D.toInt(), 0xFFFF7043.toInt(), Shader.TileMode.CLAMP)
        title.textSize = 17 * dp
        small.textSize = 12 * dp
        barText.textSize = 13 * dp
    }

    override fun onDraw(canvas: Canvas) {
        val bakery = bakery ?: return
        val now = SystemClock.uptimeMillis()
        val t = now / 1000f
        val station = Menu.stations[index]
        val locked = !bakery.isUnlocked(index)

        // Card.
        rect.set(2 * dp, 2 * dp, width - 2 * dp, height - 4 * dp)
        paint.shader = null
        paint.color = 0x33000000
        canvas.drawRoundRect(rect.left, rect.top + 3 * dp, rect.right, rect.bottom + 3 * dp, 18 * dp, 18 * dp, paint)
        paint.shader = if (locked) null else cardShader
        paint.color = if (locked) 0xFFE0D6CF.toInt() else 0xFFFFFFFF.toInt()
        canvas.drawRoundRect(rect, 18 * dp, 18 * dp, paint)
        paint.shader = null

        // Plate and pastry, with a bounce when a batch comes out.
        val art = height - 18 * dp
        val ax = 8 * dp + art / 2
        val ay = height / 2f
        paint.color = if (locked) 0x22000000 else 0x33FFFFFF
        canvas.drawCircle(ax, ay, art / 2, paint)
        val popT = (now - popAt) / 250f
        val scale = if (popT in 0f..1f) 1f + 0.18f * sin(popT * Math.PI.toFloat()) else 1f
        val save = canvas.save()
        canvas.scale(scale, scale, ax, ay)
        painter.draw(canvas, index, ax, ay, art * 0.8f, t, locked)
        canvas.restoreToCount(save)

        val textLeft = ax + art / 2 + 12 * dp
        val right = width - 12 * dp
        canvas.drawText(station.name, textLeft, 26 * dp, title)

        if (locked) {
            small.color = 0xFF8D6E63.toInt()
            canvas.drawText("🔒 Locked", textLeft, 50 * dp, small)
            return
        }

        // Level badge.
        val level = bakery.levels[index]
        val badge = "Lv $level"
        val bw = small.measureText(badge) + 14 * dp
        rect.set(right - bw, 10 * dp, right, 30 * dp)
        paint.color = 0xFF8D6E63.toInt()
        canvas.drawRoundRect(rect, 10 * dp, 10 * dp, paint)
        small.color = 0xFFFFFFFF.toInt()
        canvas.drawText(badge, rect.left + 7 * dp, rect.bottom - 6 * dp, small)

        // Progress bar showing what this batch will earn.
        val barTop = 38 * dp
        val barH = 22 * dp
        rect.set(textLeft, barTop, right, barTop + barH)
        paint.color = 0x33000000
        canvas.drawRoundRect(rect, barH / 2, barH / 2, paint)
        val fast = Menu.stations[index].seconds < 0.5 && bakery.managers[index]
        val fill = if (fast) 1f else bakery.batchProgress(index).toFloat()
        if (fill > 0f) {
            rect.set(textLeft, barTop, textLeft + (right - textLeft) * fill, barTop + barH)
            paint.shader = barShader
            canvas.drawRoundRect(rect, barH / 2, barH / 2, paint)
            paint.shader = null
        }
        val perBatch = bakery.revenuePerBatch(index, System.currentTimeMillis())
        barText.color = if (fill > 0.45f) 0xFFFFFFFF.toInt() else 0xFF5D4037.toInt()
        canvas.drawText("+${Numbers.format(perBatch)}", (textLeft + right) / 2, barTop + barH * 0.72f, barText)

        // Bottom line: time left, next milestone, and the baker or a tap hint.
        small.color = 0xFF6D4C41.toInt()
        val timeText = if (bakery.isRunning(index)) Numbers.duration(bakery.secondsLeft(index)) else Numbers.duration(station.seconds)
        canvas.drawText("⏱ $timeText", textLeft, barTop + barH + 18 * dp, small)
        bakery.nextMilestone(index)?.let {
            val text = "×2 at Lv $it"
            canvas.drawText(text, right - small.measureText(text), barTop + barH + 18 * dp, small)
        }

        if (bakery.managers[index]) {
            painter.baker(canvas, ax + art * 0.38f, ay + art * 0.48f, art * 0.42f, t + index)
        } else if (!bakery.isRunning(index)) {
            // Pulse "TAP" so new players know what to do.
            val pulse = 1f + 0.12f * sin(t * 6f)
            val s2 = canvas.save()
            canvas.scale(pulse, pulse, ax, ay + art * 0.32f)
            paint.color = 0xE6FF7043.toInt()
            rect.set(ax - 20 * dp, ay + art * 0.32f - 10 * dp, ax + 20 * dp, ay + art * 0.32f + 10 * dp)
            canvas.drawRoundRect(rect, 10 * dp, 10 * dp, paint)
            barText.color = 0xFFFFFFFF.toInt()
            barText.textSize = 11 * dp
            canvas.drawText("TAP!", ax, ay + art * 0.32f + 4 * dp, barText)
            barText.textSize = 13 * dp
            canvas.restoreToCount(s2)
        }

        // "+amount" floating up from the pastry.
        val floatT = (now - lastAmountAt) / 800f
        if (lastAmountAt > 0 && floatT < 1f && !fast) {
            barText.color = 0xFF2E7D32.toInt()
            barText.alpha = (255 * (1f - floatT)).toInt()
            canvas.drawText("+${Numbers.format(lastAmount)}", ax, ay - art * 0.3f - 20 * dp * floatT, barText)
            barText.alpha = 255
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_DOWN) return true
        if (event.actionMasked == MotionEvent.ACTION_UP) {
            performClick()
            onBake?.invoke(index)
        }
        return true
    }

    override fun performClick(): Boolean = super.performClick()

    private companion object {
        val TINTS = intArrayOf(
            0xFFFFE0B2.toInt(), 0xFFF8BBD0.toInt(), 0xFFFFCDD2.toInt(), 0xFFFFECB3.toInt(),
            0xFFD7CCC8.toInt(), 0xFFE1BEE7.toInt(), 0xFFB2EBF2.toInt(), 0xFFFFF9C4.toInt(),
        )
    }
}
