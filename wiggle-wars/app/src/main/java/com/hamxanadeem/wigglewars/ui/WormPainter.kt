package com.hamxanadeem.wigglewars.ui

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import com.hamxanadeem.wigglewars.core.Weapon
import com.hamxanadeem.wigglewars.core.Worm
import kotlin.math.cos
import kotlin.math.sin

/** Draws a worm in world units: a pink body, googly eyes, team headband and weapon. */
class WormPainter {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val path = Path()
    private val oval = RectF()

    fun draw(canvas: Canvas, w: Worm, team: Int, time: Float, active: Boolean, weapon: Weapon?, hurtFlash: Boolean) {
        val r = Worm.RADIUS.toFloat()
        val x = w.x.toFloat()
        val y = w.y.toFloat()
        val f = w.facing.toFloat()
        val wiggle = if (w.onGround) sin(time * 6f + w.id) * 0.6f else 0f
        val body = if (hurtFlash) 0xFFFFFFFF.toInt() else BODY

        // Tail curling on the ground behind.
        paint.style = Paint.Style.FILL
        paint.color = BODY_DARK
        oval.set(x - f * r * 1.6f - r * 0.7f, y + r * 0.3f, x - f * r * 1.6f + r * 0.7f, y + r)
        canvas.drawOval(oval, paint)
        paint.color = body
        oval.set(x - f * r * 1.4f - r * 0.9f, y + r * 0.1f, x + r * 0.6f, y + r * 1.02f)
        canvas.drawOval(oval, paint)

        // Upright body and head.
        oval.set(x - r * 0.8f + wiggle, y - r * 1.5f, x + r * 0.8f + wiggle, y + r)
        canvas.drawOval(oval, paint)
        // Belly rings.
        paint.color = BODY_DARK
        paint.strokeWidth = 0.5f
        paint.style = Paint.Style.STROKE
        for (i in 0..2) {
            val ry = y + r * (0.55f - i * 0.38f)
            canvas.drawLine(x - r * 0.6f + wiggle, ry, x + r * 0.6f + wiggle, ry, paint)
        }
        paint.style = Paint.Style.FILL

        // Team headband with tails flapping.
        val hy = y - r * 1.05f
        paint.color = TeamColors.colors[team]
        canvas.drawRect(x - r * 0.82f + wiggle, hy - r * 0.18f, x + r * 0.82f + wiggle, hy + r * 0.18f, paint)
        val flap = sin(time * 10f + w.id) * r * 0.25f
        path.reset()
        path.moveTo(x - f * r * 0.8f + wiggle, hy - r * 0.1f)
        path.lineTo(x - f * r * 1.7f + wiggle, hy - r * 0.35f + flap)
        path.lineTo(x - f * r * 1.6f + wiggle, hy + r * 0.15f + flap)
        path.close()
        canvas.drawPath(path, paint)

        // Googly eyes looking along the aim.
        val lookX = (if (active) cos(w.aim).toFloat() * f else f) * r * 0.12f
        val lookY = (if (active) sin(w.aim).toFloat() else 0f) * r * 0.12f
        for (side in intArrayOf(-1, 1)) {
            val ex = x + wiggle + side * r * 0.32f + f * r * 0.15f
            val ey = y - r * 0.6f
            paint.color = 0xFFFFFFFF.toInt()
            canvas.drawCircle(ex, ey, r * 0.3f, paint)
            paint.color = 0xFF111111.toInt()
            canvas.drawCircle(ex + lookX, ey + lookY, r * 0.14f, paint)
        }
        // Smile.
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 0.6f
        paint.color = BODY_DARK
        oval.set(x + wiggle - r * 0.3f + f * r * 0.15f, y - r * 0.45f, x + wiggle + r * 0.3f + f * r * 0.15f, y - r * 0.05f)
        canvas.drawArc(oval, 20f, 140f, false, paint)
        paint.style = Paint.Style.FILL

        if (active && weapon != null) drawWeapon(canvas, w, weapon, x + wiggle, y - r * 0.2f)
    }

