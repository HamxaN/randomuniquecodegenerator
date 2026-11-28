package com.hamxanadeem.rewind.game

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import com.hamxanadeem.rewind.core.EnemyKind
import com.hamxanadeem.rewind.core.TowerKind
import kotlin.math.cos
import kotlin.math.sin

/** Vector art for towers and enemies, shared by the game view and the menu icons. */
object Art {
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
    private val rect = RectF()
    private val path = Path()

    fun towerColor(k: TowerKind): Int = when (k) {
        TowerKind.BOLT -> 0xFF4FC3F7.toInt()
        TowerKind.CANNON -> 0xFFFF8A3D.toInt()
        TowerKind.FROST -> 0xFFB3E5FC.toInt()
        TowerKind.TESLA -> 0xFFB388FF.toInt()
        TowerKind.SNIPER -> 0xFF9CCC65.toInt()
    }

    fun enemyColor(k: EnemyKind): Int = when (k) {
        EnemyKind.SCOUT -> 0xFFFFD54F.toInt()
        EnemyKind.GRUNT -> 0xFFEF5350.toInt()
        EnemyKind.SWARM -> 0xFFFF80AB.toInt()
        EnemyKind.FLYER -> 0xFF4DD0E1.toInt()
        EnemyKind.TANK -> 0xFF8D6E63.toInt()
        EnemyKind.SPLITTER -> 0xFFAED581.toInt()
        EnemyKind.SHIELD -> 0xFF7986CB.toInt()
        EnemyKind.BOSS -> 0xFFD32F2F.toInt()
    }

    /** A tower centred at (cx, cy), [s] = one cell in pixels. */
    fun tower(c: Canvas, k: TowerKind, level: Int, cx: Float, cy: Float, s: Float, aim: Float, glow: Float = 0f) {
        val col = towerColor(k)
        // Base.
        rect.set(cx - s * 0.42f, cy - s * 0.42f, cx + s * 0.42f, cy + s * 0.42f)
        fill.color = 0xFF263238.toInt()
        c.drawRoundRect(rect, s * 0.14f, s * 0.14f, fill)
        fill.color = 0xFF37474F.toInt()
        rect.inset(s * 0.05f, s * 0.05f)
        c.drawRoundRect(rect, s * 0.11f, s * 0.11f, fill)
        // Barrel.
        val bx = cos(aim)
        val by = sin(aim)
        stroke.color = 0xFF1C262B.toInt()
        when (k) {
            TowerKind.BOLT -> {
                stroke.strokeWidth = s * 0.08f
                val px = -by * s * 0.09f
                val py = bx * s * 0.09f
                for (side in listOf(-1f, 1f)) {
                    c.drawLine(cx + px * side, cy + py * side, cx + px * side + bx * s * 0.42f, cy + py * side + by * s * 0.42f, stroke)
                }
            }
            TowerKind.CANNON -> {
                stroke.strokeWidth = s * 0.2f
                c.drawLine(cx, cy, cx + bx * s * 0.4f, cy + by * s * 0.4f, stroke)
            }
            TowerKind.SNIPER -> {
                stroke.strokeWidth = s * 0.07f
                c.drawLine(cx - bx * s * 0.1f, cy - by * s * 0.1f, cx + bx * s * 0.58f, cy + by * s * 0.58f, stroke)
            }
            TowerKind.FROST, TowerKind.TESLA -> Unit
        }
        // Turret.
        if (glow > 0f) {
            fill.color = (col and 0x00FFFFFF) or ((glow * 120).toInt().coerceIn(0, 255) shl 24)
            c.drawCircle(cx, cy, s * 0.46f, fill)
        }
        fill.color = col
        when (k) {
            TowerKind.FROST -> {
                hexagon(cx, cy, s * 0.26f)
                c.drawPath(path, fill)
                stroke.color = Color.WHITE
                stroke.strokeWidth = s * 0.045f
                for (i in 0 until 3) {
                    val a = Math.PI / 3 * i
                    val dx = (cos(a) * s * 0.2f).toFloat()
                    val dy = (sin(a) * s * 0.2f).toFloat()
                    c.drawLine(cx - dx, cy - dy, cx + dx, cy + dy, stroke)
                }
            }
            TowerKind.TESLA -> {
                c.drawCircle(cx, cy, s * 0.22f, fill)
                stroke.color = 0xFFEDE7F6.toInt()
                stroke.strokeWidth = s * 0.04f
                c.drawCircle(cx, cy, s * 0.13f, stroke)
                fill.color = Color.WHITE
                c.drawCircle(cx, cy, s * 0.06f, fill)
            }
            else -> {
                c.drawCircle(cx, cy, s * 0.2f, fill)
                fill.color = 0x33FFFFFF
                c.drawCircle(cx - s * 0.05f, cy - s * 0.05f, s * 0.09f, fill)
            }
        }
        // Level pips.
        fill.color = 0xFFFFD54F.toInt()
        for (i in 0 until level) {
            c.drawCircle(cx - s * 0.22f + i * s * 0.22f, cy + s * 0.33f, s * 0.05f, fill)
        }
    }

