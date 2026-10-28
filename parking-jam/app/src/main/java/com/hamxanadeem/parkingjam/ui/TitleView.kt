package com.hamxanadeem.parkingjam.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.SystemClock
import android.util.AttributeSet
import android.view.View
import com.hamxanadeem.parkingjam.core.LotGenerator
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/** Menu backdrop: sky, a roundabout with cars driving round it, and a bouncy title. */
class TitleView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    private val dp = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val black = Typeface.create("sans-serif-black", Typeface.NORMAL)
    private val title = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = black; textAlign = Paint.Align.CENTER }
    private val outline = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = black
        textAlign = Paint.Align.CENTER
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
        color = 0xFF0D47A1.toInt()
    }
    private val rect = RectF()
    private var sky: Shader? = null
    private var logo: Shader? = null

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        sky = LinearGradient(0f, 0f, 0f, h * 0.5f, 0xFF4FC3F7.toInt(), 0xFFB3E5FC.toInt(), Shader.TileMode.CLAMP)
        val size = min(w / 7.5f, 64 * dp)
        title.textSize = size
        outline.textSize = size
        outline.strokeWidth = size * 0.18f
        logo = LinearGradient(0f, h * 0.18f - size, 0f, h * 0.18f + size * 1.2f, 0xFFFFF176.toInt(), 0xFFFF8F00.toInt(), Shader.TileMode.CLAMP)
    }

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        val t = SystemClock.uptimeMillis() / 1000f
        paint.shader = sky
        canvas.drawRect(0f, 0f, w, h * 0.5f, paint)
        paint.shader = null
        // Clouds.
        paint.color = 0xE6FFFFFF.toInt()
        for (i in 0 until 4) {
            val x = ((i * 0.31f + t * 0.02f * (1 + i % 2)) % 1.2f - 0.1f) * w
            val y = h * (0.06f + i * 0.07f)
            canvas.drawCircle(x, y, 22 * dp, paint)
            canvas.drawCircle(x + 22 * dp, y - 8 * dp, 28 * dp, paint)
            canvas.drawCircle(x + 46 * dp, y, 20 * dp, paint)
        }
        // Grass and the roundabout.
        paint.color = 0xFF7CB342.toInt()
        canvas.drawRect(0f, h * 0.45f, w, h, paint)
        val cx = w / 2
        val cy = h * 0.66f
        val r = min(w, h) * 0.32f
        paint.color = 0xFF546E7A.toInt()
        canvas.drawCircle(cx, cy, r + 26 * dp, paint)
        paint.color = 0xFF8BC34A.toInt()
        canvas.drawCircle(cx, cy, r - 26 * dp, paint)
        stroke.color = 0xFFFFEE58.toInt()
        stroke.strokeWidth = 3 * dp
        stroke.pathEffect = android.graphics.DashPathEffect(floatArrayOf(14 * dp, 12 * dp), t * 30 * dp)
        canvas.drawCircle(cx, cy, r, stroke)
        stroke.pathEffect = null
        // A tree in the middle.
        paint.color = 0xFF5D4037.toInt()
        canvas.drawRect(cx - 6 * dp, cy - 4 * dp, cx + 6 * dp, cy + 24 * dp, paint)
        paint.color = 0xFF2E7D32.toInt()
        canvas.drawCircle(cx, cy - 16 * dp, 30 * dp, paint)
        paint.color = 0xFF43A047.toInt()
        canvas.drawCircle(cx - 10 * dp, cy - 24 * dp, 18 * dp, paint)

        // Cars going round.
        for (i in 0 until 6) {
            val a = t * 0.6f + i * (Math.PI.toFloat() * 2 / 6)
            val x = cx + cos(a) * r
            val y = cy + sin(a) * r
            canvas.save()
            canvas.rotate(Math.toDegrees(a.toDouble()).toFloat() + 90f, x, y)
            car(canvas, x, y, LotGenerator.COLORS[i])
            canvas.restore()
        }

        // Title, bouncing gently.
        val bounce = sin(t * 3f) * 4 * dp
        val y1 = h * 0.18f + bounce
        val y2 = y1 + title.textSize * 1.05f
        title.shader = logo
        for ((line, y) in listOf("CAR PARKING" to y1, "JAM!" to y2)) {
            canvas.drawText(line, cx, y, outline)
            canvas.drawText(line, cx, y, title)
        }
        title.shader = null
        postInvalidateOnAnimation()
    }

    /** A small car seen from above, facing right before rotation. */
    private fun car(canvas: Canvas, x: Float, y: Float, color: Int) {
        val len = 22 * dp
        val wid = 12 * dp
        paint.color = 0x44000000
        rect.set(x - len + 2 * dp, y - wid + 3 * dp, x + len + 2 * dp, y + wid + 3 * dp)
        canvas.drawRoundRect(rect, wid * 0.6f, wid * 0.6f, paint)
        paint.color = color
        rect.set(x - len, y - wid, x + len, y + wid)
        canvas.drawRoundRect(rect, wid * 0.6f, wid * 0.6f, paint)
        paint.color = 0xFF90CAF9.toInt()
        rect.set(x - len * 0.4f, y - wid * 0.65f, x + len * 0.45f, y + wid * 0.65f)
        canvas.drawRoundRect(rect, wid * 0.35f, wid * 0.35f, paint)
        paint.color = color
        rect.set(x - len * 0.25f, y - wid * 0.55f, x + len * 0.2f, y + wid * 0.55f)
        canvas.drawRoundRect(rect, wid * 0.25f, wid * 0.25f, paint)
        paint.color = 0xFFFFF59D.toInt()
        canvas.drawCircle(x + len * 0.88f, y - wid * 0.55f, wid * 0.16f, paint)
        canvas.drawCircle(x + len * 0.88f, y + wid * 0.55f, wid * 0.16f, paint)
    }
}
