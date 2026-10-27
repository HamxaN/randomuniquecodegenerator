package com.hamxanadeem.wigglewars.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
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
    private val black = Typeface.create("sans-serif-black", Typeface.NORMAL)
    private val text = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { typeface = black; color = 0xFFFFFFFF.toInt() }
    private val body = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFD7E3F4.toInt() }
    private val rect = RectF()

    // Layout, worked out in onSizeChanged / layoutParts.
    private val panel = RectF()
    private val info = RectF()
    private val equipButton = RectF()
    private val closeButton = RectF()
    private val tabRects = ArrayList<Pair<WeaponCategory?, RectF>>()
    private val tiles = ArrayList<Pair<Weapon, RectF>>()
    private var descLayout: StaticLayout? = null
    private var panelShader: Shader? = null

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
        panelShader = LinearGradient(0f, panel.top, 0f, panel.bottom, 0xFC243B5E.toInt(), 0xFC142338.toInt(), Shader.TileMode.CLAMP)
        val pad = 12 * dp

        // Tabs along the top, after the title.
        tabRects.clear()
        text.textSize = 13 * dp
        var x = panel.left + pad + 92 * dp
        val tabTop = panel.top + pad
        for (c in listOf<WeaponCategory?>(null) + WeaponCategory.entries) {
            val label = c?.displayName ?: "All"
            val w = text.measureText(label) + 22 * dp
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

        paint.shader = panelShader
        canvas.drawRoundRect(panel, 22 * dp, 22 * dp, paint)
        paint.shader = null
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 2 * dp
        paint.color = 0x66FFFFFF
        canvas.drawRoundRect(panel, 22 * dp, 22 * dp, paint)
        paint.style = Paint.Style.FILL

        text.textSize = 20 * dp
        text.color = 0xFFFFD54F.toInt()
        canvas.drawText("Armory", panel.left + 14 * dp, panel.top + 34 * dp, text)

        drawTabs(canvas)
        drawClose(canvas)
        for ((weapon, r) in tiles) drawTile(canvas, weapon, r)
        drawInfo(canvas)
        canvas.restoreToCount(save)
        if (k < 1f) postInvalidateOnAnimation()
    }

    private fun drawTabs(canvas: Canvas) {
        text.textSize = 13 * dp
        for ((c, r) in tabRects) {
            val on = c == tab
            paint.color = if (on) 0xFFFFB300.toInt() else 0x33FFFFFF
            canvas.drawRoundRect(r, r.height() / 2, r.height() / 2, paint)
            text.color = if (on) 0xFF3E2723.toInt() else 0xFFFFFFFF.toInt()
            val label = c?.displayName ?: "All"
            canvas.drawText(label, r.centerX() - text.measureText(label) / 2, r.centerY() + 4.5f * dp, text)
        }
    }

    private fun drawClose(canvas: Canvas) {
        paint.color = 0x33FFFFFF
        canvas.drawCircle(closeButton.centerX(), closeButton.centerY(), closeButton.width() / 2, paint)
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
        val radius = 14 * dp
        paint.color = when {
            weapon == focus -> 0xFF3D6FA8.toInt()
            else -> 0xFF2A4469.toInt()
        }
        canvas.drawRoundRect(r, radius, radius, paint)
        // Soft highlight on the top half.
        rect.set(r.left, r.top, r.right, r.centerY())
        paint.color = 0x14FFFFFF
        canvas.drawRoundRect(rect, radius, radius, paint)
        if (weapon == equipped) ring(canvas, r, 0xFFFFC107.toInt(), 3 * dp)
        if (weapon == focus) ring(canvas, r, 0xFFFFFFFF.toInt(), 2 * dp)

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
            empty -> 0xCC5D4037.toInt()
            ammo < 0 -> 0xCC1B5E20.toInt()
            else -> 0xCCE65100.toInt()
        }
        canvas.drawRoundRect(rect, 8 * dp, 8 * dp, paint)
        text.color = 0xFFFFFFFF.toInt()
        canvas.drawText(label, rect.centerX() - text.measureText(label) / 2, rect.centerY() + 4 * dp, text)
    }

    private fun ring(canvas: Canvas, r: RectF, color: Int, width: Float) {
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = width
        paint.color = color
        rect.set(r.left + width / 2, r.top + width / 2, r.right - width / 2, r.bottom - width / 2)
        canvas.drawRoundRect(rect, 13 * dp, 13 * dp, paint)
        paint.style = Paint.Style.FILL
    }

    private fun drawInfo(canvas: Canvas) {
        paint.color = 0x33000000
        canvas.drawRoundRect(info, 16 * dp, 16 * dp, paint)
        val left = info.left + 10 * dp
        var y = info.top + 8 * dp

        // Icon and name.
        val icon = 50 * dp
        paint.color = 0x22FFFFFF
        canvas.drawCircle(left + icon / 2, y + icon / 2, icon / 2, paint)
        WeaponIcons.draw(canvas, focus, left + icon / 2, y + icon / 2, icon * 0.86f)
        text.textSize = 17 * dp
        text.color = 0xFFFFFFFF.toInt()
        val nameX = left + icon + 8 * dp
        fitText(canvas, focus.displayName, nameX, y + 22 * dp, info.right - 8 * dp - nameX)
        text.textSize = 11 * dp
        text.color = 0xFFFFD54F.toInt()
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
                text.textSize = 10 * dp
                text.color = 0xFFB0C4DE.toInt()
                canvas.drawText(label, left, y + 9 * dp, text)
                val barLeft = left + 46 * dp
                val seg = (info.right - 10 * dp - barLeft - 4 * 3 * dp) / 5
                for (i in 0 until 5) {
                    rect.set(barLeft + i * (seg + 3 * dp), y + 1 * dp, barLeft + i * (seg + 3 * dp) + seg, y + 10 * dp)
                    paint.color = if (i < value) BAR_COLORS[i] else 0x26FFFFFF
                    canvas.drawRoundRect(rect, 3 * dp, 3 * dp, paint)
                }
                y += 16 * dp
            }
            text.textSize = 10 * dp
            text.color = 0xFF90CAF9.toInt()
            canvas.drawText(tags(focus), left, y + 10 * dp, text)
        }

        // Equip button.
        val can = browseOnly || ammo != 0
        paint.color = when {
            !can -> 0xFF455A64.toInt()
            browseOnly -> 0xFF1E88E5.toInt()
            focus == equipped -> 0xFF2E7D32.toInt()
            else -> 0xFFF57C00.toInt()
        }
        canvas.drawRoundRect(equipButton, 14 * dp, 14 * dp, paint)
        paint.color = 0x22FFFFFF
        rect.set(equipButton.left, equipButton.top, equipButton.right, equipButton.centerY())
        canvas.drawRoundRect(rect, 14 * dp, 14 * dp, paint)
        val label = when {
            browseOnly -> "Got it"
            ammo == 0 -> "No ammo"
            focus == equipped -> "✓ Equipped"
            else -> "Equip"
        }
        text.textSize = 17 * dp
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
        val BAR_COLORS = intArrayOf(0xFF66BB6A.toInt(), 0xFF9CCC65.toInt(), 0xFFFFEE58.toInt(), 0xFFFFA726.toInt(), 0xFFEF5350.toInt())
    }
}
