package com.hamxanadeem.tidyroom.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.os.SystemClock
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.hamxanadeem.tidyroom.core.DropResult
import com.hamxanadeem.tidyroom.core.Item
import com.hamxanadeem.tidyroom.core.Room
import com.hamxanadeem.tidyroom.core.RoomKind
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Draws a cosy room with its furniture, ghost outlines where things belong, and
 * the mess on the floor. Drag an item onto its outline and it snaps into place.
 */
class RoomView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    interface Listener {
        fun onDropped(result: DropResult)
        fun onPickedUp()
        fun onTidy()
    }

    var listener: Listener? = null
    var room: Room? = null
        set(value) {
            field = value
            dragging = null
            pops.clear()
            shakes.clear()
            hint = null
            invalidate()
        }
    /** An item and slot to point at for the hint. */
    var hint: Pair<Int, Int>? = null

    private val dp = resources.displayMetrics.density
    private val painter = ItemPainter()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
    private val dash = DashPathEffect(floatArrayOf(10f, 8f), 0f)
    private val rect = RectF()
    private val random = Random(9)

    private var dragging: Item? = null
    private var dragX = 0f
    private var dragY = 0f
    private var grabDx = 0f
    private var grabDy = 0f
    private val pops = HashMap<Int, Long>()
    private val shakes = HashMap<Int, Long>()

    private class Sparkle(var x: Float, var y: Float, var vx: Float, var vy: Float, var life: Float, val color: Int)
    private val sparkles = ArrayList<Sparkle>()

    private fun px(x: Float) = x * width
    private fun py(y: Float) = y * height
    private fun itemPx(size: Float) = size * width

    override fun onDraw(canvas: Canvas) {
        val r = room ?: return
        val now = SystemClock.uptimeMillis()
        drawRoom(canvas, r.kind)
        // Outlines where things still belong.
        for (s in r.slots) {
            if (r.items.any { it.slot == s.id }) continue
            val pulse = if (hint?.second == s.id) 1f + 0.12f * sin(now / 120f) else 1f
            painter.draw(canvas, s.type, px(s.x), py(s.y), itemPx(s.size) * pulse, ghost = true, ghostColor = if (hint?.second == s.id) 0x88FFC107.toInt() else 0x33000000)
            line.color = 0x66FFFFFF
            line.strokeWidth = 2 * dp
            line.pathEffect = dash
            canvas.drawCircle(px(s.x), py(s.y), itemPx(s.size) * 0.62f, line)
            line.pathEffect = null
        }
        // Placed items first, then the mess, then whatever's in your hand on top.
        for (it in r.items.sortedBy { if (it.placed) 0 else 1 }) {
            if (it === dragging) continue
            drawItem(canvas, it, now)
        }
        dragging?.let { d ->
            // A shadow under the lifted item.
            paint.color = 0x33000000
            val size = itemPx(d.size)
            canvas.drawOval(dragX - size * 0.4f, dragY + size * 0.45f, dragX + size * 0.4f, dragY + size * 0.6f, paint)
            painter.draw(canvas, d.type, dragX, dragY - 6 * dp, size * 1.15f)
        }
        drawSparkles(canvas)
        val busy = dragging != null || pops.isNotEmpty() || shakes.isNotEmpty() || sparkles.isNotEmpty() || hint != null
        if (busy) postInvalidateOnAnimation()
    }

    private fun drawItem(canvas: Canvas, item: Item, now: Long) {
        var scale = 1f
        var dx = 0f
        pops[item.id]?.let { start ->
            val k = (now - start) / 380f
            if (k >= 1f) pops.remove(item.id) else scale = 1f + 0.35f * sin(k * Math.PI.toFloat()) * (1 - k)
        }
        shakes[item.id]?.let { start ->
            val k = (now - start) / 420f
            if (k >= 1f) shakes.remove(item.id) else dx = sin(k * 40f) * (1 - k) * 8 * dp
        }
        val x = px(item.x) + dx
        val y = py(item.y)
        val size = itemPx(item.size)
        if (!item.placed) {
            paint.color = 0x22000000
            canvas.drawOval(x - size * 0.4f, y + size * 0.38f, x + size * 0.4f, y + size * 0.52f, paint)
        }
        canvas.save()
        if (!item.placed) canvas.rotate(item.tilt, x, y)
        if (hint?.first == item.id) {
            paint.color = 0x55FFC107
            canvas.drawCircle(x, y, size * (0.65f + 0.08f * sin(now / 120f)), paint)
        }
        painter.draw(canvas, item.type, x, y, size * scale)
        canvas.restore()
    }

    // ---------------------------------------------------------------- the room

    private fun drawRoom(canvas: Canvas, kind: RoomKind) {
        val w = width.toFloat()
        val h = height.toFloat()
        val (wallTop, wallBottom, floor) = when (kind) {
            RoomKind.BEDROOM -> Triple(0xFFF8BBD0.toInt(), 0xFFFCE4EC.toInt(), 0xFFD7A86E.toInt())
            RoomKind.KITCHEN -> Triple(0xFFB2EBF2.toInt(), 0xFFE0F7FA.toInt(), 0xFFECEFF1.toInt())
            RoomKind.BATHROOM -> Triple(0xFFB3E5FC.toInt(), 0xFFE1F5FE.toInt(), 0xFFCFD8DC.toInt())
            RoomKind.LIVING -> Triple(0xFFFFE0B2.toInt(), 0xFFFFF3E0.toInt(), 0xFFA1887F.toInt())
            RoomKind.PLAYROOM -> Triple(0xFFC8E6C9.toInt(), 0xFFE8F5E9.toInt(), 0xFF90CAF9.toInt())
        }
        paint.shader = LinearGradient(0f, 0f, 0f, h * 0.62f, wallTop, wallBottom, Shader.TileMode.CLAMP)
        canvas.drawRect(0f, 0f, w, h * 0.62f, paint)
        paint.shader = null
        paint.color = floor
        canvas.drawRect(0f, h * 0.62f, w, h, paint)
        // Floor boards / tiles.
        line.color = 0x22000000
        line.strokeWidth = 2 * dp
        if (kind == RoomKind.KITCHEN || kind == RoomKind.BATHROOM) {
            var x = 0f
            while (x < w) { canvas.drawLine(x, h * 0.62f, x, h, line); x += w / 8 }
            var y = h * 0.62f
            while (y < h) { canvas.drawLine(0f, y, w, y, line); y += w / 8 }
        } else {
            var y = h * 0.62f
            while (y < h) { canvas.drawLine(0f, y, w, y, line); y += h * 0.045f }
        }
        // Skirting board.
        paint.color = 0xFFFFFFFF.toInt()
        canvas.drawRect(0f, h * 0.605f, w, h * 0.625f, paint)
        // Rug in the middle of the floor.
        paint.color = 0x33FFFFFF
        canvas.drawOval(w * 0.12f, h * 0.76f, w * 0.88f, h * 0.97f, paint)

        // Wall shelf under the top row.
        plank(canvas, 0.06f, if (kind == RoomKind.LIVING) 0.54f else 0.6f, 0.258f, 0xFF8D6E63.toInt())
        when (kind) {
            RoomKind.BEDROOM -> {
                window(canvas, 0.74f, 0.07f, 0.94f, 0.30f)
                // Bed.
                box(canvas, 0.50f, 0.36f, 0.94f, 0.50f, 0xFF8D6E63.toInt())
                box(canvas, 0.50f, 0.50f, 0.94f, 0.60f, 0xFFFFFFFF.toInt())
                box(canvas, 0.50f, 0.53f, 0.94f, 0.62f, 0xFF7986CB.toInt())
                // Bedside table.
                box(canvas, 0.10f, 0.50f, 0.38f, 0.62f, 0xFFBCAAA4.toInt())
                box(canvas, 0.08f, 0.49f, 0.40f, 0.51f, 0xFF8D6E63.toInt())
            }
            RoomKind.KITCHEN -> {
                window(canvas, 0.66f, 0.06f, 0.76f, 0.30f)
                // Counter with cupboards.
                box(canvas, 0.04f, 0.50f, 0.96f, 0.62f, 0xFFFFFFFF.toInt())
                box(canvas, 0.03f, 0.49f, 0.97f, 0.51f, 0xFF607D8B.toInt())
                for (i in 0 until 4) {
                    val x0 = 0.06f + i * 0.225f
                    rect.set(px(x0), py(0.52f), px(x0 + 0.2f), py(0.60f))
                    line.color = 0x33000000
                    canvas.drawRect(rect, line)
                    paint.color = 0xFF90A4AE.toInt()
                    canvas.drawRect(px(x0 + 0.08f), py(0.53f), px(x0 + 0.12f), py(0.54f), paint)
                }
            }
            RoomKind.BATHROOM -> {
                // Mirror, sink unit and bath.
                box(canvas, 0.06f, 0.50f, 0.42f, 0.62f, 0xFFFFFFFF.toInt())
                box(canvas, 0.05f, 0.49f, 0.43f, 0.51f, 0xFF90A4AE.toInt())
                box(canvas, 0.54f, 0.49f, 0.86f, 0.505f, 0xFF90A4AE.toInt())
                paint.color = 0xFFFFFFFF.toInt()
                rect.set(px(0.56f), py(0.58f), px(0.97f), py(0.68f))
                canvas.drawRoundRect(rect, 24 * dp, 24 * dp, paint)
                paint.color = 0xFF81D4FA.toInt()
                rect.set(px(0.59f), py(0.59f), px(0.94f), py(0.63f))
                canvas.drawRoundRect(rect, 14 * dp, 14 * dp, paint)
            }
            RoomKind.LIVING -> {
                window(canvas, 0.57f, 0.06f, 0.65f, 0.30f)
                // Sofa.
                box(canvas, 0.46f, 0.40f, 0.96f, 0.56f, 0xFF7E57C2.toInt())
                box(canvas, 0.44f, 0.52f, 0.98f, 0.62f, 0xFF673AB7.toInt())
                // TV table.
                box(canvas, 0.08f, 0.50f, 0.40f, 0.62f, 0xFF6D4C41.toInt())
                box(canvas, 0.12f, 0.33f, 0.36f, 0.45f, 0xFF263238.toInt())
                box(canvas, 0.135f, 0.345f, 0.345f, 0.435f, 0xFF4FC3F7.toInt())
            }
            RoomKind.PLAYROOM -> {
                // Stars on the wall.
                paint.color = 0x55FFFFFF
                for (i in 0 until 10) canvas.drawCircle(px((i * 37 % 100) / 100f), py(0.04f + (i * 53 % 100) / 100f * 0.16f), 5 * dp, paint)
                // Toy table and a bean bag.
                box(canvas, 0.08f, 0.51f, 0.52f, 0.62f, 0xFFFFB74D.toInt())
                box(canvas, 0.07f, 0.50f, 0.53f, 0.52f, 0xFFEF6C00.toInt())
                paint.color = 0xFFEF5350.toInt()
                canvas.drawOval(px(0.58f), py(0.50f), px(0.96f), py(0.64f), paint)
            }
        }
    }

    private fun plank(canvas: Canvas, left: Float, right: Float, y: Float, color: Int) {
        rect.set(px(left), py(y), px(right), py(y) + 10 * dp)
        paint.color = color
        canvas.drawRoundRect(rect, 3 * dp, 3 * dp, paint)
        paint.color = 0x22000000
        canvas.drawRect(px(left) + 8 * dp, py(y) + 10 * dp, px(right) - 8 * dp, py(y) + 16 * dp, paint)
    }

    private fun box(canvas: Canvas, l: Float, t: Float, r: Float, b: Float, color: Int) {
        rect.set(px(l), py(t), px(r), py(b))
        paint.color = color
        canvas.drawRoundRect(rect, 6 * dp, 6 * dp, paint)
    }

    private fun window(canvas: Canvas, l: Float, t: Float, r: Float, b: Float) {
        rect.set(px(l), py(t), px(r), py(b))
        paint.color = 0xFFFFFFFF.toInt()
        canvas.drawRoundRect(rect, 6 * dp, 6 * dp, paint)
        rect.inset(6 * dp, 6 * dp)
        paint.color = 0xFF81D4FA.toInt()
        canvas.drawRect(rect, paint)
        paint.color = 0xFFFFFFFF.toInt()
        canvas.drawRect(rect.centerX() - 2 * dp, rect.top, rect.centerX() + 2 * dp, rect.bottom, paint)
        canvas.drawRect(rect.left, rect.centerY() - 2 * dp, rect.right, rect.centerY() + 2 * dp, paint)
    }

    // ---------------------------------------------------------------- effects

    private fun sparkle(x: Float, y: Float, count: Int) {
        val colors = intArrayOf(0xFFFFEB3B.toInt(), 0xFFFFFFFF.toInt(), 0xFF80DEEA.toInt(), 0xFFF48FB1.toInt())
        repeat(count) {
            val a = random.nextFloat() * 6.283f
            val v = (60 + random.nextFloat() * 200) * dp
            sparkles += Sparkle(x, y, kotlin.math.cos(a) * v, sin(a) * v - 60 * dp, 0.5f + random.nextFloat() * 0.5f, colors[it % colors.size])
        }
    }

    private var lastFrame = 0L

    private fun drawSparkles(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        val dt = if (lastFrame == 0L) 0.016f else ((now - lastFrame) / 1000f).coerceIn(0f, 0.05f)
        lastFrame = now
        val it = sparkles.iterator()
        while (it.hasNext()) {
            val s = it.next()
            s.life -= dt
            if (s.life <= 0f) {
                it.remove()
                continue
            }
            s.x += s.vx * dt
            s.y += s.vy * dt
            s.vy += 260 * dp * dt
            paint.color = s.color
            paint.alpha = (255 * min(1f, s.life * 2)).toInt()
            val r = 3.5f * dp
            canvas.drawRect(s.x - r, s.y - r * 0.3f, s.x + r, s.y + r * 0.3f, paint)
            canvas.drawRect(s.x - r * 0.3f, s.y - r, s.x + r * 0.3f, s.y + r, paint)
            paint.alpha = 255
        }
    }

    /** Sparkles all over the room when it's tidy. */
    fun celebrate() {
        val r = room ?: return
        for (s in r.slots) sparkle(px(s.x), py(s.y), 10)
        invalidate()
    }

    // ---------------------------------------------------------------- touch

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val r = room ?: return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                // Pick up the nearest loose item under the finger (the top one first).
                val loose = r.items.filter { !it.placed }
                val hit = loose.lastOrNull { hypot(px(it.x) - event.x, py(it.y) - event.y) < itemPx(it.size) * 0.75f + 10 * dp }
                    ?: loose.minByOrNull { hypot(px(it.x) - event.x, py(it.y) - event.y) }?.takeIf { hypot(px(it.x) - event.x, py(it.y) - event.y) < itemPx(it.size) * 1.1f }
                if (hit != null) {
                    dragging = hit
                    grabDx = px(hit.x) - event.x
                    grabDy = py(hit.y) - event.y
                    dragX = px(hit.x)
                    dragY = py(hit.y)
                    listener?.onPickedUp()
                    invalidate()
                }
            }
            MotionEvent.ACTION_MOVE -> dragging?.let {
                dragX = event.x + grabDx
                dragY = event.y + grabDy
                invalidate()
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val d = dragging ?: return true
                performClick()
                dragging = null
                val result = r.drop(d.id, dragX / width, (dragY - 6 * dp) / height)
                when (result) {
                    is DropResult.Placed -> {
                        pops[d.id] = SystemClock.uptimeMillis()
                        sparkle(px(result.slot.x), py(result.slot.y), 16)
                        if (hint?.first == d.id) hint = null
                    }
                    is DropResult.Missed -> if (result.wrongSlot != null) shakes[d.id] = SystemClock.uptimeMillis()
                }
                listener?.onDropped(result)
                if (r.tidy) listener?.onTidy()
                invalidate()
            }
        }
        return true
    }

    override fun performClick(): Boolean = super.performClick()
}
