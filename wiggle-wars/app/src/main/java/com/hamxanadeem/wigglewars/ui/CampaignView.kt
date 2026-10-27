package com.hamxanadeem.wigglewars.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.SystemClock
import android.text.TextPaint
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.hamxanadeem.wigglewars.core.Campaign
import com.hamxanadeem.wigglewars.core.Mission
import com.hamxanadeem.wigglewars.data.Progress
import kotlin.math.min

/**
 * The campaign screen: a grid of missions with their stars, details of the chosen
 * one and a Play button; and an Upgrades tab to spend coins on extra starting ammo.
 */
class CampaignView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    interface Listener {
        fun onPlay(mission: Int)
        fun onClose()
        fun onBought(ok: Boolean)
    }

    var listener: Listener? = null
    var progress: Progress? = null

    private enum class Tab { MISSIONS, UPGRADES }
    private var tab = Tab.MISSIONS
    private var selected = 1
    private var openedAt = 0L

    private val dp = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val path = Path()
    private val rect = RectF()
    private val text = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Neon.bold(context); color = 0xFFFFFFFF.toInt() }
    private val body = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFC8D8F0.toInt() }

    private val panel = RectF()
    private val closeButton = RectF()
    private val tabMissions = RectF()
    private val tabUpgrades = RectF()
    private val detail = RectF()
    private val playButton = RectF()
    private val tiles = ArrayList<Pair<Mission, RectF>>()
    private val shopCards = ArrayList<RectF>()
    private val buyButtons = ArrayList<RectF>()

    fun open() {
        val p = progress ?: return
        // Start on the first mission without three stars that's unlocked.
        selected = Campaign.missions.firstOrNull { p.unlocked(it.number) && p.stars(it.number) < 3 }?.number ?: 1
        tab = Tab.MISSIONS
        openedAt = SystemClock.uptimeMillis()
        layoutParts()
        invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) = layoutParts()

    private fun layoutParts() {
        if (width == 0) return
        val pw = min(width - 24 * dp, 780 * dp)
        val ph = min(height - 20 * dp, 370 * dp)
        panel.set((width - pw) / 2, (height - ph) / 2, (width + pw) / 2, (height + ph) / 2)
        val pad = 14 * dp
        val top = panel.top + pad
        closeButton.set(panel.right - pad - 30 * dp, top, panel.right - pad, top + 30 * dp)
        text.textSize = 11 * dp
        val w1 = text.measureText("MISSIONS") + 24 * dp
        val w2 = text.measureText("UPGRADES") + 24 * dp
        tabMissions.set(panel.left + pad, top, panel.left + pad + w1, top + 30 * dp)
        tabUpgrades.set(tabMissions.right + 8 * dp, top, tabMissions.right + 8 * dp + w2, top + 30 * dp)

        val gridTop = top + 42 * dp
        detail.set(panel.left + pad, panel.bottom - pad - 70 * dp, panel.right - pad, panel.bottom - pad)
        playButton.set(detail.right - 130 * dp, detail.top + 12 * dp, detail.right - 12 * dp, detail.bottom - 12 * dp)

        tiles.clear()
        val cols = 8
        val rows = 3
        val gap = 7 * dp
        val areaW = panel.width() - pad * 2
        val areaH = detail.top - 10 * dp - gridTop
        val tw = (areaW - gap * (cols - 1)) / cols
        val th = (areaH - gap * (rows - 1)) / rows
        for ((i, m) in Campaign.missions.withIndex()) {
            val x = panel.left + pad + (i % cols) * (tw + gap)
            val y = gridTop + (i / cols) * (th + gap)
            tiles += m to RectF(x, y, x + tw, y + th)
        }

        shopCards.clear()
        buyButtons.clear()
        val sc = 3
        val sr = 2
        val sw = (areaW - gap * (sc - 1)) / sc
        val sh = (panel.bottom - pad - gridTop - gap * (sr - 1)) / sr
        for (i in Campaign.upgrades.indices) {
            val x = panel.left + pad + (i % sc) * (sw + gap)
            val y = gridTop + (i / sc) * (sh + gap)
            val card = RectF(x, y, x + sw, y + sh)
            shopCards += card
            buyButtons += RectF(card.right - 112 * dp, card.bottom - 44 * dp, card.right - 10 * dp, card.bottom - 10 * dp)
        }
    }

    // ---------------------------------------------------------------- drawing

    override fun onDraw(canvas: Canvas) {
        val p = progress ?: return
        if (panel.isEmpty) return
        val k = ((SystemClock.uptimeMillis() - openedAt) / 220f).coerceIn(0f, 1f)
        val pop = 0.9f + 0.1f * (1 - (1 - k) * (1 - k))
        val save = canvas.save()
        canvas.scale(pop, pop, panel.centerX(), panel.centerY())
        Neon.panel(canvas, panel, Neon.CYAN, dp, path, paint, glass = 0xF50A1024.toInt())

        tabButton(canvas, tabMissions, "MISSIONS", tab == Tab.MISSIONS)
        tabButton(canvas, tabUpgrades, "UPGRADES", tab == Tab.UPGRADES)

        // Coins and stars, top right.
        text.textSize = 13 * dp
        text.textAlign = Paint.Align.RIGHT
        var x = closeButton.left - 14 * dp
        val y = closeButton.centerY() + 5 * dp
        text.color = Neon.AMBER
        val coins = "◆ ${p.coins}"
        canvas.drawText(coins, x, y, text)
        x -= text.measureText(coins) + 18 * dp
        text.color = 0xFFFFE066.toInt()
        canvas.drawText("★ ${p.totalStars}/${Campaign.missions.size * 3}", x, y, text)
        text.textAlign = Paint.Align.LEFT
        drawClose(canvas)

        if (tab == Tab.MISSIONS) {
            for ((m, r) in tiles) drawTile(canvas, m, r, p)
            drawDetail(canvas, Campaign.mission(selected), p)
        } else {
            for ((i, u) in Campaign.upgrades.withIndex()) drawUpgrade(canvas, i, u, p)
        }
        canvas.restoreToCount(save)
        if (k < 1f) postInvalidateOnAnimation()
    }

    private fun tabButton(canvas: Canvas, r: RectF, label: String, on: Boolean) {
        Neon.chamfer(path, r, 7 * dp)
        paint.style = Paint.Style.FILL
        paint.color = if (on) Neon.withAlpha(Neon.CYAN, 0x55) else 0x1A00E5FF
        canvas.drawPath(path, paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1.2f * dp
        paint.color = if (on) Neon.CYAN else 0x5500E5FF
        canvas.drawPath(path, paint)
        paint.style = Paint.Style.FILL
        text.textSize = 11 * dp
        text.color = if (on) 0xFFFFFFFF.toInt() else 0xFF9FD8E8.toInt()
        canvas.drawText(label, r.centerX() - text.measureText(label) / 2, r.centerY() + 4 * dp, text)
    }

    private fun drawClose(canvas: Canvas) {
        paint.color = 0x33FF2BD6
        canvas.drawCircle(closeButton.centerX(), closeButton.centerY(), closeButton.width() / 2, paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1.2f * dp
        paint.color = Neon.MAGENTA
        canvas.drawCircle(closeButton.centerX(), closeButton.centerY(), closeButton.width() / 2, paint)
        paint.color = 0xFFFFFFFF.toInt()
        paint.strokeWidth = 2.5f * dp
        val c = 6 * dp
        canvas.drawLine(closeButton.centerX() - c, closeButton.centerY() - c, closeButton.centerX() + c, closeButton.centerY() + c, paint)
        canvas.drawLine(closeButton.centerX() + c, closeButton.centerY() - c, closeButton.centerX() - c, closeButton.centerY() + c, paint)
        paint.style = Paint.Style.FILL
    }

    private fun drawTile(canvas: Canvas, m: Mission, r: RectF, p: Progress) {
        val unlocked = p.unlocked(m.number)
        val stars = p.stars(m.number)
        val theme = MapTheme.forArena(m.arena)
        Neon.chamfer(path, r, 9 * dp)
        paint.style = Paint.Style.FILL
        paint.color = if (m.number == selected) 0xFF16305A.toInt() else 0xFF0E1A38.toInt()
        canvas.drawPath(path, paint)
        // Arena colour strip along the bottom.
        if (unlocked) {
            paint.color = Neon.withAlpha(theme.surface, 0xAA)
            canvas.drawRect(r.left + 2 * dp, r.bottom - 5 * dp, r.right - 2 * dp, r.bottom - 2 * dp, paint)
        }
        paint.style = Paint.Style.STROKE
        val accent = when {
            m.number == selected -> Neon.CYAN
            stars == 3 -> Neon.AMBER
            unlocked -> 0x8800E5FF.toInt()
            else -> 0x33FFFFFF
        }
        paint.strokeWidth = (if (m.number == selected) 2f else 1.2f) * dp
        paint.color = accent
        if (m.number == selected) paint.setShadowLayer(7 * dp, 0f, 0f, accent)
        canvas.drawPath(path, paint)
        paint.clearShadowLayer()
        paint.style = Paint.Style.FILL

        text.textAlign = Paint.Align.CENTER
        if (unlocked) {
            text.textSize = min(r.height() * 0.34f, 20 * dp)
            text.color = 0xFFFFFFFF.toInt()
            canvas.drawText(m.number.toString(), r.centerX(), r.top + r.height() * 0.48f, text)
            text.textSize = min(r.height() * 0.2f, 12 * dp)
            val starText = "★".repeat(stars) + "☆".repeat(3 - stars)
            text.color = if (stars > 0) 0xFFFFE066.toInt() else 0x66FFFFFF
            canvas.drawText(starText, r.centerX(), r.top + r.height() * 0.78f, text)
        } else {
            text.textSize = min(r.height() * 0.32f, 18 * dp)
            text.color = 0x66FFFFFF
            canvas.drawText("🔒", r.centerX(), r.centerY() + text.textSize * 0.35f, text)
        }
        text.textAlign = Paint.Align.LEFT
    }

    private fun drawDetail(canvas: Canvas, m: Mission, p: Progress) {
        Neon.panel(canvas, detail, Neon.MAGENTA, dp, path, paint, glass = 0x66000814, glow = false)
        val left = detail.left + 14 * dp
        text.textSize = 15 * dp
        text.color = 0xFFFFFFFF.toInt()
        val title = "${m.number.toString().padStart(2, '0')}  ${m.title.uppercase()}"
        canvas.drawText(title, left, detail.top + 24 * dp, text)
        text.textSize = 10 * dp
        text.color = Neon.CYAN
        val enemies = m.enemyWorms.joinToString(" + ")
        val info = "${m.arena.displayName.uppercase()}  ·  ${m.myWorms} VS $enemies  ·  ${m.difficulty.name}  ·  3★ IN ${m.parTurns} TURNS"
        val maxW = playButton.left - 12 * dp - left
        canvas.drawText(fit(info, maxW), left, detail.top + 42 * dp, text)
        body.textSize = 11.5f * dp
        canvas.drawText(fit(m.brief, maxW, body), left, detail.top + 60 * dp, body)

        val unlocked = p.unlocked(m.number)
        Neon.panel(canvas, playButton, if (unlocked) Neon.LIME else 0xFF5A6478.toInt(), dp, path, paint,
            glass = TerrainArt.mix(Neon.GLASS, if (unlocked) Neon.LIME else 0xFF5A6478.toInt(), 0.3f), glow = unlocked)
        text.textSize = 15 * dp
        text.color = 0xFFFFFFFF.toInt()
        text.textAlign = Paint.Align.CENTER
        canvas.drawText(if (unlocked) "PLAY ▶" else "LOCKED", playButton.centerX(), playButton.centerY() + 5.5f * dp, text)
        text.textAlign = Paint.Align.LEFT
    }

    private fun drawUpgrade(canvas: Canvas, i: Int, u: com.hamxanadeem.wigglewars.core.Upgrade, p: Progress) {
        val card = shopCards[i]
        val level = p.level(u)
        Neon.panel(canvas, card, if (level >= u.max) Neon.AMBER else Neon.CYAN, dp, path, paint, glass = 0xFF0E1A38.toInt(), glow = false)
        val icon = min(card.height() * 0.5f, 54 * dp)
        WeaponIcons.draw(canvas, u.weapon, card.left + 12 * dp + icon / 2, card.top + 12 * dp + icon / 2, icon)
        val tx = card.left + 22 * dp + icon
        text.textSize = 13 * dp
        text.color = 0xFFFFFFFF.toInt()
        canvas.drawText(fit(u.weapon.displayName.uppercase(), card.right - 10 * dp - tx), tx, card.top + 26 * dp, text)
        body.textSize = 10.5f * dp
        canvas.drawText(fit("+1 at the start of every battle", card.right - 10 * dp - tx, body), tx, card.top + 44 * dp, body)
        // Level pips.
        for (k in 0 until u.max) {
            val px = tx + k * 16 * dp
            rect.set(px, card.top + 52 * dp, px + 12 * dp, card.top + 58 * dp)
            paint.color = if (k < level) Neon.LIME else 0x2600E5FF
            canvas.drawRect(rect, paint)
        }
        val button = buyButtons[i]
        val maxed = level >= u.max
        val afford = p.coins >= u.price
        val accent = when {
            maxed -> Neon.AMBER
            afford -> Neon.LIME
            else -> 0xFF5A6478.toInt()
        }
        Neon.panel(canvas, button, accent, dp, path, paint, glass = TerrainArt.mix(Neon.GLASS, accent, 0.25f), glow = afford && !maxed)
        text.textSize = 12 * dp
        text.color = 0xFFFFFFFF.toInt()
        text.textAlign = Paint.Align.CENTER
        canvas.drawText(if (maxed) "MAX" else "◆ ${u.price}", button.centerX(), button.centerY() + 4.5f * dp, text)
        text.textAlign = Paint.Align.LEFT
    }

    private fun fit(s: String, max: Float, paint: TextPaint = text): String {
        if (paint.measureText(s) <= max) return s
        var end = s.length
        while (end > 1 && paint.measureText(s, 0, end) + paint.measureText("…") > max) end--
        return s.substring(0, end) + "…"
    }

    // ---------------------------------------------------------------- touch

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked != MotionEvent.ACTION_UP) return true
        performClick()
        val x = event.x
        val y = event.y
        val p = progress ?: return true
        when {
            !panel.contains(x, y) || closeButton.contains(x, y) -> listener?.onClose()
            tabMissions.contains(x, y) -> tab = Tab.MISSIONS
            tabUpgrades.contains(x, y) -> tab = Tab.UPGRADES
            tab == Tab.MISSIONS && playButton.contains(x, y) -> if (p.unlocked(selected)) listener?.onPlay(selected)
            tab == Tab.MISSIONS -> tiles.firstOrNull { it.second.contains(x, y) }?.let { (m, _) ->
                if (m.number == selected && p.unlocked(m.number)) listener?.onPlay(m.number) else selected = m.number
            }
            else -> buyButtons.indexOfFirst { it.contains(x, y) }.takeIf { it >= 0 }?.let { i ->
                listener?.onBought(p.buy(Campaign.upgrades[i]))
            }
        }
        invalidate()
        return true
    }

    override fun performClick(): Boolean = super.performClick()

}