    private fun drawWeapon(canvas: Canvas, w: Worm, weapon: Weapon, x: Float, y: Float) {
        val save = canvas.save()
        canvas.translate(x, y)
        val angle = Math.toDegrees(w.aim).toFloat()
        if (w.facing < 0) canvas.scale(-1f, 1f)
        canvas.rotate(angle)
        paint.style = Paint.Style.FILL
        when (weapon) {
            Weapon.BAZOOKA -> {
                paint.color = 0xFF556B2F.toInt()
                canvas.drawRoundRect(-4f, -2.2f, 13f, 2.2f, 1.5f, 1.5f, paint)
                paint.color = 0xFF333333.toInt()
                canvas.drawRect(11f, -2.6f, 14f, 2.6f, paint)
            }
            Weapon.SHOTGUN -> {
                paint.color = 0xFF5D4037.toInt()
                canvas.drawRect(-4f, -1.4f, 3f, 1.6f, paint)
                paint.color = 0xFF424242.toInt()
                canvas.drawRect(3f, -1.2f, 14f, 0.4f, paint)
                canvas.drawRect(3f, 0.4f, 14f, 1.4f, paint)
            }
            Weapon.BAT -> {
                paint.color = 0xFFA1887F.toInt()
                path.reset()
                path.moveTo(0f, -0.8f); path.lineTo(14f, -1.8f); path.lineTo(14f, 1.8f); path.lineTo(0f, 0.8f); path.close()
                canvas.drawPath(path, paint)
            }
            Weapon.GRENADE -> ball(canvas, 0xFF2E7D32.toInt())
            Weapon.CLUSTER -> ball(canvas, 0xFFC62828.toInt())
            Weapon.BANANA -> {
                paint.color = 0xFFFFEB3B.toInt()
                oval.set(4f, -4f, 12f, 4f)
                canvas.drawArc(oval, -90f, 180f, true, paint)
            }
            Weapon.DYNAMITE -> {
                paint.color = 0xFFD32F2F.toInt()
                canvas.drawRect(3f, -4f, 7f, 4f, paint)
            }
            Weapon.AIRSTRIKE -> {
                paint.color = 0xFF37474F.toInt()
                canvas.drawRect(3f, -3f, 9f, 3f, paint)
                paint.color = 0xFF90A4AE.toInt()
                canvas.drawRect(5f, -7f, 6f, -3f, paint)
            }
            Weapon.TELEPORT -> {
                paint.color = 0xFFAB47BC.toInt()
                canvas.drawCircle(7f, 0f, 2.5f, paint)
            }
            Weapon.MEGA_GRENADE -> ball(canvas, 0xFFFFC107.toInt())
            Weapon.HOMING, Weapon.DRILL, Weapon.MIRV, Weapon.NAPALM, Weapon.NUKE -> {
                // A launcher tube, coloured by what's loaded.
                paint.color = when (weapon) {
                    Weapon.HOMING -> 0xFF00838F.toInt()
                    Weapon.DRILL -> 0xFFE65100.toInt()
                    Weapon.MIRV -> 0xFF5E35B1.toInt()
                    Weapon.NAPALM -> 0xFFBF360C.toInt()
                    else -> 0xFF37474F.toInt()
                }
                canvas.drawRoundRect(-4f, -2.6f, 14f, 2.6f, 1.5f, 1.5f, paint)
                paint.color = if (weapon == Weapon.NUKE) 0xFFFFD600.toInt() else 0xFF263238.toInt()
                canvas.drawRect(12f, -3f, 15f, 3f, paint)
            }
            Weapon.MINE -> {
                paint.color = 0xFF546E7A.toInt()
                oval.set(3f, -3f, 11f, 5f)
                canvas.drawArc(oval, 180f, 180f, true, paint)
                paint.color = 0xFFFF1744.toInt()
                canvas.drawCircle(7f, -1.5f, 0.9f, paint)
            }
            Weapon.UZI -> {
                paint.color = 0xFF37474F.toInt()
                canvas.drawRect(-1f, -1.6f, 8f, 1.2f, paint)
                canvas.drawRect(8f, -1f, 11f, 0.2f, paint)
                canvas.drawRect(2f, 1.2f, 4f, 4.5f, paint)
            }
            Weapon.SNIPER -> {
                paint.color = 0xFF5D4037.toInt()
                canvas.drawRect(-5f, -1.2f, 2f, 1.6f, paint)
                paint.color = 0xFF263238.toInt()
                canvas.drawRect(2f, -0.7f, 19f, 0.7f, paint)
                canvas.drawRect(1f, -3.2f, 7f, -1.2f, paint)
            }
            Weapon.SHEEP -> {
                paint.color = 0xFFF5F5F5.toInt()
                canvas.drawCircle(7f, 0f, 3.5f, paint)
                paint.color = 0xFF212121.toInt()
                canvas.drawCircle(10.5f, -1f, 1.6f, paint)
            }
            Weapon.GIRDER -> {
                paint.color = 0xFFE67E22.toInt()
                canvas.drawRect(2f, -1.8f, 14f, 1.8f, paint)
            }
        }
        canvas.restoreToCount(save)
    }

    private fun ball(canvas: Canvas, color: Int) {
        paint.color = color
        canvas.drawCircle(8f, 0f, 3f, paint)
        paint.color = 0x88FFFFFF.toInt()
        canvas.drawCircle(7f, -1f, 1f, paint)
    }

    /** A little tombstone where a worm fell. */
    fun grave(canvas: Canvas, x: Float, y: Float) {
        paint.style = Paint.Style.FILL
        paint.color = 0xFF9E9E9E.toInt()
        oval.set(x - 5f, y - 13f, x + 5f, y - 3f)
        canvas.drawArc(oval, 180f, 180f, true, paint)
        canvas.drawRect(x - 5f, y - 8f, x + 5f, y + 6f, paint)
        paint.color = 0xFF616161.toInt()
        canvas.drawRect(x - 0.6f, y - 9f, x + 0.6f, y - 1f, paint)
        canvas.drawRect(x - 2.5f, y - 7f, x + 2.5f, y - 5.8f, paint)
    }

    private companion object {
        const val BODY = 0xFFFFA5B4.toInt()
        const val BODY_DARK = 0xFFE07A8C.toInt()
    }
}
