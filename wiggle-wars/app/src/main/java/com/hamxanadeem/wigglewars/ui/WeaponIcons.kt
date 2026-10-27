package com.hamxanadeem.wigglewars.ui

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import androidx.core.graphics.createBitmap
import com.hamxanadeem.wigglewars.core.Weapon
import kotlin.math.cos
import kotlin.math.sin

/** Paints a picture of each weapon, for the picker and the weapon button. */
object WeaponIcons {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val path = Path()
    private val rect = RectF()

    /** A ready-made bitmap of [weapon], [size] pixels square. */
    fun bitmap(weapon: Weapon, size: Int): Bitmap {
        val bmp = createBitmap(size, size)
        draw(Canvas(bmp), weapon, size / 2f, size / 2f, size.toFloat())
        return bmp
    }

    /** Draws [weapon] centred on ([cx], [cy]) in a box [size] pixels wide. */
    fun draw(canvas: Canvas, weapon: Weapon, cx: Float, cy: Float, size: Float) {
        val save = canvas.save()
        canvas.translate(cx, cy)
        // Every icon is designed on a 48 × 48 grid around the centre.
        canvas.scale(size / 48f, size / 48f)
        paint.style = Paint.Style.FILL
        when (weapon) {
            Weapon.BAZOOKA -> bazooka(canvas)
            Weapon.GRENADE -> grenade(canvas, 0xFF43A047.toInt(), 0xFF1B5E20.toInt())
            Weapon.CLUSTER -> cluster(canvas)
            Weapon.BANANA -> banana(canvas)
            Weapon.MEGA_GRENADE -> mega(canvas)
            Weapon.DYNAMITE -> dynamite(canvas)
            Weapon.MINE -> mine(canvas)
            Weapon.SHOTGUN -> shotgun(canvas)
            Weapon.UZI -> uzi(canvas)
            Weapon.SNIPER -> sniper(canvas)
            Weapon.AIRSTRIKE -> airstrike(canvas)
            Weapon.SHEEP -> sheep(canvas, 0f)
            Weapon.BAT -> bat(canvas)
            Weapon.TELEPORT -> teleport(canvas)
            Weapon.GIRDER -> girder(canvas)
        }
        canvas.restoreToCount(save)
    }

    private fun fill(color: Int) = paint.apply { this.color = color }

    private fun line(canvas: Canvas, x0: Float, y0: Float, x1: Float, y1: Float, width: Float, color: Int) {
        stroke.strokeWidth = width
        stroke.color = color
        canvas.drawLine(x0, y0, x1, y1, stroke)
    }

    private fun bazooka(canvas: Canvas) {
        canvas.save()
        canvas.rotate(-22f)
        canvas.drawRoundRect(-21f, -5.5f, 17f, 5.5f, 4f, 4f, fill(0xFF6B8E23.toInt()))
        canvas.drawRect(-21f, -5.5f, 17f, -2f, fill(0xFF8FB339.toInt()))
        canvas.drawRect(15f, -7f, 21f, 7f, fill(0xFF37474F.toInt()))
        canvas.drawRect(-23f, -6.5f, -18f, 6.5f, fill(0xFF37474F.toInt()))
        canvas.drawRect(-6f, 5f, -1f, 13f, fill(0xFF5D4037.toInt()))
        canvas.drawRect(4f, 5f, 8f, 10f, fill(0xFF5D4037.toInt()))
        canvas.drawCircle(21f, 0f, 3.5f, fill(0xFFE53935.toInt()))
        canvas.restore()
    }

    private fun grenade(canvas: Canvas, body: Int, dark: Int) {
        canvas.drawCircle(0f, 5f, 14f, fill(dark))
        canvas.drawCircle(-1f, 4f, 13f, fill(body))
        // Segment lines.
        line(canvas, -13f, 4f, 12f, 4f, 1.2f, dark)
        line(canvas, -1f, -8f, -1f, 17f, 1.2f, dark)
        canvas.drawCircle(-6f, -2f, 3.5f, fill(0x66FFFFFF))
        canvas.drawRect(-4f, -13f, 4f, -8f, fill(0xFF9E9E9E.toInt()))
        stroke.style = Paint.Style.STROKE
        line(canvas, 4f, -12f, 12f, -6f, 2.2f, 0xFF9E9E9E.toInt())
        stroke.strokeWidth = 1.8f
        canvas.drawCircle(9f, -15f, 4f, stroke)
    }

