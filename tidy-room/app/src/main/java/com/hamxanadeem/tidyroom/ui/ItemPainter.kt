package com.hamxanadeem.tidyroom.ui

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import com.hamxanadeem.tidyroom.core.ItemType

/**
 * Paints each kind of item in a cosy cartoon style. With [ghost] set the item is
 * drawn as a soft silhouette: the outline that shows where it belongs.
 */
class ItemPainter {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND }
    private val path = Path()
    private val rect = RectF()
    private var ghost = false
    private var ghostColor = 0

    /** Draws [type] centred on ([cx], [cy]), [size] pixels wide. */
    fun draw(canvas: Canvas, type: ItemType, cx: Float, cy: Float, size: Float, ghost: Boolean = false, ghostColor: Int = 0x55000000) {
        this.ghost = ghost
        this.ghostColor = ghostColor
        val save = canvas.save()
        canvas.translate(cx, cy)
        // Items are designed in a 100-unit box.
        canvas.scale(size / 100f, size / 100f)
        line.strokeWidth = 5f
        when (type) {
            ItemType.BOOK -> book()
            ItemType.MUG -> mug()
            ItemType.PLANT -> plant()
            ItemType.SHOE -> shoe()
            ItemType.PILLOW -> pillow()
            ItemType.TEDDY -> teddy()
            ItemType.LAMP -> lamp()
            ItemType.CLOCK -> clock()
            ItemType.PLATE -> plate()
            ItemType.BOTTLE -> bottle()
            ItemType.TOWEL -> towel()
            ItemType.DUCK -> duck()
            ItemType.FRAME -> frame()
            ItemType.VASE -> vase()
            ItemType.GAMEPAD -> gamepad()
            ItemType.SOCK -> sock()
        }.invoke(canvas)
        canvas.restoreToCount(save)
    }

    private fun fill(color: Int): Paint = paint.apply { this.color = if (ghost) ghostColor else color }

    /** Detail strokes and highlights vanish in a ghost. */
    private fun detail(color: Int): Paint? = if (ghost) null else paint.apply { this.color = color }

    private fun stroke(color: Int, width: Float = 5f): Paint? = if (ghost) null else line.apply { this.color = color; strokeWidth = width }

    private fun book(): (Canvas) -> Unit = { c ->
        rect.set(-30f, -48f, 30f, 48f)
        c.drawRoundRect(rect, 6f, 6f, fill(0xFF5C6BC0.toInt()))
        detail(0xFFF5F5F5.toInt())?.let { rect.set(18f, -44f, 28f, 44f); c.drawRect(rect, it) }
        detail(0xFFFFCA28.toInt())?.let { c.drawRect(-22f, -28f, 10f, -20f, it); c.drawRect(-22f, -14f, 4f, -9f, it) }
        detail(0xFF3949AB.toInt())?.let { c.drawRect(-30f, -48f, -22f, 48f, it) }
    }

    private fun mug(): (Canvas) -> Unit = { c ->
        line.strokeWidth = 10f
        if (ghost) {
            line.color = ghostColor
            rect.set(18f, -14f, 46f, 18f)
            c.drawArc(rect, -90f, 180f, false, line)
        } else {
            line.color = 0xFFE57373.toInt()
            rect.set(18f, -14f, 46f, 18f)
            c.drawArc(rect, -90f, 180f, false, line)
        }
        rect.set(-34f, -34f, 26f, 40f)
        c.drawRoundRect(rect, 10f, 10f, fill(0xFFE57373.toInt()))
        detail(0xFFFFFFFF.toInt())?.let { c.drawCircle(-4f, 4f, 10f, it) }
        detail(0xFFFF8A80.toInt())?.let { c.drawCircle(-4f, 4f, 5f, it) }
        detail(0xFF6D4C41.toInt())?.let { c.drawOval(-30f, -36f, 22f, -26f, it) }
        stroke(0x66FFFFFF, 4f)?.let { c.drawLine(-24f, -20f, -24f, 26f, it) }
    }

    private fun plant(): (Canvas) -> Unit = { c ->
        val leaf = fill(0xFF66BB6A.toInt())
        for ((x, y, a) in listOf(Triple(-18f, -22f, -35f), Triple(18f, -22f, 35f), Triple(0f, -32f, 0f), Triple(-26f, -2f, -70f), Triple(26f, -2f, 70f))) {
            c.save()
            c.rotate(a, 0f, 10f)
            c.drawOval(x - 12f, y - 26f, x + 12f, y + 22f, leaf)
            c.restore()
        }
        detail(0xFF43A047.toInt())?.let { c.drawLine(0f, 10f, 0f, -40f, line.apply { color = 0xFF43A047.toInt(); strokeWidth = 4f }) }
        path.reset()
        path.moveTo(-28f, 8f); path.lineTo(28f, 8f); path.lineTo(20f, 48f); path.lineTo(-20f, 48f); path.close()
        c.drawPath(path, fill(0xFFE07A4F.toInt()))
        detail(0xFFC0623A.toInt())?.let { c.drawRect(-30f, 6f, 30f, 16f, it) }
    }

    private fun shoe(): (Canvas) -> Unit = { c ->
        path.reset()
        path.moveTo(-44f, 18f); path.lineTo(-44f, -24f); path.quadTo(-44f, -32f, -34f, -32f); path.lineTo(-12f, -32f)
        path.quadTo(-6f, -6f, 18f, -2f); path.quadTo(46f, 2f, 46f, 18f); path.close()
        c.drawPath(path, fill(0xFF42A5F5.toInt()))
        detail(0xFFFFFFFF.toInt())?.let { c.drawRect(-46f, 14f, 48f, 24f, it) }
        stroke(0xFFFFFFFF.toInt(), 3f)?.let { for (i in 0 until 3) c.drawLine(-22f + i * 8f, -20f + i * 6f, -10f + i * 8f, -24f + i * 6f, it) }
    }

    private fun pillow(): (Canvas) -> Unit = { c ->
        path.reset()
        path.moveTo(-46f, -28f); path.quadTo(0f, -40f, 46f, -28f); path.quadTo(40f, 0f, 46f, 28f)
        path.quadTo(0f, 40f, -46f, 28f); path.quadTo(-40f, 0f, -46f, -28f); path.close()
        c.drawPath(path, fill(0xFFF8BBD0.toInt()))
        detail(0xFFF48FB1.toInt())?.let { c.drawCircle(-14f, -6f, 5f, it); c.drawCircle(14f, 8f, 5f, it); c.drawCircle(16f, -12f, 4f, it); c.drawCircle(-12f, 14f, 4f, it) }
    }

    private fun teddy(): (Canvas) -> Unit = { c ->
        val fur = fill(0xFFB07A4F.toInt())
        c.drawCircle(-24f, -34f, 13f, fur)
        c.drawCircle(24f, -34f, 13f, fur)
        c.drawCircle(0f, -14f, 28f, fur)
        c.drawOval(-30f, 6f, 30f, 50f, fur)
        detail(0xFFD7A77A.toInt())?.let { c.drawOval(-12f, -10f, 12f, 6f, it); c.drawOval(-16f, 18f, 16f, 42f, it) }
        detail(0xFF3E2723.toInt())?.let { c.drawCircle(-10f, -20f, 4f, it); c.drawCircle(10f, -20f, 4f, it); c.drawCircle(0f, -6f, 4f, it) }
        detail(0xFFE53935.toInt())?.let { path.reset(); path.moveTo(-14f, 8f); path.lineTo(0f, 14f); path.lineTo(14f, 8f); path.lineTo(14f, 20f); path.lineTo(0f, 14f); path.lineTo(-14f, 20f); path.close(); c.drawPath(path, it) }
    }

    private fun lamp(): (Canvas) -> Unit = { c ->
        path.reset()
        path.moveTo(-30f, -12f); path.lineTo(30f, -12f); path.lineTo(18f, -48f); path.lineTo(-18f, -48f); path.close()
        c.drawPath(path, fill(0xFFFFE082.toInt()))
        c.drawRect(-4f, -12f, 4f, 36f, fill(0xFF8D6E63.toInt()))
        c.drawOval(-24f, 32f, 24f, 46f, fill(0xFF8D6E63.toInt()))
        detail(0x55FFF59D)?.let { c.drawCircle(0f, -4f, 26f, it) }
    }

    private fun clock(): (Canvas) -> Unit = { c ->
        c.drawCircle(0f, 0f, 44f, fill(0xFF4DB6AC.toInt()))
        detail(0xFFFFFFFF.toInt())?.let { c.drawCircle(0f, 0f, 35f, it) }
        stroke(0xFF37474F.toInt(), 6f)?.let { c.drawLine(0f, 0f, 0f, -24f, it); c.drawLine(0f, 0f, 16f, 6f, it) }
        detail(0xFF37474F.toInt())?.let { for (i in 0 until 12) { val a = i * Math.PI / 6; c.drawCircle((kotlin.math.cos(a) * 29).toFloat(), (kotlin.math.sin(a) * 29).toFloat(), 2.5f, it) } }
    }

    private fun plate(): (Canvas) -> Unit = { c ->
        c.drawOval(-48f, -22f, 48f, 22f, fill(0xFFECEFF1.toInt()))
        detail(0xFFFFFFFF.toInt())?.let { c.drawOval(-34f, -14f, 34f, 14f, it) }
        stroke(0xFF64B5F6.toInt(), 3f)?.let { c.drawOval(-42f, -19f, 42f, 19f, it) }
    }

    private fun bottle(): (Canvas) -> Unit = { c ->
        path.reset()
        path.moveTo(-10f, -48f); path.lineTo(10f, -48f); path.lineTo(10f, -30f); path.quadTo(26f, -22f, 26f, -6f)
        path.lineTo(26f, 44f); path.quadTo(26f, 50f, 20f, 50f); path.lineTo(-20f, 50f); path.quadTo(-26f, 50f, -26f, 44f)
        path.lineTo(-26f, -6f); path.quadTo(-26f, -22f, -10f, -30f); path.close()
        c.drawPath(path, fill(0xFF26C6DA.toInt()))
        detail(0xFFFFFFFF.toInt())?.let { c.drawRect(-26f, 2f, 26f, 26f, it) }
        detail(0xFF00838F.toInt())?.let { c.drawRect(-12f, -54f, 12f, -44f, it) }
        detail(0xFFFF7043.toInt())?.let { c.drawCircle(0f, 14f, 7f, it) }
    }

    private fun towel(): (Canvas) -> Unit = { c ->
        rect.set(-40f, -44f, 40f, 44f)
        c.drawRoundRect(rect, 10f, 10f, fill(0xFF81D4FA.toInt()))
        detail(0xFFFFFFFF.toInt())?.let { c.drawRect(-40f, 18f, 40f, 26f, it); c.drawRect(-40f, 32f, 40f, 36f, it) }
        detail(0x2201579B)?.let { c.drawRect(-40f, -44f, -24f, 44f, it) }
    }

    private fun duck(): (Canvas) -> Unit = { c ->
        c.drawOval(-42f, -4f, 36f, 44f, fill(0xFFFFEB3B.toInt()))
        c.drawCircle(18f, -20f, 22f, fill(0xFFFFEB3B.toInt()))
        path.reset()
        path.moveTo(36f, -22f); path.lineTo(54f, -16f); path.lineTo(36f, -8f); path.close()
        c.drawPath(path, fill(0xFFFF9800.toInt()))
        detail(0xFF212121.toInt())?.let { c.drawCircle(24f, -26f, 4f, it) }
        detail(0xFFFDD835.toInt())?.let { c.drawOval(-30f, 6f, 6f, 30f, it) }
    }

    private fun frame(): (Canvas) -> Unit = { c ->
        rect.set(-46f, -38f, 46f, 38f)
        c.drawRoundRect(rect, 4f, 4f, fill(0xFFA1887F.toInt()))
        detail(0xFFB3E5FC.toInt())?.let { c.drawRect(-36f, -28f, 36f, 28f, it) }
        detail(0xFF66BB6A.toInt())?.let { path.reset(); path.moveTo(-36f, 28f); path.lineTo(-10f, -2f); path.lineTo(8f, 16f); path.lineTo(20f, 4f); path.lineTo(36f, 28f); path.close(); c.drawPath(path, it) }
        detail(0xFFFFEE58.toInt())?.let { c.drawCircle(20f, -14f, 7f, it) }
    }

    private fun vase(): (Canvas) -> Unit = { c ->
        path.reset()
        path.moveTo(-14f, -46f); path.lineTo(14f, -46f); path.quadTo(8f, -30f, 30f, 0f); path.quadTo(40f, 30f, 18f, 48f)
        path.lineTo(-18f, 48f); path.quadTo(-40f, 30f, -30f, 0f); path.quadTo(-8f, -30f, -14f, -46f); path.close()
        c.drawPath(path, fill(0xFF7E57C2.toInt()))
        stroke(0xFFFFD54F.toInt(), 4f)?.let { c.drawLine(-30f, 10f, 30f, 10f, it); c.drawLine(-26f, 24f, 26f, 24f, it) }
        detail(0x44FFFFFF)?.let { c.drawOval(-22f, -10f, -12f, 30f, it) }
    }

    private fun gamepad(): (Canvas) -> Unit = { c ->
        path.reset()
        path.moveTo(-30f, -24f); path.lineTo(30f, -24f); path.quadTo(50f, -24f, 50f, 0f); path.quadTo(54f, 30f, 36f, 30f)
        path.quadTo(24f, 30f, 18f, 14f); path.lineTo(-18f, 14f); path.quadTo(-24f, 30f, -36f, 30f); path.quadTo(-54f, 30f, -50f, 0f)
        path.quadTo(-50f, -24f, -30f, -24f); path.close()
        c.drawPath(path, fill(0xFF455A64.toInt()))
        detail(0xFFECEFF1.toInt())?.let { c.drawRect(-36f, -6f, -16f, 2f, it); c.drawRect(-30f, -12f, -22f, 8f, it) }
        detail(0xFFEF5350.toInt())?.let { c.drawCircle(24f, -8f, 5f, it) }
        detail(0xFF66BB6A.toInt())?.let { c.drawCircle(34f, 2f, 5f, it) }
    }

    private fun sock(): (Canvas) -> Unit = { c ->
        path.reset()
        path.moveTo(-16f, -48f); path.lineTo(14f, -48f); path.lineTo(14f, 12f); path.quadTo(44f, 14f, 44f, 34f)
        path.quadTo(44f, 50f, 24f, 50f); path.lineTo(-6f, 50f); path.quadTo(-16f, 50f, -16f, 38f); path.close()
        c.drawPath(path, fill(0xFFFF8A65.toInt()))
        detail(0xFFFFFFFF.toInt())?.let { c.drawRect(-16f, -48f, 14f, -36f, it); c.drawRect(-16f, -24f, 14f, -18f, it); c.drawRect(-16f, -8f, 14f, -2f, it) }
    }
}