    private fun hexagon(cx: Float, cy: Float, r: Float) {
        path.reset()
        for (i in 0 until 6) {
            val a = Math.PI / 3 * i + Math.PI / 6
            val x = cx + (cos(a) * r).toFloat()
            val y = cy + (sin(a) * r).toFloat()
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
    }

    /** An enemy centred at (cx, cy). [alpha] 0..1 (ghosts are faint). */
    fun enemy(c: Canvas, k: EnemyKind, cx: Float, cy: Float, s: Float, phase: Float, alpha: Float = 1f, slowed: Boolean = false, tint: Int? = null) {
        val a = (alpha * 255).toInt().coerceIn(0, 255)
        val r = (k.radius * s).toFloat()
        val col = tint ?: enemyColor(k)
        fun withA(color: Int) = (color and 0x00FFFFFF) or (((color ushr 24) * a / 255) shl 24)
        if (k.flying) {
            // Shadow and flapping wings.
            fill.color = withA(0x40000000)
            c.drawOval(cx - r, cy + r * 0.9f, cx + r, cy + r * 1.3f, fill)
            val flap = (sin(phase * 14f) * 0.35f + 0.85f)
            fill.color = withA(0xCCFFFFFF.toInt())
            c.drawOval(cx - r * 1.9f, cy - r * 0.35f * flap, cx - r * 0.3f, cy + r * 0.25f * flap, fill)
            c.drawOval(cx + r * 0.3f, cy - r * 0.35f * flap, cx + r * 1.9f, cy + r * 0.25f * flap, fill)
        } else {
            fill.color = withA(0x40000000)
            c.drawOval(cx - r * 0.9f, cy + r * 0.55f, cx + r * 0.9f, cy + r * 1.05f, fill)
        }
        val bob = if (k.flying) 0f else (sin(phase * 10f) * r * 0.08f)
        fill.color = withA(col)
        when (k) {
            EnemyKind.TANK -> {
                rect.set(cx - r, cy - r * 0.8f + bob, cx + r, cy + r * 0.8f + bob)
                c.drawRoundRect(rect, r * 0.3f, r * 0.3f, fill)
                fill.color = withA(0xFF5D4037.toInt())
                c.drawCircle(cx, cy + bob, r * 0.45f, fill)
            }
            EnemyKind.BOSS -> {
                c.drawCircle(cx, cy + bob, r, fill)
                fill.color = withA(0xFFFFD54F.toInt())
                path.reset()
                path.moveTo(cx - r * 0.6f, cy - r * 0.6f + bob)
                path.lineTo(cx - r * 0.4f, cy - r * 1.15f + bob)
                path.lineTo(cx - r * 0.15f, cy - r * 0.75f + bob)
                path.lineTo(cx, cy - r * 1.25f + bob)
                path.lineTo(cx + r * 0.15f, cy - r * 0.75f + bob)
                path.lineTo(cx + r * 0.4f, cy - r * 1.15f + bob)
                path.lineTo(cx + r * 0.6f, cy - r * 0.6f + bob)
                path.close()
                c.drawPath(path, fill)
            }
            EnemyKind.SPLITTER -> {
                c.drawCircle(cx, cy + bob, r, fill)
                fill.color = withA(0xFF689F38.toInt())
                for (i in 0 until 3) {
                    val ang = phase * 2f + i * 2.094f
                    c.drawCircle(cx + cos(ang) * r * 0.45f, cy + bob + sin(ang) * r * 0.45f, r * 0.25f, fill)
                }
            }
            else -> c.drawCircle(cx, cy + bob, r, fill)
        }
        if (k == EnemyKind.SHIELD) {
            stroke.color = withA(0xAAC5CAE9.toInt())
            stroke.strokeWidth = s * 0.05f
            c.drawCircle(cx, cy + bob, r * 1.35f, stroke)
        }
        // Eyes.
        if (k != EnemyKind.SWARM) {
            fill.color = withA(Color.WHITE)
            c.drawCircle(cx - r * 0.32f, cy - r * 0.15f + bob, r * 0.22f, fill)
            c.drawCircle(cx + r * 0.32f, cy - r * 0.15f + bob, r * 0.22f, fill)
            fill.color = withA(0xFF1A1A1A.toInt())
            c.drawCircle(cx - r * 0.28f, cy - r * 0.12f + bob, r * 0.1f, fill)
            c.drawCircle(cx + r * 0.36f, cy - r * 0.12f + bob, r * 0.1f, fill)
        }
        if (slowed) {
            fill.color = withA(0x6681D4FA)
            c.drawCircle(cx, cy + bob, r * 1.1f, fill)
        }
    }
}
