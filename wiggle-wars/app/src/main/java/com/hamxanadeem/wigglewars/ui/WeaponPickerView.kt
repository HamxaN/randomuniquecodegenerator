package com.hamxanadeem.wigglewars.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.SystemClock
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.hamxanadeem.wigglewars.core.FireMode
import com.hamxanadeem.wigglewars.core.Weapon
import com.hamxanadeem.wigglewars.core.WeaponCategory
import kotlin.math.ceil
import kotlin.math.min

/**
 * The armory: weapons in tabs as picture tiles with ammo badges, and a card with
 * the chosen weapon's description and ratings. Tap a tile to read about it, tap it
 * again (or Equip) to take it. In browse mode (from the menu) nothing is equipped.
 */
class WeaponPickerView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    interface Listener {
        fun onEquip(weapon: Weapon)
        fun onClose()
    }

    var listener: Listener? = null
    /** Ammo for each weapon (-1 = unlimited). */
    var ammoOf: (Weapon) -> Int = { it.startAmmo }
    /** Just looking: from the main menu. */
    var browseOnly = false

    private var equipped: Weapon? = null
    private var focus = Weapon.BAZOOKA
    /** null shows every weapon. */
    private var tab: WeaponCategory? = null
    private var openedAt = 0L

    private val dp = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val black = Neon.bold(context)
    private val text = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { typeface = black; color = 0xFFFFFFFF.toInt() }
    private val body = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFD7E3F4.toInt() }
    private val rect = RectF()
    private val path = Path()

    // Layout, worked out in onSizeChanged / layoutParts.
    private val panel = RectF()
    private val info = RectF()
    private val equipButton = RectF()
    private val closeButton = RectF()
    private val tabRects = ArrayList<Pair<WeaponCategory?, RectF>>()
    private val tiles = ArrayList<Pair<Weapon, RectF>>()
    private var descLayout: StaticLayout? = null

    fun open(current: Weapon?) {
        equipped = current
        focus = current ?: Weapon.BAZOOKA
        if (tab != null && focus.category != tab) tab = null
        openedAt = SystemClock.uptimeMillis()
        layoutParts()
        contentDescription = "Weapons. ${focus.displayName} selected."
        invalidate()
    }

    private fun visibleWeapons() = Weapon.entries.filter { tab == null || it.category == tab }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) = layoutParts()

    private fun layoutParts() {
        if (width == 0) return
        val pw = min(width - 24 * dp, 700 * dp)
        val ph = min(height - 20 * dp, 350 * dp)
        panel.set((width - pw) / 2, (height - ph) / 2, (width + pw) / 2, (height + ph) / 2)
        val pad = 12 * dp

        // Tabs along the top, after the title.
        tabRects.clear()
        text.textSize = 18 * dp
        var x = panel.left + 16 * dp + text.measureText(TITLE) + 14 * dp
        text.textSize = 11 * dp
        val tabTop = panel.top + pad
        for (c in listOf<WeaponCategory?>(null) + WeaponCategory.entries) {
            val label = (c?.displayName ?: "All").uppercase()
            val w = text.measureText(label) + 20 * dp
            tabRects += c to RectF(x, tabTop, x + w, tabTop + 30 * dp)
            x += w + 6 * dp
        }
        closeButton.set(panel.right - pad - 30 * dp, tabTop, panel.right - pad, tabTop + 30 * dp)

        // Info card on the right.
        val infoW = min(230 * dp, panel.width() * 0.38f)
        info.set(panel.right - pad - infoW, tabTop + 40 * dp, panel.right - pad, panel.bottom - pad)
        equipButton.set(info.left + 10 * dp, info.bottom - 52 * dp, info.right - 10 * dp, info.bottom - 10 * dp)

        // Tile grid on the left.
        tiles.clear()
        val list = visibleWeapons()
        val cols = if (list.size > 8) 5 else 4
        val rows = ceil(list.size / cols.toFloat()).toInt().coerceAtLeast(1)
        val gap = 8 * dp
        val areaLeft = panel.left + pad
        val areaTop = info.top
        val areaW = info.left - pad - areaLeft
        val areaH = info.bottom - areaTop
        val tile = min((areaW - gap * (cols - 1)) / cols, (areaH - gap * (rows - 1)) / rows)
        for ((i, weapon) in list.withIndex()) {
            val cx = areaLeft + (i % cols) * (tile + gap)
            val cy = areaTop + (i / cols) * (tile + gap)
            tiles += weapon to RectF(cx, cy, cx + tile, cy + tile)
        }
        buildDescription()
    }

    private fun buildDescription() {
        body.textSize = 12 * dp
        val w = (info.width() - 20 * dp).toInt().coerceAtLeast(1)
        descLayout = StaticLayout.Builder.obtain(focus.description, 0, focus.description.length, body, w)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setLineSpacing(0f, 1.05f)
            .build()
    }

    // ---------------------------------------------------------------- drawing

    override fun onDraw(canvas: Canvas) {
        if (panel.isEmpty) return
        // Pop in when opened.
        val k = ((SystemClock.uptimeMillis() - openedAt) / 220f).coerceIn(0f, 1f)
        val pop = 0.88f + 0.12f * (1 - (1 - k) * (1 - k))
        val save = canvas.save()
        canvas.scale(pop, pop, panel.centerX(), panel.centerY())

        Neon.panel(canvas, panel, Neon.CYAN, dp, path, paint, glass = 0xF50A1024.toInt())
        // Faint scan lines across the glass.
        paint.color = 0x0A00E5FF
        var sy = panel.top + 4 * dp
        while (sy < panel.bottom) {
            canvas.drawRect(panel.left + 2 * dp, sy, panel.right - 2 * dp, sy + 1 * dp, paint)
            sy += 4 * dp
        }

        text.textSize = 18 * dp
        text.color = Neon.CYAN
        text.setShadowLayer(8 * dp, 0f, 0f, Neon.CYAN)
        canvas.drawText(TITLE, panel.left + 16 * dp, panel.top + 34 * dp, text)
        text.clearShadowLayer()

        drawTabs(canvas)
        drawClose(canvas)
        for ((weapon, r) in tiles) drawTile(canvas, weapon, r)
        drawInfo(canvas)
        canvas.restoreToCount(save)
        if (k < 1f) postInvalidateOnAnimation()
    }

    private fun drawTabs(canvas: Canvas) {
        text.textSize = 11 * dp
        for ((c, r) in tabRects) {
            val on = c == tab
            Neon.chamfer(path, r, 7 * dp)
            paint.style = Paint.Style.FILL
            paint.color = if (on) Neon.withAlpha(Neon.CYAN, 0x55) else 0x1A00E5FF
            canvas.drawPath(path, paint)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1.2f * dp
            paint.color = if (on) Neon.CYAN else 0x5500E5FF
            canvas.drawPath(path, paint)
            paint.style = Paint.Style.FILL
            text.color = if (on) 0xFFFFFFFF.toInt() else 0xFF9FD8E8.toInt()
            val label = (c?.displayName ?: "All").uppercase()
            canvas.drawText(label, r.centerX() - text.measureText(label) / 2, r.centerY() + 4.5f * dp, text)
        }
    }

    private fun drawClose(canvas: Canvas) {
        paint.color = 0x33FF2BD6
        canvas.drawCircle(closeButton.centerX(), closeButton.centerY(), closeButton.width() / 2, paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1.2f * dp
        paint.color = Neon.MAGENTA
        canvas.drawCircle(closeButton.centerX(), closeButton.centerY(), closeButton.width() / 2, paint)
        paint.style = Paint.Style.FILL
        paint.color = 0xFFFFFFFF.toInt()
        paint.strokeWidth = 2.5f * dp
        paint.strokeCap = Paint.Cap.ROUND
        val c = 6 * dp
        canvas.drawLine(closeButton.centerX() - c, closeButton.centerY() - c, closeButton.centerX() + c, closeButton.centerY() + c, paint)
        canvas.drawLine(closeButton.centerX() + c, closeButton.centerY() - c, closeButton.centerX() - c, closeButton.centerY() + c, paint)
    }

    private fun drawTile(canvas: Canvas, weapon: Weapon, r: RectF) {
        val ammo = ammoOf(weapon)
        val empty = ammo == 0
        Neon.chamfer(path, r, 12 * dp)
        paint.style = Paint.Style.FILL
        paint.color = if (weapon == focus) 0xFF16305A.toInt() else 0xFF0E1A38.toInt()
        canvas.drawPath(path, paint)
        // Soft highlight on the top half.
        paint.color = 0x0FFFFFFF
        canvas.drawRect(r.left + 12 * dp, r.top + 2 * dp, r.right - 2 * dp, r.centerY(), paint)
        when {
            weapon == equipped -> ring(canvas, Neon.LIME, 2.5f * dp, glow = true)
            weapon == focus -> ring(canvas, Neon.CYAN, 2 * dp, glow = true)
            else -> ring(canvas, 0x4400E5FF, 1 * dp, glow = false)
        }

        val iconSize = r.width() * 0.72f
        if (empty) {
            val layer = canvas.saveLayerAlpha(r, 90)
            WeaponIcons.draw(canvas, weapon, r.centerX(), r.centerY() - r.height() * 0.04f, iconSize)
            canvas.restoreToCount(layer)
        } else {
            WeaponIcons.draw(canvas, weapon, r.centerX(), r.centerY() - r.height() * 0.04f, iconSize)
        }

        // Ammo badge.
        val label = if (ammo < 0) "∞" else "×$ammo"
        text.textSize = 11 * dp
        val bw = text.measureText(label) + 10 * dp
        rect.set(r.right - bw - 4 * dp, r.bottom - 20 * dp, r.right - 4 * dp, r.bottom - 4 * dp)
        paint.color = when {
            empty -> 0xCC3A2A40.toInt()
            ammo < 0 -> Neon.withAlpha(Neon.LIME, 0x66)
            else -> Neon.withAlpha(Neon.MAGENTA, 0x77)
        }
        canvas.drawRect(rect, paint)
        text.color = 0xFFFFFFFF.toInt()
        canvas.drawText(label, rect.centerX() - text.measureText(label) / 2, rect.centerY() + 4 * dp, text)
    }

    /** Outlines the tile whose shape is in [path]. */
    private fun ring(canvas: Canvas, color: Int, width: Float, glow: Boolean) {
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = width
        paint.color = color
        if (glow) paint.setShadowLayer(7 * dp, 0f, 0f, color)
        canvas.drawPath(path, paint)
        paint.clearShadowLayer()
        paint.style = Paint.Style.FILL
    }

    private fun drawInfo(canvas: Canvas) {
        Neon.panel(canvas, info, Neon.MAGENTA, dp, path, paint, glass = 0x66000814, glow = false)
        val left = info.left + 10 * dp
        var y = info.top + 8 * dp

        // Icon and name.
        val icon = 50 * dp
        paint.color = 0x2200E5FF
        canvas.drawCircle(left + icon / 2, y + icon / 2, icon / 2, paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1 * dp
        paint.color = 0x8800E5FF.toInt()
        canvas.drawCircle(left + icon / 2, y + icon / 2, icon / 2, paint)
        paint.style = Paint.Style.FILL
        WeaponIcons.draw(canvas, focus, left + icon / 2, y + icon / 2, icon * 0.86f)
        text.textSize = 17 * dp
        text.color = 0xFFFFFFFF.toInt()
        val nameX = left + icon + 8 * dp
        fitText(canvas, focus.displayName, nameX, y + 22 * dp, info.right - 8 * dp - nameX)
        text.textSize = 9.5f * dp
        text.color = Neon.CYAN
        val ammo = ammoOf(focus)
        val ammoText = when {
            ammo < 0 -> "Unlimited"
            ammo == 0 -> "None left"
            else -> "$ammo left"
        }
        canvas.drawText("${focus.category.displayName} · $ammoText", nameX, y + 40 * dp, text)
        y += icon + 8 * dp

        descLayout?.let {
            canvas.save()
            canvas.translate(left, y)
            it.draw(canvas)
            canvas.restore()
            y += it.height + 8 * dp
        }

        // Ratings, if there's room above the button.
        val bars = listOf("Power" to focus.power, "Blast" to focus.blast, "Range" to focus.range)
        if (y + bars.size * 16 * dp + 22 * dp < equipButton.top) {
            for ((label, value) in bars) {
                text.textSize = 8.5f * dp
                text.color = 0xFF9FD8E8.toInt()
                canvas.drawText(label.uppercase(), left, y + 9 * dp, text)
                val barLeft = left + 52 * dp
                val seg = (info.right - 10 * dp - barLeft - 4 * 3 * dp) / 5
                for (i in 0 until 5) {
                    rect.set(barLeft + i * (seg + 3 * dp), y + 1 * dp, barLeft + i * (seg + 3 * dp) + seg, y + 10 * dp)
                    paint.color = if (i < value) BAR_COLORS[i] else 0x26FFFFFF
                    canvas.drawRect(rect, paint)
                }
                y += 16 * dp
            }
            text.textSize = 10 * dp
            text.color = 0xFF90CAF9.toInt()
            canvas.drawText(tags(focus), left, y + 10 * dp, text)
        }

        // Equip button.
        val can = browseOnly || ammo != 0
        val accent = when {
            !can -> 0xFF5A6478.toInt()
            browseOnly -> Neon.CYAN
            focus == equipped -> Neon.LIME
            else -> Neon.MAGENTA
        }
        Neon.panel(canvas, equipButton, accent, dp, path, paint, glass = TerrainArt.mix(Neon.GLASS, accent, 0.3f), glow = can)
        val label = when {
            browseOnly -> "GOT IT"
            ammo == 0 -> "NO AMMO"
            focus == equipped -> "✓ EQUIPPED"
            else -> "EQUIP"
        }
        text.textSize = 14 * dp
        text.color = 0xFFFFFFFF.toInt()
        canvas.drawText(label, equipButton.centerX() - text.measureText(label) / 2, equipButton.centerY() + 6 * dp, text)
    }

    private fun fitText(canvas: Canvas, s: String, x: Float, y: Float, maxWidth: Float) {
        val w = text.measureText(s)
        if (w > maxWidth) text.textSize *= maxWidth / w
        canvas.drawText(s, x, y, text)
    }

    private fun tags(w: Weapon): String {
        val out = ArrayList<String>()
        when (w.mode) {
            FireMode.POWER -> out += "Hold to throw"
            FireMode.INSTANT -> out += "Instant"
            FireMode.TARGET -> out += "Tap the map"
            FireMode.DROP -> out += "Drop"
        }
        w.spec?.let { spec ->
            if (spec.windFactor > 0) out += "Wind"
            if (spec.bounce > 0.2) out += "Bounces"
            spec.fuse?.let { out += "${it.toInt()}s fuse" }
        }
        return out.joinToString("  ·  ")
    }

    // ---------------------------------------------------------------- touch

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked != MotionEvent.ACTION_UP) return true
        val x = event.x
        val y = event.y
        performClick()
        if (!panel.contains(x, y) || closeButton.contains(x, y)) {
            listener?.onClose()
            return true
        }
        tabRects.firstOrNull { it.second.contains(x, y) }?.let { (c, _) ->
            tab = c
            layoutParts()
            invalidate()
            return true
        }
        if (equipButton.contains(x, y)) {
            equipFocus()
            return true
        }
        tiles.firstOrNull { it.second.contains(x, y) }?.let { (weapon, _) ->
            if (weapon == focus) {
                equipFocus()
            } else {
                focus = weapon
                buildDescription()
                contentDescription = "${weapon.displayName}. ${weapon.description}"
                invalidate()
            }
        }
        return true
    }

    private fun equipFocus() {
        if (browseOnly) {
            listener?.onClose()
            return
        }
        if (ammoOf(focus) == 0) return
        listener?.onEquip(focus)
    }

    override fun performClick(): Boolean = super.performClick()

    private companion object {
        const val TITLE = "ARMORY"
        val BAR_COLORS = intArrayOf(Neon.CYAN, 0xFF4FC3FF.toInt(), Neon.VIOLET, 0xFFC46CFF.toInt(), Neon.MAGENTA)
    }
}
