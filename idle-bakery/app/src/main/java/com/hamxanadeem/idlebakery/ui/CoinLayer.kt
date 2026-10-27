package com.hamxanadeem.idlebakery.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.os.SystemClock
import android.util.AttributeSet
import android.view.View
import kotlin.math.min

/** Gold coins that fly from a pastry up to the money counter. Draws over everything. */
class CoinLayer @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    /** Called each time a coin lands, to bump the counter. */
    var onLanded: (() -> Unit)? = null

    private val dp = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val sx = FloatArray(MAX)
    private val sy = FloatArray(MAX)
    private val tx = FloatArray(MAX)
    private val ty = FloatArray(MAX)
    private val start = LongArray(MAX)
    private var count = 0
    private val origin = IntArray(2)

    /** Window coordinates in, converted to this view's coordinates. */
    fun launch(fromX: Int, fromY: Int, toX: Int, toY: Int, coins: Int) {
        getLocationInWindow(origin)
        val now = SystemClock.uptimeMillis()
        repeat(coins) {
            if (count >= MAX) return
            val i = count++
            sx[i] = (fromX - origin[0]).toFloat() + (it - coins / 2f) * 6 * dp
            sy[i] = (fromY - origin[1]).toFloat()
            tx[i] = (toX - origin[0]).toFloat()
            ty[i] = (toY - origin[1]).toFloat()
            start[i] = now + it * 60L
        }
        postInvalidateOnAnimation()
    }

    override fun onDraw(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        var i = 0
        while (i < count) {
            val t = (now - start[i]) / FLIGHT.toFloat()
            if (t >= 1f) {
                count--
                sx[i] = sx[count]; sy[i] = sy[count]; tx[i] = tx[count]; ty[i] = ty[count]; start[i] = start[count]
                onLanded?.invoke()
                continue
            }
            if (t >= 0f) {
                // Quadratic curve that bows out sideways.
                val e = t * t * (3 - 2 * t)
                val cx = sx[i] + 80 * dp
                val cy = (sy[i] + ty[i]) / 2
                val x = (1 - e) * (1 - e) * sx[i] + 2 * (1 - e) * e * cx + e * e * tx[i]
                val y = (1 - e) * (1 - e) * sy[i] + 2 * (1 - e) * e * cy + e * e * ty[i]
                val r = 9 * dp * (1f - 0.3f * e)
                paint.color = 0xFFC88A12.toInt()
                canvas.drawCircle(x, y + 1.5f * dp, r, paint)
                paint.color = 0xFFFFC928.toInt()
                canvas.drawCircle(x, y, r, paint)
                paint.color = 0xFFFFE57F.toInt()
                canvas.drawCircle(x, y, r * 0.62f, paint)
                paint.color = 0xCCFFFFFF.toInt()
                canvas.drawCircle(x - r * 0.3f, y - r * 0.3f, min(r * 0.2f, 3 * dp), paint)
            }
            i++
        }
        if (count > 0) postInvalidateOnAnimation()
    }

    private companion object {
        const val MAX = 120
        const val FLIGHT = 650L
    }
}
