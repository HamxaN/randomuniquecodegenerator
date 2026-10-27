package com.hamxanadeem.penguinslide.ui

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import com.hamxanadeem.penguinslide.core.Hat
import com.hamxanadeem.penguinslide.core.Skin
import kotlin.math.sin

/**
 * Draws the penguin belly-sliding to the right, made entirely of shapes. Its belly
 * touches y = 0 in local coordinates, so callers translate to the contact point and
 * rotate to the slope.
 */
class PenguinPainter {

    enum class Mood { HAPPY, FOCUSED, DIZZY }

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val path = Path()
    private val oval = RectF()

    /**
     * [size] is the body length in pixels, [flap] 0..1 lifts the flippers and
     * [squash] > 1 flattens the body (diving).
     */
    fun draw(canvas: Canvas, size: Float, skin: Skin, time: Float, flap: Float, squash: Float, mood: Mood) {
        val s = size
        val h = s * 0.55f / squash
        val w = s * squash.coerceAtMost(1.15f)
        val cy = -h / 2f

        // Feet trailing behind.
        paint.style = Paint.Style.FILL
        paint.color = FEET
        oval.set(-w * 0.62f, cy - h * 0.05f, -w * 0.38f, cy + h * 0.25f)
        canvas.drawOval(oval, paint)
        oval.set(-w * 0.6f, cy + h * 0.1f, -w * 0.36f, cy + h * 0.42f)
        canvas.drawOval(oval, paint)

        // Back flipper (behind the body).
        drawFlipper(canvas, -w * 0.02f, cy - h * 0.2f, w, h, -flap, DARK_SHADE)

        // Body and white belly.
        paint.color = BODY
        oval.set(-w / 2f, cy - h / 2f, w / 2f, cy + h / 2f)
        canvas.drawOval(oval, paint)
        paint.color = BELLY
        oval.set(-w * 0.42f, cy - h * 0.05f, w * 0.38f, cy + h * 0.48f)
        canvas.drawOval(oval, paint)
        // White face patch.
        oval.set(w * 0.18f, cy - h * 0.38f, w * 0.48f, cy + h * 0.15f)
        canvas.drawOval(oval, paint)
        // Shine on the back.
        paint.color = 0x33FFFFFF
        oval.set(-w * 0.3f, cy - h * 0.46f, w * 0.15f, cy - h * 0.28f)
        canvas.drawOval(oval, paint)

        // Scarf around the neck with a tail streaming behind.
        paint.color = skin.scarf.toInt()
        val sx = w * 0.12f
        canvas.drawRect(sx - w * 0.05f, cy - h * 0.5f, sx + w * 0.05f, cy + h * 0.42f, paint)
        val wave = sin(time * 18f) * h * 0.12f
        path.reset()
        path.moveTo(sx, cy - h * 0.42f)
        path.quadTo(sx - w * 0.25f, cy - h * 0.62f + wave, sx - w * 0.48f, cy - h * 0.55f - wave)
        path.lineTo(sx - w * 0.45f, cy - h * 0.38f - wave)
        path.quadTo(sx - w * 0.22f, cy - h * 0.42f + wave, sx, cy - h * 0.25f)
        path.close()
        canvas.drawPath(path, paint)

        // Front flipper.
        drawFlipper(canvas, w * 0.02f, cy + h * 0.05f, w, h, flap, BODY)

        // Beak.
        paint.color = FEET
        path.reset()
        path.moveTo(w * 0.46f, cy - h * 0.14f)
        path.lineTo(w * 0.66f, cy - h * 0.04f)
        path.lineTo(w * 0.46f, cy + h * 0.04f)
        path.close()
        canvas.drawPath(path, paint)

        // Eye.
        val ex = w * 0.36f
        val ey = cy - h * 0.18f
        when (mood) {
            Mood.DIZZY -> {
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = s * 0.025f
                paint.color = BODY
                val r = h * 0.09f
                canvas.drawLine(ex - r, ey - r, ex + r, ey + r, paint)
                canvas.drawLine(ex - r, ey + r, ex + r, ey - r, paint)
                paint.style = Paint.Style.FILL
            }
            else -> {
                val blink = (time % 3.2f) > 3.05f
                paint.color = 0xFFFFFFFF.toInt()
                if (blink) {
                    canvas.drawRect(ex - h * 0.1f, ey - h * 0.015f, ex + h * 0.1f, ey + h * 0.015f, paint)
                } else {
                    canvas.drawCircle(ex, ey, h * 0.11f, paint)
                    paint.color = BODY
                    val look = if (mood == Mood.FOCUSED) h * 0.04f else h * 0.02f
                    canvas.drawCircle(ex + look, ey, h * 0.065f, paint)
                    paint.color = 0xFFFFFFFF.toInt()
                    canvas.drawCircle(ex + look + h * 0.025f, ey - h * 0.025f, h * 0.022f, paint)
                }
                // Rosy cheek.
                paint.color = 0x55FF8A80
                canvas.drawCircle(ex - h * 0.02f, ey + h * 0.16f, h * 0.06f, paint)
            }
        }

        drawHat(canvas, skin, w, h, cy, time)
    }