    private fun cluster(canvas: Canvas) {
        canvas.drawCircle(-1f, 2f, 13f, fill(0xFF8E0000.toInt()))
        canvas.drawCircle(-2f, 1f, 12f, fill(0xFFD32F2F.toInt()))
        canvas.drawCircle(-6f, -4f, 3.5f, fill(0x66FFFFFF))
        canvas.drawRect(-5f, -14f, 3f, -9f, fill(0xFF9E9E9E.toInt()))
        for ((x, y) in listOf(14f to -10f, 17f to 4f, 12f to 16f, -14f to 17f)) {
            canvas.drawCircle(x, y, 3.6f, fill(0xFF212121.toInt()))
            canvas.drawCircle(x - 1f, y - 1f, 1.2f, fill(0x88FFFFFF.toInt()))
        }
    }

    private fun banana(canvas: Canvas) {
        path.reset()
        path.moveTo(-18f, -10f)
        path.quadTo(-12f, 20f, 18f, 12f)
        path.quadTo(-4f, 10f, -12f, -12f)
        path.close()
        canvas.drawPath(path, fill(0xFFFFD600.toInt()))
        path.reset()
        path.moveTo(-15f, -8f)
        path.quadTo(-9f, 13f, 12f, 12f)
        path.quadTo(-9f, 17f, -16f, -6f)
        path.close()
        canvas.drawPath(path, fill(0xFFF9A825.toInt()))
        canvas.drawCircle(-15f, -11f, 3f, fill(0xFF5D4037.toInt()))
        canvas.drawCircle(18f, 12f, 2.4f, fill(0xFF5D4037.toInt()))
        // A little spark: it's a bomb!
        star(canvas, 13f, -12f, 6f, 0xFFFF6D00.toInt())
    }

    private fun mega(canvas: Canvas) {
        canvas.drawCircle(0f, 6f, 15f, fill(0xFFB8860B.toInt()))
        canvas.drawCircle(-1f, 5f, 14f, fill(0xFFFFC107.toInt()))
        canvas.drawCircle(-6f, -1f, 4.5f, fill(0x88FFFFFF.toInt()))
        canvas.drawRect(-3f, -16f, 3f, -8f, fill(0xFFFFE082.toInt()))
        canvas.drawRect(-7f, -13f, 7f, -10f, fill(0xFFFFE082.toInt()))
        star(canvas, 8f, 10f, 5f, 0xFFFFFFFF.toInt())
        star(canvas, -14f, -14f, 4f, 0xFFFFF59D.toInt())
        star(canvas, 16f, -10f, 3.5f, 0xFFFFF59D.toInt())
    }

    private fun dynamite(canvas: Canvas) {
        for (i in -1..1) {
            val x = i * 8f
            canvas.drawRoundRect(x - 4f, -8f, x + 4f, 18f, 2f, 2f, fill(0xFFC62828.toInt()))
            canvas.drawRect(x - 4f, -8f, x - 1.5f, 18f, fill(0xFFE57373.toInt()))
        }
        canvas.drawRect(-13f, 3f, 13f, 7f, fill(0xFF212121.toInt()))
        stroke.style = Paint.Style.STROKE
        path.reset()
        path.moveTo(0f, -8f)
        path.quadTo(4f, -16f, 12f, -14f)
        stroke.strokeWidth = 2f
        stroke.color = 0xFF5D4037.toInt()
        canvas.drawPath(path, stroke)
        star(canvas, 13f, -15f, 6f, 0xFFFFEB3B.toInt())
    }

    private fun mine(canvas: Canvas) {
        canvas.drawRoundRect(-19f, 8f, 19f, 14f, 3f, 3f, fill(0xFF37474F.toInt()))
        rect.set(-15f, -8f, 15f, 22f)
        canvas.drawArc(rect, 180f, 180f, true, fill(0xFF546E7A.toInt()))
        rect.set(-15f, -8f, -2f, 14f)
        canvas.drawArc(rect, 180f, 90f, true, fill(0xFF78909C.toInt()))
        for (a in listOf(-60f, -30f, 0f, 30f, 60f)) {
            val r = Math.toRadians((a - 90).toDouble())
            line(canvas, (cos(r) * 14).toFloat(), 7f + (sin(r) * 14).toFloat(), (cos(r) * 19).toFloat(), 7f + (sin(r) * 19).toFloat(), 2.4f, 0xFF37474F.toInt())
        }
        canvas.drawCircle(0f, -4f, 3.5f, fill(0xFFFF1744.toInt()))
        canvas.drawCircle(0f, -4f, 6f, fill(0x44FF1744))
    }

