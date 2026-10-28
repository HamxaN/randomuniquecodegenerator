package com.hamxanadeem.parkingjam.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.SystemClock
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.hamxanadeem.parkingjam.core.Car
import com.hamxanadeem.parkingjam.core.Dir
import com.hamxanadeem.parkingjam.core.Lot
import com.hamxanadeem.parkingjam.core.TapResult
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Draws the parking lot from above: asphalt bays with painted lines, a road around
 * the edge, and chunky cartoon cars. Tap a car to drive it out; blocked cars bump
 * and honk. Cars that leave zoom off along their way out.
 */
class LotView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    interface Listener {
        fun onTapped(result: TapResult)
        fun onCleared()
    }

    var listener: Listener? = null
    var lot: Lot? = null
        set(value) {
            field = value
            leaving.clear()
            bumping.clear()
            confettiAt = 0L
            hintCar = -1
            appearedAt = SystemClock.uptimeMillis()
            requestLayout()
            invalidate()
        }

    private val dp = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Typeface.create("sans-serif-black", Typeface.NORMAL); textAlign = Paint.Align.CENTER }
    private val rect = RectF()
    private val arrow = android.graphics.Path()
    private val random = Random(3)

    // Layout: size of one cell and the lot's top-left corner on screen.
    private var cell = 0f
    private var ox = 0f
    private var oy = 0f
    private var appearedAt = 0L

    private class Leaving(val car: Car, val start: Long)
    private class Bumping(val car: Car, val blocker: Car, val gap: Int, val start: Long)
    private val leaving = ArrayList<Leaving>()
    private val bumping = ArrayList<Bumping>()
    private var confettiAt = 0L
    private val confetti = List(80) { floatArrayOf(random.nextFloat(), random.nextFloat() * 0.3f, random.nextFloat(), random.nextFloat()) }
    /** A car to point at for the hint, or -1. */
    var hintCar = -1

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) = layoutLot()

    private fun layoutLot() {
        val l = lot ?: return
        if (width == 0) return
        // The lot plus a road one cell wide all round.
        cell = min(width / (l.width + 2f), height / (l.height + 2f))
        ox = (width - cell * l.width) / 2
        oy = (height - cell * l.height) / 2
    }

    override fun onDraw(canvas: Canvas) {
        val l = lot ?: return
        if (cell == 0f) layoutLot()
        val now = SystemClock.uptimeMillis()
        drawGround(canvas, l)
        // Pop the cars in when a level starts.
        val pop = ((now - appearedAt) / 350f).coerceIn(0f, 1f)
        for (car in l.cars) {
            val b = bumping.lastOrNull { it.car.id == car.id }
            val hitBy = bumping.lastOrNull { it.blocker.id == car.id }
            var dx = 0f
            var dy = 0f
            var wobble = 0f
            if (b != null) {
                val k = (now - b.start) / BUMP_MS
                // Roll forward to the blocker, then back.
                val reach = (b.gap + 0.18f) * (if (k < 0.5f) k * 2 else (1 - k) * 2)
                dx = car.dir.dx * reach * cell
                dy = car.dir.dy * reach * cell
            }
            if (hitBy != null) {
                val k = (now - hitBy.start) / BUMP_MS
                if (k > 0.4f) wobble = sin(k * 40f) * (1 - k) * 6f
            }
            val delay = (car.id % 8) * 0.04f
            val s = ((pop - delay) / (1 - delay)).coerceIn(0f, 1f)
            drawCar(canvas, car, dx, dy, wobble, s, hint = car.id == hintCar && (now / 300) % 2 == 0L)
        }
        // Cars driving away.
        val it = leaving.iterator()
        while (it.hasNext()) {
            val lv = it.next()
            val k = (now - lv.start) / LEAVE_MS
            if (k >= 1f) {
                it.remove()
                continue
            }
            val dist = k * k * (l.width + l.height + 4) * cell
            drawCar(canvas, lv.car, lv.car.dir.dx * dist, lv.car.dir.dy * dist, 0f, 1f, hint = false)
        }
        bumping.removeAll { now - it.start > BUMP_MS }
        for (b in bumping) {
            // "BEEP!" over the bumping car.
            val (fx, fy) = b.car.front
            val k = (now - b.start) / BUMP_MS
            text.textSize = 16 * dp
            text.color = 0xFFFFFFFF.toInt()
            paint.color = 0xE6212121.toInt()
            val tx = ox + (fx + 0.5f) * cell
            val ty = oy + (fy + 0.5f) * cell - cell * (0.6f + k * 0.3f)
            rect.set(tx - 34 * dp, ty - 20 * dp, tx + 34 * dp, ty + 6 * dp)
            canvas.drawRoundRect(rect, 12 * dp, 12 * dp, paint)
            canvas.drawText("BEEP!", tx, ty - 1 * dp, text)
        }
        if (confettiAt > 0) drawConfetti(canvas, now)
        if (leaving.isNotEmpty() || bumping.isNotEmpty() || pop < 1f || confettiAt > 0 || hintCar >= 0) postInvalidateOnAnimation()
    }

    private fun drawGround(canvas: Canvas, l: Lot) {
        // Grass, then the road around the lot.
        canvas.drawColor(0xFF7CB342.toInt())
        paint.color = 0xFF8BC34A.toInt()
        for (i in 0 until 40) {
            val x = (i * 97 % 100) / 100f * width
            val y = (i * 61 % 100) / 100f * height
            canvas.drawCircle(x, y, 18 * dp, paint)
        }
        rect.set(ox - cell, oy - cell, ox + (l.width + 1) * cell, oy + (l.height + 1) * cell)
        paint.color = 0xFF546E7A.toInt()
        canvas.drawRoundRect(rect, cell * 0.6f, cell * 0.6f, paint)
        // Dashed centre line on the road.
        stroke.color = 0xFFFFEE58.toInt()
        stroke.strokeWidth = 3 * dp
        val r = cell * 0.5f
        rect.set(ox - r, oy - r, ox + l.width * cell + r, oy + l.height * cell + r)
        var x = rect.left + cell
        while (x < rect.right - cell) {
            canvas.drawLine(x, rect.top, x + cell * 0.4f, rect.top, stroke)
            canvas.drawLine(x, rect.bottom, x + cell * 0.4f, rect.bottom, stroke)
            x += cell * 0.8f
        }
        var y = rect.top + cell
        while (y < rect.bottom - cell) {
            canvas.drawLine(rect.left, y, rect.left, y + cell * 0.4f, stroke)
            canvas.drawLine(rect.right, y, rect.right, y + cell * 0.4f, stroke)
            y += cell * 0.8f
        }
        // The lot itself, with white bay lines.
        rect.set(ox, oy, ox + l.width * cell, oy + l.height * cell)
        paint.color = 0xFF37474F.toInt()
        canvas.drawRect(rect, paint)
        stroke.color = 0x66FFFFFF
        stroke.strokeWidth = 1.5f * dp
        for (i in 1 until l.width) canvas.drawLine(ox + i * cell, oy, ox + i * cell, oy + l.height * cell, stroke)
        for (j in 1 until l.height) canvas.drawLine(ox, oy + j * cell, ox + l.width * cell, oy + j * cell, stroke)
        stroke.color = 0xFFFFFFFF.toInt()
        stroke.strokeWidth = 3 * dp
        canvas.drawRect(rect, stroke)
    }

    /** A top-down cartoon car (or truck), facing its direction. */
    private fun drawCar(canvas: Canvas, car: Car, dx: Float, dy: Float, wobble: Float, scale: Float, hint: Boolean) {
        if (scale <= 0f) return
        val cells = car.cells()
        val minX = cells.minOf { it.first }
        val minY = cells.minOf { it.second }
        val maxX = cells.maxOf { it.first }
        val maxY = cells.maxOf { it.second }
        val inset = cell * 0.1f
        val left = ox + minX * cell + inset + dx + wobble
        val top = oy + minY * cell + inset + dy
        val right = ox + (maxX + 1) * cell - inset + dx + wobble
        val bottom = oy + (maxY + 1) * cell - inset + dy
        val cx = (left + right) / 2
        val cy = (top + bottom) / 2
        val save = canvas.save()
        canvas.scale(scale, scale, cx, cy)
        // Rotate so the car is drawn facing right, then turned to its direction.
        val angle = when (car.dir) {
            Dir.RIGHT -> 0f
            Dir.DOWN -> 90f
            Dir.LEFT -> 180f
            Dir.UP -> 270f
        }
        canvas.rotate(angle, cx, cy)
        val len = (if (car.dir.horizontal) right - left else bottom - top) / 2
        val wid = (if (car.dir.horizontal) bottom - top else right - left) / 2
        // Shadow.
        paint.color = 0x55000000
        rect.set(cx - len + 2 * dp, cy - wid + 4 * dp, cx + len + 2 * dp, cy + wid + 4 * dp)
        canvas.drawRoundRect(rect, wid * 0.6f, wid * 0.6f, paint)
        // Wheels.
        paint.color = 0xFF212121.toInt()
        for (wx in floatArrayOf(cx - len * 0.6f, cx + len * 0.55f)) {
            rect.set(wx - wid * 0.32f, cy - wid * 1.06f, wx + wid * 0.32f, cy - wid * 0.7f)
            canvas.drawRoundRect(rect, 3 * dp, 3 * dp, paint)
            rect.set(wx - wid * 0.32f, cy + wid * 0.7f, wx + wid * 0.32f, cy + wid * 1.06f)
            canvas.drawRoundRect(rect, 3 * dp, 3 * dp, paint)
        }
        // Body.
        rect.set(cx - len, cy - wid, cx + len, cy + wid)
        paint.color = car.color
        canvas.drawRoundRect(rect, wid * 0.55f, wid * 0.55f, paint)
        paint.color = 0x33000000
        rect.set(cx - len, cy + wid * 0.35f, cx + len, cy + wid)
        canvas.drawRoundRect(rect, wid * 0.55f, wid * 0.55f, paint)
        if (car.length == 3) {
            // Truck: a cargo box behind the cab.
            paint.color = 0xFFECEFF1.toInt()
            rect.set(cx - len * 0.92f, cy - wid * 0.82f, cx + len * 0.25f, cy + wid * 0.82f)
            canvas.drawRoundRect(rect, wid * 0.2f, wid * 0.2f, paint)
            paint.color = 0x22000000
            for (i in 1..3) {
                val lx = cx - len * 0.92f + i * len * 0.29f
                canvas.drawRect(lx - 1 * dp, cy - wid * 0.82f, lx + 1 * dp, cy + wid * 0.82f, paint)
            }
            paint.color = 0xFF90CAF9.toInt()
            rect.set(cx + len * 0.45f, cy - wid * 0.62f, cx + len * 0.72f, cy + wid * 0.62f)
            canvas.drawRoundRect(rect, wid * 0.2f, wid * 0.2f, paint)
        } else {
            // Roof with windscreens.
            paint.color = 0xFF90CAF9.toInt()
            rect.set(cx - len * 0.45f, cy - wid * 0.66f, cx + len * 0.42f, cy + wid * 0.66f)
            canvas.drawRoundRect(rect, wid * 0.35f, wid * 0.35f, paint)
            paint.color = car.color
            rect.set(cx - len * 0.28f, cy - wid * 0.58f, cx + len * 0.18f, cy + wid * 0.58f)
            canvas.drawRoundRect(rect, wid * 0.25f, wid * 0.25f, paint)
            paint.color = 0x44FFFFFF
            rect.set(cx - len * 0.26f, cy - wid * 0.55f, cx + len * 0.16f, cy - wid * 0.2f)
            canvas.drawRoundRect(rect, wid * 0.2f, wid * 0.2f, paint)
        }
        // Headlights at the front, tail lights at the back.
        paint.color = 0xFFFFF59D.toInt()
        canvas.drawCircle(cx + len * 0.9f, cy - wid * 0.6f, wid * 0.16f, paint)
        canvas.drawCircle(cx + len * 0.9f, cy + wid * 0.6f, wid * 0.16f, paint)
        paint.color = 0xFFD50000.toInt()
        canvas.drawRect(cx - len * 0.98f, cy - wid * 0.7f, cx - len * 0.9f, cy - wid * 0.35f, paint)
        canvas.drawRect(cx - len * 0.98f, cy + wid * 0.35f, cx - len * 0.9f, cy + wid * 0.7f, paint)
        // Direction arrow on the roof, so it's clear which way it'll go.
        paint.color = 0xCCFFFFFF.toInt()
        val ax = cx + len * (if (car.length == 3) 0.05f else -0.05f)
        val a = wid * 0.32f
        val path = arrow
        path.reset()
        path.moveTo(ax + a, cy)
        path.lineTo(ax - a * 0.6f, cy - a)
        path.lineTo(ax - a * 0.6f, cy + a)
        path.close()
        canvas.drawPath(path, paint)
        if (hint) {
            stroke.color = 0xFFFFEB3B.toInt()
            stroke.strokeWidth = 4 * dp
            rect.set(cx - len - 4 * dp, cy - wid - 4 * dp, cx + len + 4 * dp, cy + wid + 4 * dp)
            canvas.drawRoundRect(rect, wid * 0.6f, wid * 0.6f, stroke)
        }
        canvas.restoreToCount(save)
    }

    private fun drawConfetti(canvas: Canvas, now: Long) {
        val k = (now - confettiAt) / 2200f
        if (k >= 1f) {
            confettiAt = 0L
            return
        }
        for ((i, c) in confetti.withIndex()) {
            val x = c[0] * width + sin(k * 8f + i) * 20 * dp
            val y = (c[1] - 0.3f + k * (0.9f + c[2] * 0.6f)) * height
            paint.color = LotGeneratorColors[i % LotGeneratorColors.size]
            canvas.save()
            canvas.rotate(k * 720f * (c[3] - 0.5f), x, y)
            canvas.drawRect(x - 5 * dp, y - 3 * dp, x + 5 * dp, y + 3 * dp, paint)
            canvas.restore()
        }
    }

    fun celebrate() {
        confettiAt = SystemClock.uptimeMillis()
        invalidate()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val l = lot ?: return false
        if (event.actionMasked != MotionEvent.ACTION_UP) return true
        performClick()
        val x = ((event.x - ox) / cell).toInt().let { if (event.x < ox) -1 else it }
        val y = ((event.y - oy) / cell).toInt().let { if (event.y < oy) -1 else it }
        val car = l.carAt(x, y) ?: return true
        if (bumping.any { it.car.id == car.id }) return true
        val result = l.tap(car.id)
        val now = SystemClock.uptimeMillis()
        when (result) {
            is TapResult.Exited -> {
                leaving += Leaving(result.car, now)
                if (hintCar == car.id) hintCar = -1
            }
            is TapResult.Bumped -> bumping += Bumping(result.car, result.blocker, result.gap, now)
            TapResult.Nothing -> Unit
        }
        listener?.onTapped(result)
        if (l.cleared) listener?.onCleared()
        invalidate()
        return true
    }

    override fun performClick(): Boolean = super.performClick()

    private companion object {
        const val BUMP_MS = 520f
        const val LEAVE_MS = 700f
        val LotGeneratorColors = com.hamxanadeem.parkingjam.core.LotGenerator.COLORS
    }
}