    private fun drawFlipper(canvas: Canvas, x: Float, y: Float, w: Float, h: Float, flap: Float, color: Int) {
        val save = canvas.save()
        canvas.rotate(-25f - 55f * flap, x, y)
        paint.color = color
        oval.set(x - w * 0.32f, y - h * 0.1f, x + w * 0.02f, y + h * 0.12f)
        canvas.drawOval(oval, paint)
        canvas.restoreToCount(save)
    }

    private fun drawHat(canvas: Canvas, skin: Skin, w: Float, h: Float, cy: Float, time: Float) {
        val color = skin.hatColor.toInt()
        val hx = w * 0.3f
        val top = cy - h * 0.48f
        paint.style = Paint.Style.FILL
        when (skin.hat) {
            Hat.NONE -> Unit
            Hat.BEANIE -> {
                paint.color = color
                oval.set(hx - w * 0.2f, top - h * 0.3f, hx + w * 0.2f, top + h * 0.22f)
                canvas.drawArc(oval, 180f, 180f, true, paint)
                paint.color = 0xFFFFFFFF.toInt()
                canvas.drawRect(hx - w * 0.21f, top - h * 0.06f, hx + w * 0.21f, top + h * 0.06f, paint)
                canvas.drawCircle(hx, top - h * 0.3f, h * 0.09f, paint)
            }
            Hat.TOP_HAT -> {
                paint.color = color
                canvas.drawRect(hx - w * 0.2f, top - h * 0.04f, hx + w * 0.2f, top + h * 0.04f, paint)
                canvas.drawRect(hx - w * 0.12f, top - h * 0.5f, hx + w * 0.12f, top, paint)
                paint.color = skin.scarf.toInt()
                canvas.drawRect(hx - w * 0.12f, top - h * 0.12f, hx + w * 0.12f, top - h * 0.04f, paint)
            }
            Hat.CROWN -> {
                paint.color = color
                path.reset()
                path.moveTo(hx - w * 0.16f, top + h * 0.02f)
                path.lineTo(hx - w * 0.18f, top - h * 0.32f)
                path.lineTo(hx - w * 0.07f, top - h * 0.16f)
                path.lineTo(hx, top - h * 0.38f)
                path.lineTo(hx + w * 0.07f, top - h * 0.16f)
                path.lineTo(hx + w * 0.18f, top - h * 0.32f)
                path.lineTo(hx + w * 0.16f, top + h * 0.02f)
                path.close()
                canvas.drawPath(path, paint)
                paint.color = 0xFFE53935.toInt()
                canvas.drawCircle(hx, top - h * 0.08f, h * 0.05f, paint)
            }
            Hat.HEADPHONES -> {
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = h * 0.07f
                paint.color = color
                oval.set(hx - w * 0.2f, top - h * 0.25f, hx + w * 0.2f, top + h * 0.35f)
                canvas.drawArc(oval, 180f, 180f, false, paint)
                paint.style = Paint.Style.FILL
                paint.color = skin.scarf.toInt()
                canvas.drawCircle(hx + w * 0.02f, top + h * 0.18f, h * 0.13f, paint)
            }
            Hat.PARTY -> {
                paint.color = color
                val tilt = sin(time * 6f) * w * 0.02f
                path.reset()
                path.moveTo(hx - w * 0.13f, top + h * 0.04f)
                path.lineTo(hx + tilt, top - h * 0.55f)
                path.lineTo(hx + w * 0.13f, top + h * 0.04f)
                path.close()
                canvas.drawPath(path, paint)
                paint.color = skin.scarf.toInt()
                canvas.drawCircle(hx + tilt, top - h * 0.55f, h * 0.08f, paint)
            }
        }
    }

    private companion object {
        const val BODY = 0xFF1F2A44.toInt()
        const val DARK_SHADE = 0xFF141C30.toInt()
        const val BELLY = 0xFFFDFDFD.toInt()
        const val FEET = 0xFFFF9800.toInt()
    }
}