    private fun shotgun(canvas: Canvas) {
        canvas.save()
        canvas.rotate(-12f)
        path.reset()
        path.moveTo(-22f, 0f); path.lineTo(-8f, -3f); path.lineTo(-6f, 4f); path.lineTo(-20f, 9f); path.close()
        canvas.drawPath(path, fill(0xFF6D4C41.toInt()))
        canvas.drawRect(-8f, -4f, 0f, 4f, fill(0xFF424242.toInt()))
        canvas.drawRect(0f, -4f, 22f, -0.5f, fill(0xFF616161.toInt()))
        canvas.drawRect(0f, 0.5f, 22f, 4f, fill(0xFF424242.toInt()))
        canvas.drawRect(2f, 4f, 12f, 7f, fill(0xFF8D6E63.toInt()))
        canvas.restore()
    }

    private fun uzi(canvas: Canvas) {
        canvas.drawRoundRect(-14f, -9f, 12f, 1f, 2f, 2f, fill(0xFF37474F.toInt()))
        canvas.drawRect(-14f, -9f, 12f, -6f, fill(0xFF546E7A.toInt()))
        canvas.drawRect(12f, -6f, 21f, -3f, fill(0xFF263238.toInt()))
        canvas.drawRect(-3f, 1f, 3f, 20f, fill(0xFF263238.toInt()))
        canvas.drawRect(-12f, 1f, -6f, 11f, fill(0xFF37474F.toInt()))
        canvas.drawRect(-22f, -7f, -14f, -4f, fill(0xFF263238.toInt()))
        // Muzzle flash.
        star(canvas, 23f, -4.5f, 5f, 0xFFFFEB3B.toInt())
    }

    private fun sniper(canvas: Canvas) {
        canvas.save()
        canvas.rotate(-10f)
        path.reset()
        path.moveTo(-24f, -2f); path.lineTo(-10f, -3f); path.lineTo(-8f, 4f); path.lineTo(-22f, 8f); path.close()
        canvas.drawPath(path, fill(0xFF5D4037.toInt()))
        canvas.drawRect(-10f, -3f, 4f, 3f, fill(0xFF2E3B33.toInt()))
        canvas.drawRect(4f, -1.5f, 24f, 1.5f, fill(0xFF263238.toInt()))
        canvas.drawRect(-6f, -10f, 6f, -5f, fill(0xFF212121.toInt()))
        canvas.drawCircle(6f, -7.5f, 3f, fill(0xFF4FC3F7.toInt()))
        canvas.drawRect(-2f, -5f, 0f, -3f, fill(0xFF212121.toInt()))
        line(canvas, 14f, 1.5f, 11f, 9f, 1.5f, 0xFF424242.toInt())
        line(canvas, 14f, 1.5f, 17f, 9f, 1.5f, 0xFF424242.toInt())
        canvas.restore()
    }

    private fun airstrike(canvas: Canvas) {
        path.reset()
        path.moveTo(-22f, -10f); path.lineTo(16f, -14f); path.lineTo(22f, -11f); path.lineTo(16f, -8f); path.lineTo(-22f, -6f); path.close()
        canvas.drawPath(path, fill(0xFF607D8B.toInt()))
        path.reset()
        path.moveTo(-2f, -10f); path.lineTo(-12f, -22f); path.lineTo(-6f, -22f); path.lineTo(8f, -10f); path.close()
        canvas.drawPath(path, fill(0xFF455A64.toInt()))
        path.reset()
        path.moveTo(-18f, -9f); path.lineTo(-23f, -18f); path.lineTo(-19f, -18f); path.lineTo(-13f, -9f); path.close()
        canvas.drawPath(path, fill(0xFF455A64.toInt()))
        canvas.drawCircle(13f, -11f, 2f, fill(0xFFB3E5FC.toInt()))
        for ((i, x) in listOf(-12f, -2f, 8f).withIndex()) {
            val y = 2f + i * 5f
            canvas.drawRoundRect(x - 2.5f, y, x + 2.5f, y + 9f, 2.5f, 2.5f, fill(0xFFD32F2F.toInt()))
            canvas.drawRect(x - 3.5f, y, x + 3.5f, y + 2f, fill(0xFF424242.toInt()))
        }
    }

