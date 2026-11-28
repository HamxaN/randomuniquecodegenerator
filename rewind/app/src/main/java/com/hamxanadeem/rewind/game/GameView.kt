package com.hamxanadeem.rewind.game

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.SystemClock
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import com.hamxanadeem.rewind.audio.Sfx
import com.hamxanadeem.rewind.core.Cell
import com.hamxanadeem.rewind.core.Event
import com.hamxanadeem.rewind.core.Game
import com.hamxanadeem.rewind.core.Level
import com.hamxanadeem.rewind.core.Rng
import com.hamxanadeem.rewind.core.Sim
import com.hamxanadeem.rewind.core.State
import com.hamxanadeem.rewind.core.TowerKind
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Draws and runs a [Game]: a fixed-step simulation on its own thread, smooth
 * rendering, effects and sound for each event, the ghosts of the future after a
 * rewind, and the rewind playback itself.
 */
class GameView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) :
    SurfaceView(context, attrs), SurfaceHolder.Callback, Runnable {

    interface Listener {
        /** Runs on the game thread; post to the UI. */
        fun onEvents(events: List<Event>)
        fun onTap(cell: Cell)
    }

    @Volatile var game: Game? = null
    @Volatile var listener: Listener? = null
    @Volatile var speed = 1
    @Volatile var paused = false
    @Volatile var selected: Cell? = null
    /** The tower kind being previewed for building, to show its range. */
    @Volatile var preview: TowerKind? = null
    /** No sound (the title-screen demo). */
    @Volatile var silent = false

    private val lock = Any()
    private var thread: Thread? = null
    @Volatile private var running = false

    // Rewind playback: states newest → oldest, shown over REWIND_MS.
    private var rewindFrames: List<State>? = null
    private var rewindStart = 0L
    private val rewindMs = 1100L

    private var cell = 1f
    private var ox = 0f
    private var oy = 0f
    private var shakeUntil = 0L
    private var leakFlashUntil = 0L

    private val effects = ArrayList<Fx>()
    private val decor = ArrayList<Triple<Float, Float, Int>>()

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Typeface.DEFAULT_BOLD; textAlign = Paint.Align.CENTER }
    private val roadPath = Path()
    private val rect = RectF()
    private var bgShader: Shader? = null

    init {
        holder.addCallback(this)
        isFocusable = true
    }

    private sealed class Fx(val born: Long, val life: Long) {
        class Ring(born: Long, val x: Float, val y: Float, val r: Float, val color: Int) : Fx(born, 380)
        class Bolt(born: Long, val pts: FloatArray) : Fx(born, 160)
        class Burst(born: Long, val x: Float, val y: Float, val color: Int, val seed: Long) : Fx(born, 450)
        class Label(born: Long, val x: kotlin.Float, val y: kotlin.Float, val label: String, val color: Int) : Fx(born, 800)
        class Flash(born: Long, val x: kotlin.Float, val y: kotlin.Float, val color: Int) : Fx(born, 90)
        class Tracer(born: Long, val x1: kotlin.Float, val y1: kotlin.Float, val x2: kotlin.Float, val y2: kotlin.Float) : Fx(born, 140)
    }

    /** Plays the rewind from [frames] (newest first); the game should already be rewound. */
    fun playRewind(frames: List<State>) {
        synchronized(lock) {
            rewindFrames = frames
            rewindStart = SystemClock.uptimeMillis()
            effects.clear()
        }
        if (!silent) Sfx.play(Sfx.REWIND)
    }

    val rewinding: Boolean get() = rewindFrames != null

    /** Runs [block] on the game while the simulation is paused between ticks (safe from the UI thread). */
    fun <T> withGame(block: (Game) -> T): T? = synchronized(lock) { game?.let(block) }

    /** Swaps in a new game (e.g. restart), resetting effects and the map layout. */
    fun replaceGame(g: Game) {
        synchronized(lock) {
            game = g
            effects.clear()
            rewindFrames = null
            roadPath.reset()
        }
    }

    // ---- Lifecycle -----------------------------------------------------------------

    override fun surfaceCreated(holder: SurfaceHolder) = start()

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        synchronized(lock) { layout(width, height) }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) = stop()

    private fun start() {
        if (running) return
        running = true
        thread = Thread(this, "game").also { it.start() }
    }

    private fun stop() {
        running = false
        thread?.let { t ->
            try {
                t.join(500)
            } catch (_: InterruptedException) {
            }
        }
        thread = null
    }

    private fun layout(w: Int, h: Int) {
        // Leave room for the HUD bar at the top.
        val top = h * 0.11f
        cell = min(w / Level.COLS.toFloat(), (h - top) / Level.ROWS.toFloat())
        ox = (w - cell * Level.COLS) / 2f
        oy = top + (h - top - cell * Level.ROWS) / 2f
        bgShader = LinearGradient(0f, 0f, 0f, h.toFloat(), 0xFF1E3A26.toInt(), 0xFF12251A.toInt(), Shader.TileMode.CLAMP)
        val g = game ?: return
        buildRoad(g.level)
        decor.clear()
        val rng = Rng(31L + g.level.index)
        repeat(26) {
            val c = Cell(rng.nextInt(Level.COLS), rng.nextInt(Level.ROWS))
            if (g.level.buildable(c)) decor += Triple(c.c + 0.2f + rng.nextDouble().toFloat() * 0.6f, c.r + 0.2f + rng.nextDouble().toFloat() * 0.6f, rng.nextInt(3))
        }
    }

    private fun buildRoad(level: Level) {
        roadPath.reset()
        level.points.forEachIndexed { i, p ->
            val x = sx(p.x)
            val y = sy(p.y)
            if (i == 0) roadPath.moveTo(x, y) else roadPath.lineTo(x, y)
        }
    }

    private fun sx(x: Double) = ox + (x * cell).toFloat()
    private fun sy(y: Double) = oy + (y * cell).toFloat()

    // ---- Loop ----------------------------------------------------------------------

    override fun run() {
        var last = SystemClock.uptimeMillis()
        var acc = 0.0
        while (running) {
            val now = SystemClock.uptimeMillis()
            val dt = (now - last).coerceAtMost(100)
            last = now
            val g = game
            if (g != null && !paused && rewindFrames == null) {
                acc += dt / 1000.0 * Sim.TICKS_PER_SECOND * speed
                var n = 0
                val events = ArrayList<Event>()
                synchronized(lock) {
                    while (acc >= 1.0 && n < 12) {
                        events += g.tick()
                        acc -= 1.0
                        n++
                    }
                }
                if (acc > 3) acc = 0.0
                if (events.isNotEmpty()) {
                    react(events, now)
                    listener?.onEvents(events)
                }
            } else {
                acc = 0.0
            }
            draw(now)
            val spent = SystemClock.uptimeMillis() - now
            if (spent < 16) {
                try {
                    Thread.sleep(16 - spent)
                } catch (_: InterruptedException) {
                }
            }
        }
    }

    private fun react(events: List<Event>, now: Long) {
        val sound = !silent
        synchronized(lock) {
            for (e in events) when (e) {
                is Event.Fired -> {
                    effects += Fx.Flash(now, sx(e.from.x), sy(e.from.y), Art.towerColor(e.kind))
                    if (e.kind == TowerKind.SNIPER) effects += Fx.Tracer(now, sx(e.from.x), sy(e.from.y), sx(e.to.x), sy(e.to.y))
                    if (sound) Sfx.play(when (e.kind) {
                        TowerKind.CANNON -> Sfx.CANNON
                        TowerKind.FROST -> Sfx.FROST
                        TowerKind.SNIPER -> Sfx.SNIPER
                        else -> Sfx.SHOOT
                    })
                }
                is Event.Zap -> {
                    val pts = FloatArray(e.points.size * 2)
                    e.points.forEachIndexed { i, p ->
                        pts[i * 2] = sx(p.x)
                        pts[i * 2 + 1] = sy(p.y)
                    }
                    effects += Fx.Bolt(now, pts)
                    if (sound) Sfx.play(Sfx.ZAP)
                }
                is Event.Boom -> {
                    effects += Fx.Ring(now, sx(e.at.x), sy(e.at.y), (e.radius * cell).toFloat(),
                        if (e.kind == TowerKind.FROST) 0xFFB3E5FC.toInt() else 0xFFFFAB40.toInt())
                    if (e.kind == TowerKind.CANNON) if (sound) Sfx.play(Sfx.BOOM)
                }
                is Event.Killed -> {
                    effects += Fx.Burst(now, sx(e.at.x), sy(e.at.y), Art.enemyColor(e.kind), now xor e.at.x.toBits())
                    effects += Fx.Label(now, sx(e.at.x), sy(e.at.y) - cell * 0.3f, "+${e.reward}", 0xFFFFD54F.toInt())
                    if (sound) Sfx.play(Sfx.POP)
                }
                is Event.Leaked -> {
                    leakFlashUntil = now + 350
                    shakeUntil = now + 220
                    if (sound) Sfx.play(Sfx.LEAK)
                }
                is Event.WaveCleared -> if (sound) Sfx.play(Sfx.COIN)
                Event.Won -> if (sound) Sfx.play(Sfx.WIN)
                Event.Lost -> if (sound) Sfx.play(Sfx.LOSE)
            }
            if (effects.size > 400) effects.subList(0, effects.size - 400).clear()
        }
    }

    // ---- Touch ---------------------------------------------------------------------

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_UP) {
            val c = ((event.x - ox) / cell).toInt()
            val r = ((event.y - oy) / cell).toInt()
            if (event.x >= ox && event.y >= oy && c < Level.COLS && r < Level.ROWS) {
                listener?.onTap(Cell(c, r))
                performClick()
            }
        }
        return true
    }

    override fun performClick(): Boolean = super.performClick()

    // ---- Drawing -------------------------------------------------------------------

    private fun draw(now: Long) {
        val h = holder
        val c: Canvas = try {
            h.lockHardwareCanvas()
        } catch (_: Exception) {
            null
        } ?: return
        try {
            synchronized(lock) { render(c, now) }
        } finally {
            try {
                h.unlockCanvasAndPost(c)
            } catch (_: Exception) {
            }
        }
    }

    private fun render(c: Canvas, now: Long) {
        val g = game
        fill.shader = bgShader
        c.drawRect(0f, 0f, c.width.toFloat(), c.height.toFloat(), fill)
        fill.shader = null
        if (g == null) return
        if (roadPath.isEmpty) layout(c.width, c.height)

        // Pick the state to show: the live one, or a frame of the rewind playback.
        var state = g.state
        var rewindK = -1f
        rewindFrames?.let { frames ->
            val k = ((now - rewindStart).toFloat() / rewindMs).coerceIn(0f, 1f)
            // Ease out: fast at first, settling on the moment we return to.
            val e = 1 - (1 - k) * (1 - k)
            state = frames[min(frames.size - 1, (e * (frames.size - 1)).toInt())]
            rewindK = k
            if (k >= 1f) rewindFrames = null
        }

        c.save()
        if (now < shakeUntil) c.translate(sin(now / 15f) * cell * 0.05f, 0f)
        drawMap(c, g.level, state)
        drawGhosts(c, g, state, now)
        drawTowers(c, state)
        drawEnemies(c, g.level, state, now)
        drawShots(c, state)
        drawSelection(c, g, state)
        drawEffects(c, now)
        c.restore()

        if (now < leakFlashUntil) {
            fill.color = Color.argb(((leakFlashUntil - now) / 350f * 90).toInt(), 255, 40, 40)
            c.drawRect(0f, 0f, c.width.toFloat(), c.height.toFloat(), fill)
        }
        if (rewindK >= 0f) drawRewindOverlay(c, rewindK, now)
    }

    private fun drawMap(c: Canvas, level: Level, s: State) {
        // Buildable tiles.
        fill.color = 0x14FFFFFF
        for (col in 0 until Level.COLS) for (row in 0 until Level.ROWS) {
            if (!level.buildable(Cell(col, row))) continue
            rect.set(ox + col * cell + cell * 0.06f, oy + row * cell + cell * 0.06f, ox + (col + 1) * cell - cell * 0.06f, oy + (row + 1) * cell - cell * 0.06f)
            c.drawRoundRect(rect, cell * 0.12f, cell * 0.12f, fill)
        }
        // Grass tufts and rocks.
        for ((x, y, kind) in decor) {
            val px = ox + x * cell
            val py = oy + y * cell
            if (kind == 0) {
                fill.color = 0x553C6E47
                c.drawCircle(px, py, cell * 0.08f, fill)
                c.drawCircle(px + cell * 0.09f, py + cell * 0.03f, cell * 0.06f, fill)
            } else {
                fill.color = 0x40B0BEC5
                c.drawOval(px - cell * 0.07f, py - cell * 0.04f, px + cell * 0.07f, py + cell * 0.04f, fill)
            }
        }
        // The road: edge, surface, and a faint dashed centre line.
        stroke.pathEffect = null
        stroke.color = 0xFF4E3B2A.toInt()
        stroke.strokeWidth = cell * 0.92f
        c.drawPath(roadPath, stroke)
        stroke.color = 0xFFA1845C.toInt()
        stroke.strokeWidth = cell * 0.78f
        c.drawPath(roadPath, stroke)
        stroke.color = 0x30FFFFFF
        stroke.strokeWidth = cell * 0.05f
        stroke.pathEffect = DashPathEffect(floatArrayOf(cell * 0.25f, cell * 0.25f), 0f)
        c.drawPath(roadPath, stroke)
        stroke.pathEffect = null
        // The crystal core enemies are trying to reach.
        val end = level.points.last()
        val ex = sx(end.x.coerceIn(0.5, Level.COLS - 0.5))
        val ey = sy(end.y.coerceIn(0.5, Level.ROWS - 0.5))
        val danger = 1f - s.lives / level.lives.toFloat()
        fill.shader = RadialGradient(ex, ey, cell * 0.9f, Color.argb(160, 120 + (135 * danger).toInt(), 180 - (140 * danger).toInt(), 255), Color.TRANSPARENT, Shader.TileMode.CLAMP)
        c.drawCircle(ex, ey, cell * 0.9f, fill)
        fill.shader = null
        fill.color = 0xFFE1F5FE.toInt()
        c.drawCircle(ex, ey, cell * 0.22f, fill)
        // Spawn portal.
        val st = level.points.first()
        val px = sx(st.x.coerceIn(0.3, Level.COLS - 0.3))
        val py = sy(st.y.coerceIn(0.3, Level.ROWS - 0.3))
        fill.shader = RadialGradient(px, py, cell * 0.7f, 0xAAB388FF.toInt(), Color.TRANSPARENT, Shader.TileMode.CLAMP)
        c.drawCircle(px, py, cell * 0.7f, fill)
        fill.shader = null
    }

    /** The future you came back from: faint purple echoes a second ahead, with trails. */
    private fun drawGhosts(c: Canvas, g: Game, s: State, now: Long) {
        val gh = g.ghosts ?: return
        if (!gh.active(s.tick)) return
        val ahead = min(gh.untilTick, s.tick + Sim.TICKS_PER_SECOND)
        stroke.color = 0x55CE93D8
        stroke.strokeWidth = cell * 0.06f
        val trailEnd = min(gh.untilTick, s.tick + Sim.TICKS_PER_SECOND * 2)
        val nowDots = gh.at(ahead).associateBy { it.id }
        for (d in gh.at(trailEnd)) {
            val a = nowDots[d.id] ?: continue
            c.drawLine(sx(a.x), sy(a.y), sx(d.x), sy(d.y), stroke)
        }
        val pulse = 0.35f + 0.1f * sin(now / 160f)
        for (d in nowDots.values) {
            Art.enemy(c, d.kind, sx(d.x), sy(d.y), cell, now / 1000f, pulse, tint = 0xFFCE93D8.toInt())
        }
        if (gh.leaked) {
            val end = g.level.points.last()
            val ex = sx(end.x.coerceIn(0.5, Level.COLS - 0.5))
            val ey = sy(end.y.coerceIn(0.5, Level.ROWS - 0.5))
            text.textSize = cell * 0.36f
            text.color = 0xFFFF8A80.toInt()
            val label = "−${gh.livesLost} ♥"
            c.drawText(label, ex.coerceIn(cell, Level.COLS * cell + ox - cell), ey - cell * 0.6f, text)
        }
    }

    private fun drawTowers(c: Canvas, s: State) {
        for (t in s.towers) {
            val cc = t.cell.center
            val glow = if (t.cooldown > t.kind.cooldownAt(t.level) - 0.12) 0.8f else 0f
            Art.tower(c, t.kind, t.level, sx(cc.x), sy(cc.y), cell, t.aim.toFloat(), glow)
        }
    }

    private fun drawEnemies(c: Canvas, level: Level, s: State, now: Long) {
        for (e in s.enemies) {
            val p = level.at(e.dist)
            val x = sx(p.x)
            val y = sy(p.y)
            Art.enemy(c, e.kind, x, y, cell, now / 1000f + e.id * 0.37f, 1f, slowed = e.slowLeft > 0)
            if (e.hp < e.maxHp) {
                val w = cell * max(0.45f, e.kind.radius.toFloat() * 1.6f)
                val top = y - e.kind.radius.toFloat() * cell - cell * 0.18f
                fill.color = 0xAA000000.toInt()
                rect.set(x - w / 2, top, x + w / 2, top + cell * 0.07f)
                c.drawRect(rect, fill)
                val k = (e.hp / e.maxHp).toFloat().coerceIn(0f, 1f)
                fill.color = if (k > 0.5f) 0xFF66BB6A.toInt() else if (k > 0.25f) 0xFFFFCA28.toInt() else 0xFFEF5350.toInt()
                rect.set(x - w / 2, top, x - w / 2 + w * k, top + cell * 0.07f)
                c.drawRect(rect, fill)
            }
        }
    }

    private fun drawShots(c: Canvas, s: State) {
        for (sh in s.shots) {
            val x = sx(sh.x)
            val y = sy(sh.y)
            when (sh.kind) {
                TowerKind.CANNON -> {
                    fill.color = 0xFF212121.toInt()
                    c.drawCircle(x, y, cell * 0.1f, fill)
                }
                TowerKind.FROST -> {
                    fill.color = 0xFFE1F5FE.toInt()
                    c.drawCircle(x, y, cell * 0.08f, fill)
                }
                else -> {
                    fill.color = Art.towerColor(sh.kind)
                    c.drawCircle(x, y, cell * 0.06f, fill)
                }
            }
        }
    }

    private fun drawSelection(c: Canvas, g: Game, s: State) {
        val cellSel = selected ?: return
        val cc = cellSel.center
        val x = sx(cc.x)
        val y = sy(cc.y)
        val t = s.towerAt(cellSel)
        val range = t?.kind?.rangeAt(t.level) ?: preview?.range
        if (range != null) {
            fill.color = 0x22FFFFFF
            c.drawCircle(x, y, (range * cell).toFloat(), fill)
            stroke.color = 0x88FFFFFF.toInt()
            stroke.strokeWidth = cell * 0.04f
            c.drawCircle(x, y, (range * cell).toFloat(), stroke)
        }
        stroke.color = if (t != null || g.level.buildable(cellSel)) 0xFFFFFFFF.toInt() else 0xFFFF5252.toInt()
        stroke.strokeWidth = cell * 0.05f
        rect.set(ox + cellSel.c * cell + 2, oy + cellSel.r * cell + 2, ox + (cellSel.c + 1) * cell - 2, oy + (cellSel.r + 1) * cell - 2)
        c.drawRoundRect(rect, cell * 0.12f, cell * 0.12f, stroke)
        if (t == null) preview?.let { Art.tower(c, it, 1, x, y, cell, -Math.PI.toFloat() / 2) }
    }

    private fun drawEffects(c: Canvas, now: Long) {
        val it = effects.iterator()
        while (it.hasNext()) {
            val fx = it.next()
            val k = (now - fx.born).toFloat() / fx.life
            if (k >= 1f) {
                it.remove()
                continue
            }
            val a = ((1 - k) * 255).toInt()
            when (fx) {
                is Fx.Ring -> {
                    stroke.color = (fx.color and 0x00FFFFFF) or (a shl 24)
                    stroke.strokeWidth = cell * 0.08f * (1 - k) + 1
                    c.drawCircle(fx.x, fx.y, fx.r * (0.4f + 0.6f * k), stroke)
                }
                is Fx.Bolt -> {
                    stroke.color = Color.argb(a, 225, 200, 255)
                    stroke.strokeWidth = cell * 0.07f
                    var i = 0
                    while (i + 3 < fx.pts.size) {
                        // A jagged line between each pair of points.
                        val x1 = fx.pts[i]
                        val y1 = fx.pts[i + 1]
                        val x2 = fx.pts[i + 2]
                        val y2 = fx.pts[i + 3]
                        val mx = (x1 + x2) / 2 + sin(now / 7f + i) * cell * 0.15f
                        val my = (y1 + y2) / 2 + sin(now / 9f + i) * cell * 0.15f
                        c.drawLine(x1, y1, mx, my, stroke)
                        c.drawLine(mx, my, x2, y2, stroke)
                        i += 2
                    }
                }
                is Fx.Burst -> {
                    val rng = Rng(fx.seed)
                    fill.color = (fx.color and 0x00FFFFFF) or (a shl 24)
                    repeat(9) {
                        val ang = rng.nextDouble() * Math.PI * 2
                        val d = cell * (0.15f + 0.6f * k) * (0.6f + rng.nextDouble().toFloat() * 0.6f)
                        c.drawCircle(fx.x + (kotlin.math.cos(ang) * d).toFloat(), fx.y + (kotlin.math.sin(ang) * d).toFloat(), cell * 0.06f * (1 - k) + 1, fill)
                    }
                }
                is Fx.Label -> {
                    text.textSize = cell * 0.28f
                    text.color = (fx.color and 0x00FFFFFF) or (a shl 24)
                    c.drawText(fx.label, fx.x, fx.y - cell * 0.5f * k, text)
                }
                is Fx.Flash -> {
                    fill.color = (fx.color and 0x00FFFFFF) or ((a / 2) shl 24)
                    c.drawCircle(fx.x, fx.y, cell * 0.32f, fill)
                }
                is Fx.Tracer -> {
                    stroke.color = Color.argb(a, 230, 255, 200)
                    stroke.strokeWidth = cell * 0.04f
                    c.drawLine(fx.x1, fx.y1, fx.x2, fx.y2, stroke)
                }
            }
        }
    }

    private fun drawRewindOverlay(c: Canvas, k: Float, now: Long) {
        val w = c.width.toFloat()
        val h = c.height.toFloat()
        val a = ((1 - k) * 110 + 30).toInt()
        fill.color = Color.argb(a, 90, 40, 160)
        c.drawRect(0f, 0f, w, h, fill)
        // Scan lines sweeping up, like a tape rewinding.
        stroke.color = Color.argb(60, 255, 255, 255)
        stroke.strokeWidth = 2f
        val off = (now / 3 % 24).toFloat()
        var y = h - off
        while (y > 0) {
            c.drawLine(0f, y, w, y, stroke)
            y -= 24f
        }
        text.textSize = h * 0.09f
        text.color = Color.argb(230, 255, 255, 255)
        c.drawText("◀◀  REWIND", w / 2, h * 0.5f, text)
    }
}
