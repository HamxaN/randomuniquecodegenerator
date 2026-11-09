package com.hamxanadeem.spendwise.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import androidx.core.content.ContextCompat
import com.hamxanadeem.spendwise.R

private fun Context.color(id: Int) = ContextCompat.getColor(this, id)

/** A ring of category slices with a total in the middle. */
class DonutView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private var slices: List<Pair<Int, Long>> = emptyList()
    private var title = ""
    private var subtitle = ""
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.BUTT }
    private val big = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER; isFakeBoldText = true; color = context.color(R.color.ink) }
    private val small = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER; color = context.color(R.color.ink_soft) }
    private val box = RectF()

    fun set(slices: List<Pair<Int, Long>>, title: String, subtitle: String) {
        this.slices = slices.filter { it.second > 0 }
        this.title = title
        this.subtitle = subtitle
        contentDescription = "$subtitle $title"
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val w = MeasureSpec.getSize(widthMeasureSpec)
        val h = minOf(w, Ui.dp(context, 200))
        setMeasuredDimension(w, h)
    }

    override fun onDraw(canvas: Canvas) {
        val size = minOf(width, height).toFloat()
        val stroke = size * 0.14f
        ring.strokeWidth = stroke
        val r = (size - stroke) / 2f
        val cx = width / 2f
        val cy = height / 2f
        box.set(cx - r, cy - r, cx + r, cy + r)
        val total = slices.sumOf { it.second }.toFloat()
        if (total <= 0f) {
            ring.color = context.color(R.color.track)
            canvas.drawArc(box, 0f, 360f, false, ring)
        } else {
            var start = -90f
            val gap = if (slices.size > 1) 1.5f else 0f
            for ((c, v) in slices) {
                val sweep = v / total * 360f
                ring.color = c
                canvas.drawArc(box, start + gap / 2, (sweep - gap).coerceAtLeast(0.5f), false, ring)
                start += sweep
            }
        }
        big.textSize = size * 0.12f
        small.textSize = size * 0.065f
        canvas.drawText(title, cx, cy + big.textSize * 0.15f, big)
        canvas.drawText(subtitle, cx, cy + big.textSize * 0.15f + small.textSize * 1.6f, small)
    }
}

/** One bar per day of the month; today's bar is highlighted and the daily budget pace is a dashed line. */
class DailyBarsView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private var values = LongArray(0)
    private var highlight = -1
    private var pace = 0L
    private val bar = Paint(Paint.ANTI_ALIAS_FLAG)
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = context.color(R.color.warning)
        pathEffect = android.graphics.DashPathEffect(floatArrayOf(12f, 8f), 0f)
    }
    private val label = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.color(R.color.ink_soft); textAlign = Paint.Align.CENTER }
    private val rect = RectF()

    fun set(values: LongArray, highlight: Int, pace: Long) {
        this.values = values
        this.highlight = highlight
        this.pace = pace
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), Ui.dp(context, 140))
    }

    override fun onDraw(canvas: Canvas) {
        if (values.isEmpty()) return
        label.textSize = Ui.dp(context, 10).toFloat()
        line.strokeWidth = Ui.dp(context, 1).toFloat() * 1.5f
        val bottom = height - label.textSize * 1.6f
        val top = Ui.dp(context, 6).toFloat()
        val max = maxOf(values.max(), pace, 1L).toFloat()
        val slot = width.toFloat() / values.size
        val w = slot * 0.62f
        val radius = w / 3f
        for (i in values.indices) {
            val h = (bottom - top) * values[i] / max
            val x = i * slot + (slot - w) / 2
            rect.set(x, bottom - maxOf(h, if (values[i] > 0) 3f else 1.5f), x + w, bottom)
            bar.color = context.color(
                when {
                    i == highlight -> R.color.brand
                    i > highlight && highlight >= 0 -> R.color.track
                    else -> R.color.brand_soft
                }
            )
            canvas.drawRoundRect(rect, radius, radius, bar)
            if (i == 0 || (i + 1) % 5 == 0) canvas.drawText("${i + 1}", x + w / 2, height - label.textSize * 0.3f, label)
        }
        if (pace > 0) {
            val y = bottom - (bottom - top) * pace / max
            canvas.drawLine(0f, y, width.toFloat(), y, line)
        }
    }
}

/** Income and spending side by side for the last few months. */
class TrendView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private var data: List<Triple<String, Long, Long>> = emptyList()
    private val income = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.color(R.color.income) }
    private val expense = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.color(R.color.expense) }
    private val label = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.color(R.color.ink_soft); textAlign = Paint.Align.CENTER }
    private val rect = RectF()

    fun set(data: List<Triple<String, Long, Long>>) {
        this.data = data
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), Ui.dp(context, 160))
    }

    override fun onDraw(canvas: Canvas) {
        if (data.isEmpty()) return
        label.textSize = Ui.dp(context, 11).toFloat()
        val bottom = height - label.textSize * 1.8f
        val top = Ui.dp(context, 6).toFloat()
        val max = maxOf(data.maxOf { maxOf(it.second, it.third) }, 1L).toFloat()
        val slot = width.toFloat() / data.size
        val w = slot * 0.26f
        val radius = w / 3f
        for ((i, d) in data.withIndex()) {
            val cx = i * slot + slot / 2
            val hi = (bottom - top) * d.second / max
            val he = (bottom - top) * d.third / max
            rect.set(cx - w - 2f, bottom - maxOf(hi, 1.5f), cx - 2f, bottom)
            canvas.drawRoundRect(rect, radius, radius, income)
            rect.set(cx + 2f, bottom - maxOf(he, 1.5f), cx + w + 2f, bottom)
            canvas.drawRoundRect(rect, radius, radius, expense)
            canvas.drawText(d.first, cx, height - label.textSize * 0.4f, label)
        }
    }
}

/** A slim rounded progress bar that turns amber then red as a budget fills. */
class BudgetBarView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private var fraction = 0.0
    private var marker = -1.0
    private var colorRes = R.color.brand
    private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.color(R.color.track) }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val tick = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.color(R.color.ink_soft) }
    private val rect = RectF()

    /** [marker] is how far through the month we are, drawn as a tick (or <0 for none). */
    fun set(fraction: Double, colorRes: Int, marker: Double = -1.0) {
        this.fraction = fraction
        this.colorRes = colorRes
        this.marker = marker
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), Ui.dp(context, 10))
    }

    override fun onDraw(canvas: Canvas) {
        val r = height / 2f
        rect.set(0f, 0f, width.toFloat(), height.toFloat())
        canvas.drawRoundRect(rect, r, r, track)
        val f = fraction.coerceIn(0.0, 1.0).toFloat()
        if (f > 0f) {
            fill.color = context.color(colorRes)
            rect.set(0f, 0f, maxOf(width * f, height.toFloat()), height.toFloat())
            canvas.drawRoundRect(rect, r, r, fill)
        }
        if (marker in 0.0..1.0) {
            val x = (width * marker).toFloat()
            canvas.drawRect(x - 1.5f, 0f, x + 1.5f, height.toFloat(), tick)
        }
    }
}