    /** Also used to draw a sheep walking across the map; [step] animates its legs. */
    fun sheep(canvas: Canvas, step: Float) {
        val swing = sin(step) * 3f
        for (x in listOf(-9f + swing, -3f - swing, 5f + swing, 11f - swing)) line(canvas, x, 8f, x, 18f, 3f, 0xFF212121.toInt())
        val wool = fill(0xFFF5F5F5.toInt())
        for ((x, y, r) in listOf(Triple(-10f, 0f, 9f), Triple(0f, -4f, 10f), Triple(10f, 0f, 9f), Triple(-2f, 6f, 9f), Triple(8f, 6f, 8f), Triple(-12f, 6f, 7f))) {
            canvas.drawCircle(x, y, r, wool)
        }
        canvas.drawCircle(-3f, -7f, 4f, fill(0xFFFFFFFF.toInt()))
        canvas.drawRoundRect(14f, -10f, 26f, 2f, 5f, 5f, fill(0xFF212121.toInt()))
        canvas.drawCircle(21f, -6f, 1.8f, fill(0xFFFFFFFF.toInt()))
        canvas.drawCircle(21.5f, -6f, 0.9f, fill(0xFF000000.toInt()))
        canvas.drawOval(12f, -12f, 17f, -7f, fill(0xFF424242.toInt()))
    }

    private fun bat(canvas: Canvas) {
        canvas.save()
        canvas.rotate(-40f)
        path.reset()
        path.moveTo(-22f, -1.5f); path.lineTo(4f, -3f); path.quadTo(22f, -6f, 23f, 0f); path.quadTo(22f, 6f, 4f, 3f); path.lineTo(-22f, 1.5f); path.close()
        canvas.drawPath(path, fill(0xFFD7A86E.toInt()))
        canvas.drawRect(-22f, -2f, -10f, 2f, fill(0xFF424242.toInt()))
        canvas.drawCircle(-23f, 0f, 3f, fill(0xFF424242.toInt()))
        line(canvas, 6f, -1.5f, 20f, -3f, 1.2f, 0x55FFFFFF)
        canvas.restore()
    }

    private fun teleport(canvas: Canvas) {
        stroke.style = Paint.Style.STROKE
        for ((i, color) in listOf(0xFF4A148C.toInt(), 0xFF8E24AA.toInt(), 0xFFCE93D8.toInt()).withIndex()) {
            stroke.strokeWidth = 3.5f - i * 0.5f
            stroke.color = color
            rect.set(-18f + i * 6, -18f + i * 6, 18f - i * 6, 18f - i * 6)
            canvas.drawArc(rect, i * 70f, 270f, false, stroke)
        }
        canvas.drawCircle(0f, 0f, 4f, fill(0xFFFFFFFF.toInt()))
        star(canvas, 16f, -16f, 5f, 0xFFE1BEE7.toInt())
        star(canvas, -17f, 15f, 4f, 0xFFE1BEE7.toInt())
    }

    private fun girder(canvas: Canvas) {
        canvas.save()
        canvas.rotate(-15f)
        canvas.drawRect(-23f, -6f, 23f, 6f, fill(0xFF8E3B0B.toInt()))
        canvas.drawRect(-22f, -5f, 22f, 5f, fill(0xFFE67E22.toInt()))
        canvas.drawRect(-22f, -5f, 22f, -2f, fill(0xFFF39C4A.toInt()))
        var x = -18f
        while (x < 20f) {
            canvas.drawCircle(x, 0.5f, 1.6f, fill(0xFF8E3B0B.toInt()))
            x += 9f
        }
        canvas.restore()
        line(canvas, -6f, 8f, -6f, 20f, 2f, 0xFF616161.toInt())
        line(canvas, 6f, 4f, 6f, 20f, 2f, 0xFF616161.toInt())
    }

    private fun star(canvas: Canvas, x: Float, y: Float, r: Float, color: Int) {
        path.reset()
        for (i in 0 until 8) {
            val a = i * Math.PI / 4
            val rr = if (i % 2 == 0) r else r * 0.4f
            val px = x + (cos(a) * rr).toFloat()
            val py = y + (sin(a) * rr).toFloat()
            if (i == 0) path.moveTo(px, py) else path.lineTo(px, py)
        }
        path.close()
        canvas.drawPath(path, fill(color))
    }
}
