package com.hamxanadeem.wigglewars.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.os.SystemClock
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.hamxanadeem.wigglewars.core.CrateKind
import com.hamxanadeem.wigglewars.core.FireMode
import com.hamxanadeem.wigglewars.core.GameEvent
import com.hamxanadeem.wigglewars.core.Match
import com.hamxanadeem.wigglewars.core.Phase
import com.hamxanadeem.wigglewars.core.Weapon
import com.hamxanadeem.wigglewars.core.Worm
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Draws the battle and turns touches into aiming. The camera follows whatever is
 * flying, or the active worm; two fingers pan and zoom.
 */
class BattleView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    interface Listener {
        fun onAim(facing: Int, aim: Double)
        fun onTarget(x: Double, y: Double)
    }

    var listener: Listener? = null
    /** True while a human controls the active worm. */
    var humanTurn = false
    /** 0..1 while the fire button is held. */
    var charge = -1f
    /** Space at the top taken by the status bar. */
    var topInset = 0
    /** Space taken by the camera cutout or bars on the other edges. */
    var leftInset = 0
    var rightInset = 0
    var bottomInset = 0

    private var match: Match? = null
    private var art: TerrainArt? = null
    private var theme = MapTheme.grassland
    private val dp = resources.displayMetrics.density
    private val random = Random(SystemClock.uptimeMillis())
    private val wormPainter = WormPainter()

    // Camera: world position of the screen's top-left corner, and pixels per world unit.
    private var camX = 0f
    private var camY = 0f
    private var scale = 1f
    private var zoom = 1f
    private var manualUntil = 0L
    private var shake = 0f

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val backdropPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bitmapPaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val rect = RectF()
    private val path = Path()
    private var skyShader: Shader? = null
    private val black = Neon.bold(context)
    private val textFill = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = black; textAlign = Paint.Align.CENTER }
    private val textStroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = black
        textAlign = Paint.Align.CENTER
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
        color = 0xFF1A1A1A.toInt()
    }

    // ---- Effects (world coordinates) ----
    private class Fireball(val x: Float, val y: Float, val r: Float, val start: Long)
    private class FloatText(val text: String, val color: Int, val x: Float, val y: Float, val start: Long, val big: Boolean)
    private class Tracer(val x0: Float, val y0: Float, val x1: Float, val y1: Float, val start: Long)
    private class Grave(val x: Float, var y: Float)

    private val fireballs = ArrayList<Fireball>()
    private val texts = ArrayList<FloatText>()
    private val tracers = ArrayList<Tracer>()
    private val graves = ArrayList<Grave>()
    private val hurtAt = HashMap<Int, Long>()
    private var introAt = 0L
    private val miniMap = RectF()
    private var banner: String? = null
    private var subBanner: String? = null
    private var bannerColor = 0
    private var bannerAt = 0L

    private val px = FloatArray(MAX_PARTICLES)
    private val py = FloatArray(MAX_PARTICLES)
    private val pvx = FloatArray(MAX_PARTICLES)
    private val pvy = FloatArray(MAX_PARTICLES)
    private val pLife = FloatArray(MAX_PARTICLES)
    private val pMax = FloatArray(MAX_PARTICLES)
    private val pSize = FloatArray(MAX_PARTICLES)
    private val pColor = IntArray(MAX_PARTICLES)
    private val pKind = ByteArray(MAX_PARTICLES)
    private var particles = 0
    private var lastFrame = 0L

    fun start(newMatch: Match) {
        match = newMatch
        theme = MapTheme.forArena(newMatch.arena)
        art?.bitmap?.recycle()
        art = TerrainArt(newMatch.terrain, theme, newMatch.arena.backdrop)
        introAt = 0L
        backdropPaint.color = TerrainArt.shade(theme.soilDark, 0.5f)
        fireballs.clear()
        texts.clear()
        tracers.clear()
        graves.clear()
        particles = 0
        zoom = 1f
        skyShader = null
        val w = newMatch.activeWorm
        updateScale()
        camX = (w.x - width / scale / 2).toFloat()
        camY = (w.y - height / scale / 2).toFloat()
        postInvalidateOnAnimation()
    }

    fun showBanner(text: String, color: Int, sub: String? = null) {
        subBanner = sub
        banner = text
        bannerColor = color
        bannerAt = SystemClock.uptimeMillis()
    }

    private fun updateScale() {
        if (width == 0) return
        // About 620 world units across at normal zoom.
        scale = width / 620f * zoom
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        updateScale()
        skyShader = null
    }

    private fun toWorldX(sx: Float) = camX + sx / scale
    private fun toWorldY(sy: Float) = camY + sy / scale

    // ---------------------------------------------------------------- events

    fun onEvents(events: List<GameEvent>) {
        val m = match ?: return
        val now = SystemClock.uptimeMillis()
        for (e in events) {
            when (e) {
                is GameEvent.Explosion -> {
                    e.area?.let { art?.blast(it, e.x, e.y, e.radius) }
                    val x = e.x.toFloat()
                    val y = e.y.toFloat()
                    val r = e.radius.toFloat()
                    fireballs += Fireball(x, y, r, now)
                    repeat((r * 0.8f).toInt()) { spawn(x, y, r * 5f, 0, debrisColor(), 0.9f, 1.5f + random.nextFloat() * 2f) }
                    repeat((r * 0.5f).toInt()) { spawn(x, y, r * 3f, 1, if (random.nextBoolean()) 0xFFFFB300.toInt() else 0xFFFF5722.toInt(), 0.5f, 2f + random.nextFloat() * 2f) }
                    repeat((r / 4).toInt() + 3) { spawn(x, y, r * 0.8f, 2, 0xFF757575.toInt(), 1.6f, 6f + random.nextFloat() * 6f) }
                    shake = max(shake, r * 0.5f * dp)
                    if (r >= 40) addText(BIG_WORDS[random.nextInt(BIG_WORDS.size)], 0xFFFFEB3B.toInt(), x, y - r, big = true)
                }
                is GameEvent.Damaged -> {
                    val w = m.worms[e.worm]
                    hurtAt[e.worm] = now
                    addText("-${e.amount}", TeamColors.colors[w.team], w.x.toFloat(), w.y.toFloat() - 26, big = false)
                }
                is GameEvent.Died -> {
                    val w = m.worms[e.worm]
                    graves += Grave(w.x.toFloat(), w.y.toFloat() + Worm.RADIUS.toFloat())
                    addText("R.I.P. ${w.name}", 0xFFFFFFFF.toInt(), w.x.toFloat(), w.y.toFloat() - 30, big = false)
                }
                is GameEvent.Drowned -> addText("Glub glub!", 0xFF81D4FA.toInt(), m.worms[e.worm].x.toFloat(), m.terrain.waterY - 30f, big = false)
                is GameEvent.Splash -> repeat(20) {
                    spawn(e.x.toFloat(), m.terrain.waterY.toFloat(), 0f, 3, 0xFFB3E5FC.toInt(), 0.9f, 1.5f + random.nextFloat() * 2f)
                }
                is GameEvent.ShotgunBlast -> tracers += Tracer(e.fromX.toFloat(), e.fromY.toFloat(), e.toX.toFloat(), e.toY.toFloat(), now)
                is GameEvent.BatSwing -> if (e.hit) {
                    val w = m.worms[e.worm]
                    addText("WHACK!", 0xFFFFFFFF.toInt(), w.x.toFloat() + w.facing * 20, w.y.toFloat() - 20, big = true)
                    shake = max(shake, 8 * dp)
                }
                is GameEvent.Teleported -> {
                    val w = m.worms[e.worm]
                    repeat(30) { spawn(w.x.toFloat(), w.y.toFloat(), 120f, 1, 0xFFE1BEE7.toInt(), 0.7f, 1.5f) }
                }
                is GameEvent.CrateCollected -> {
                    val w = m.worms[e.worm]
                    val label = if (e.crate.kind == CrateKind.HEALTH) "+${Match.CRATE_HEALTH} ❤" else "+1 ${e.crate.weapon!!.displayName}"
                    addText(label, 0xFF69F0AE.toInt(), w.x.toFloat(), w.y.toFloat() - 30, big = false)
                }
                is GameEvent.Built -> {
                    art?.build(e.area)
                    val cx = (e.area.left + e.area.right) / 2f
                    val cy = (e.area.top + e.area.bottom) / 2f
                    repeat(18) { spawn(cx, cy, 90f, 1, 0xFFFFD180.toInt(), 0.5f, 1.4f) }
                    shake = max(shake, 3 * dp)
                }
                is GameEvent.Fired -> if (e.weapon == Weapon.BAZOOKA || e.weapon == Weapon.SHOTGUN || e.weapon == Weapon.UZI || e.weapon == Weapon.SNIPER) {
                    val w = m.worms[e.worm]
                    repeat(6) { spawn((w.x + w.aimX * 14).toFloat(), (w.y + w.aimY * 14).toFloat(), 20f, 2, 0xFFBDBDBD.toInt(), 0.8f, 4f) }
                }
                else -> Unit
            }
        }
    }

    private fun debrisColor() = if (random.nextInt(3) == 0) theme.surfaceDark else theme.soil

    private fun spawn(x: Float, y: Float, speed: Float, kind: Int, color: Int, life: Float, size: Float) {
        if (particles >= MAX_PARTICLES) return
        val i = particles++
        val a = random.nextFloat() * 6.2832f
        val s = speed * (0.3f + random.nextFloat() * 0.7f)
        px[i] = x
        py[i] = y
        pvx[i] = cos(a) * s
        pvy[i] = sin(a) * s - (if (kind == 3) 180f + random.nextFloat() * 120f else speed * 0.4f)
        if (kind == 4) {
            pvx[i] = (random.nextFloat() - 0.5f) * 20f
            pvy[i] = -20f - random.nextFloat() * 30f
        }
        if (kind == 3) pvx[i] *= 0.3f
        pLife[i] = life * (0.6f + random.nextFloat() * 0.6f)
        pMax[i] = pLife[i]
        pSize[i] = size
        pColor[i] = color
        pKind[i] = kind.toByte()
    }

    private fun addText(text: String, color: Int, x: Float, y: Float, big: Boolean) {
        texts += FloatText(text, color, x, y, SystemClock.uptimeMillis(), big)
    }

    // ---------------------------------------------------------------- drawing

    override fun onDraw(canvas: Canvas) {
        val m = match ?: return
        val art = art ?: return
        val now = SystemClock.uptimeMillis()
        val dt = if (lastFrame == 0L) 0.016f else ((now - lastFrame) / 1000f).coerceIn(0f, 0.05f)
        lastFrame = now
        val t = now / 1000f
        updateCamera(m, dt)

        drawSky(canvas, m, t)
        val save = canvas.save()
        if (shake > 0.5f) {
            canvas.translate((random.nextFloat() - 0.5f) * shake, (random.nextFloat() - 0.5f) * shake)
            shake *= 0.85f
        } else {
            shake = 0f
        }
        canvas.scale(scale, scale)
        canvas.translate(-camX, -camY)

        drawMountains(canvas, m)
        canvas.drawPath(art.backdrop, backdropPaint)
        canvas.drawBitmap(art.bitmap, 0f, 0f, bitmapPaint)
        for (g in graves) wormPainter.grave(canvas, g.x, g.y)
        drawCrates(canvas, m, t)
        drawWorms(canvas, m, t, now)
        drawProjectiles(canvas, m, t)
        drawTracers(canvas, now)
        drawFireballs(canvas, now)
        drawParticles(canvas, dt, m)
        drawWater(canvas, m, t)
        drawAim(canvas, m)
        drawTexts(canvas, now)
        canvas.restoreToCount(save)

        drawHud(canvas, m, now)
        postInvalidateOnAnimation()
    }

    private fun updateCamera(m: Match, dt: Float) {
        updateScale()
        val viewW = width / scale
        val viewH = height / scale
        if (SystemClock.uptimeMillis() > manualUntil) {
            val p = m.projectiles.firstOrNull { !it.idle }
            val (tx, ty) = if (p != null) p.x.toFloat() to p.y.toFloat() else m.activeWorm.x.toFloat() to m.activeWorm.y.toFloat()
            val k = min(1f, dt * if (p != null) 6f else 3f)
            camX += (tx - viewW / 2 - camX) * k
            camY += (ty - viewH * 0.55f - camY) * k
        }
        camX = camX.coerceIn(-viewW * 0.3f, m.terrain.width - viewW * 0.7f)
        camY = camY.coerceIn(-viewH * 0.6f, m.terrain.height - viewH)
    }

    private fun drawSky(canvas: Canvas, m: Match, t: Float) {
        if (skyShader == null) skyShader = LinearGradient(0f, 0f, 0f, height.toFloat(), theme.skyTop, theme.skyBottom, Shader.TileMode.CLAMP)
        paint.shader = skyShader
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        paint.shader = null
        if (theme.stars) drawStars(canvas, t)
        if (theme.lava) {
            // Embers drifting up from the lava.
            if (random.nextFloat() < 0.5f) {
                val wx = camX + random.nextFloat() * width / scale
                spawn(wx, m.terrain.waterY.toFloat(), 0f, 4, if (random.nextBoolean()) 0xFFFFAB40.toInt() else 0xFFFF5722.toInt(), 2.2f, 1f + random.nextFloat() * 1.5f)
            }
        }
        if (!theme.clouds) return
        // Clouds drift with the wind, which shows its strength at a glance.
        paint.color = 0xCCFFFFFF.toInt()
        val drift = (t * (8 + m.wind * 70)).toFloat()
        for (i in 0 until 7) {
            val span = width + 300 * dp
            val x = ((i * 397f + drift * (0.6f + i * 0.12f) * dp - camX * scale * 0.1f) % span + span) % span - 150 * dp
            val y = height * (0.08f + (i % 3) * 0.09f)
            val r = (18 + (i % 3) * 8) * dp
            canvas.drawCircle(x, y, r, paint)
            canvas.drawCircle(x + r, y - r * 0.4f, r * 1.2f, paint)
            canvas.drawCircle(x + r * 2.1f, y, r * 0.9f, paint)
        }
    }

    private fun drawStars(canvas: Canvas, t: Float) {
        for (i in 0 until 70) {
            val h1 = TerrainArt.hash(i, 7)
            val h2 = TerrainArt.hash(i, 13)
            val x = ((h1 % 10000) / 10000f * (width + 200 * dp) - camX * scale * 0.05f).mod(width + 200 * dp) - 100 * dp
            val y = (h2 % 10000) / 10000f * height * 0.75f
            val twinkle = 0.6f + 0.4f * sin(t * (1.5f + i % 5) + i)
            paint.color = 0xFFFFFFFF.toInt()
            paint.alpha = (255 * twinkle).toInt()
            canvas.drawCircle(x, y, (0.8f + (h1 % 3) * 0.5f) * dp, paint)
        }
        paint.alpha = 255
        // The Earth hangs in the sky.
        val ex = width * 0.62f - camX * scale * 0.03f
        val ey = height * 0.2f
        val er = 26 * dp
        paint.color = 0xFF1E88E5.toInt()
        canvas.drawCircle(ex, ey, er, paint)
        paint.color = 0xFF43A047.toInt()
        canvas.drawCircle(ex - er * 0.3f, ey - er * 0.2f, er * 0.45f, paint)
        canvas.drawCircle(ex + er * 0.4f, ey + er * 0.35f, er * 0.3f, paint)
        paint.color = 0x55000000
        canvas.drawCircle(ex + er * 0.35f, ey, er * 0.95f, paint)
    }

    private fun drawMountains(canvas: Canvas, m: Match) {
        when (theme.scenery) {
            Scenery.MOUNTAINS -> Unit
            Scenery.DUNES -> return drawDunes(canvas, m)
            Scenery.STALACTITES -> return drawCaveWall(canvas, m)
            Scenery.NONE -> return
        }
        // Distant hills in world space, slightly parallaxed.
        paint.color = theme.mountains
        val baseY = m.terrain.height * 0.62f
        path.reset()
        path.moveTo(-600f, m.terrain.height.toFloat())
        var x = -600f
        val offset = camX * 0.35f
        var i = 0
        while (x < m.terrain.width + 600f) {
            val peak = 120f + ((i * 7919) % 7) * 28f
            path.lineTo(x + offset, baseY)
            path.lineTo(x + offset + 110f, baseY - peak)
            x += 220f
            i++
        }
        path.lineTo(x + offset, baseY)
        path.lineTo(x + offset, m.terrain.height.toFloat())
        path.close()
        canvas.drawPath(path, paint)
    }

    private fun drawDunes(canvas: Canvas, m: Match) {
        paint.color = theme.mountains
        val baseY = m.terrain.height * 0.6f
        val offset = camX * 0.35f
        path.reset()
        path.moveTo(-600f + offset, m.terrain.height.toFloat())
        var x = -600f
        var i = 0
        while (x < m.terrain.width + 600f) {
            val rise = 70f + ((i * 7919) % 5) * 25f
            path.quadTo(x + offset + 120f, baseY - rise * 2, x + offset + 240f, baseY)
            x += 240f
            i++
        }
        path.lineTo(x + offset, m.terrain.height.toFloat())
        path.close()
        canvas.drawPath(path, paint)
    }

    private fun drawCaveWall(canvas: Canvas, m: Match) {
        // Glowing crystals far back in the dark.
        val offset = camX * 0.3f
        for (i in 0 until 40) {
            val h = TerrainArt.hash(i, 3)
            val x = (h % 2400) - 200f + offset
            val y = 200f + (TerrainArt.hash(i, 9) % 500)
            val size = 6f + (h % 7) * 2f
            paint.color = if (i % 3 == 0) 0x6680DEEA else 0x55CE93D8
            path.reset()
            path.moveTo(x, y - size * 1.6f)
            path.lineTo(x + size * 0.6f, y)
            path.lineTo(x, y + size * 0.4f)
            path.lineTo(x - size * 0.6f, y)
            path.close()
            canvas.drawPath(path, paint)
        }
    }

    private fun drawWater(canvas: Canvas, m: Match, t: Float) {
        val waterY = m.terrain.waterY.toFloat()
        val left = camX - 50
        val right = camX + width / scale + 50
        for (layer in 0..2) {
            val base = if (theme.lava) TerrainArt.mix(theme.water, 0xFFFFD54F.toInt(), (0.5f + 0.5f * sin(t * 2f + layer)) * 0.35f) else theme.water
            paint.color = (base and 0x00FFFFFF) or ((if (theme.lava) 220 + layer * 15 else 150 + layer * 35) shl 24)
            path.reset()
            path.moveTo(left, m.terrain.height + 400f)
            var x = left
            while (x <= right) {
                val y = waterY + layer * 10 + sin(x * 0.03f + t * (1.5f + layer * 0.4f) + layer) * 4f
                path.lineTo(x, y)
                x += 12f
            }
            path.lineTo(right, m.terrain.height + 400f)
            path.close()
            canvas.drawPath(path, paint)
        }
    }

    private fun drawWorms(canvas: Canvas, m: Match, t: Float, now: Long) {
        for (w in m.worms) {
            if (!w.alive) continue
            val active = w.id == m.activeWormId && m.phase != Phase.GAME_OVER
            val weapon = if (active && m.phase == Phase.AIM) m.selected else null
            val hurt = (hurtAt[w.id]?.let { now - it < 160 }) == true
            wormPainter.draw(canvas, w, w.team, t + w.id, active, weapon, hurt)
            // Health label.
            val label = w.health.toString()
            textFill.textSize = 9f
            val tw = textFill.measureText(label) + 8
            val ly = w.y.toFloat() - 20
            rect.set(w.x.toFloat() - tw / 2, ly - 9, w.x.toFloat() + tw / 2, ly + 2.5f)
            paint.color = TeamColors.colors[w.team]
            canvas.drawRoundRect(rect, 5.5f, 5.5f, paint)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 0.9f
            paint.color = 0xCCFFFFFF.toInt()
            canvas.drawRoundRect(rect, 5.5f, 5.5f, paint)
            paint.style = Paint.Style.FILL
            textFill.color = if (w.team == 3) 0xFF333333.toInt() else 0xFFFFFFFF.toInt()
            canvas.drawText(label, w.x.toFloat(), ly, textFill)
            if (active) {
                // Bouncing arrow over the active worm, and its name.
                val bob = sin(t * 6f) * 3f
                paint.color = 0xFFFFFFFF.toInt()
                path.reset()
                val ay = ly - 16 + bob
                path.moveTo(w.x.toFloat() - 5, ay - 6); path.lineTo(w.x.toFloat() + 5, ay - 6); path.lineTo(w.x.toFloat(), ay); path.close()
                canvas.drawPath(path, paint)
                textFill.textSize = 8f
                textFill.color = 0xFFFFFFFF.toInt()
                textStroke.textSize = 8f
                textStroke.strokeWidth = 2f
                canvas.drawText(w.name, w.x.toFloat(), ay - 9, textStroke)
                canvas.drawText(w.name, w.x.toFloat(), ay - 9, textFill)
            }
        }
    }

    private fun drawAim(canvas: Canvas, m: Match) {
        if (m.phase != Phase.AIM) return
        val w = m.activeWorm
        if (!w.alive || m.selected.mode == FireMode.TARGET || m.selected.mode == FireMode.DROP) return
        val cx = (w.x + w.aimX * 42).toFloat()
        val cy = (w.y + w.aimY * 42).toFloat()
        // Neon reticle with a slowly turning outer ring.
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1.2f
        paint.color = Neon.CYAN
        paint.setShadowLayer(3f, 0f, 0f, Neon.CYAN)
        canvas.drawCircle(cx, cy, 4f, paint)
        val spin = (SystemClock.uptimeMillis() % 4000) / 4000f * 360f
        rect.set(cx - 8, cy - 8, cx + 8, cy + 8)
        for (q in 0 until 4) canvas.drawArc(rect, spin + q * 90f, 45f, false, paint)
        paint.clearShadowLayer()
        paint.style = Paint.Style.FILL
        paint.color = Neon.MAGENTA
        canvas.drawCircle(cx, cy, 1.2f, paint)
        // Power arc grows from the worm toward the crosshair while charging.
        if (charge >= 0f && m.selected.mode == FireMode.POWER) {
            val steps = 14
            for (i in 0 until (steps * charge).toInt().coerceAtLeast(1)) {
                val k = (i + 1f) / steps
                val d = 10 + k * 34
                paint.color = TeamColors.mixHeat(k)
                canvas.drawCircle((w.x + w.aimX * d).toFloat(), (w.y + w.aimY * d).toFloat(), 1.2f + k * 2.2f, paint)
            }
        }
    }

    private fun drawProjectiles(canvas: Canvas, m: Match, t: Float) {
        for (p in m.projectiles) {
            val x = p.x.toFloat()
            val y = p.y.toFloat()
            val angle = Math.toDegrees(atan2(p.vy, p.vx)).toFloat()
            val save = canvas.save()
            canvas.translate(x, y)
            when (p.weapon) {
                Weapon.BAZOOKA, Weapon.AIRSTRIKE -> {
                    canvas.rotate(angle)
                    paint.color = 0xFF616161.toInt()
                    canvas.drawRoundRect(-6f, -2f, 5f, 2f, 2f, 2f, paint)
                    paint.color = 0xFFD32F2F.toInt()
                    canvas.drawCircle(5f, 0f, 2f, paint)
                    spawn(x - cos(Math.toRadians(angle.toDouble())).toFloat() * 7, y - sin(Math.toRadians(angle.toDouble())).toFloat() * 7, 8f, 1, 0xFFFFA000.toInt(), 0.25f, 2f)
                }
                Weapon.GRENADE -> grenade(canvas, 0xFF2E7D32.toInt(), t)
                Weapon.CLUSTER -> grenade(canvas, if (p.spec.childSpec != null) 0xFFC62828.toInt() else 0xFF424242.toInt(), t)
                Weapon.BANANA -> {
                    canvas.rotate(t * 720f)
                    paint.color = 0xFFFFEB3B.toInt()
                    rect.set(-5f, -5f, 5f, 5f)
                    canvas.drawArc(rect, -90f, 180f, true, paint)
                    paint.color = 0xFF6D4C41.toInt()
                    canvas.drawCircle(0f, -4.5f, 1f, paint)
                }
                Weapon.DYNAMITE -> {
                    paint.color = 0xFFD32F2F.toInt()
                    canvas.drawRect(-2.5f, -6f, 2.5f, 6f, paint)
                    // Fizzing fuse.
                    spawn(x, y - 8, 30f, 1, 0xFFFFEB3B.toInt(), 0.2f, 1.2f)
                }
                Weapon.MEGA_GRENADE -> {
                    grenade(canvas, 0xFFFFC107.toInt(), t)
                    if (random.nextFloat() < 0.3f) spawn(x, y, 20f, 1, 0xFFFFF59D.toInt(), 0.4f, 1f)
                }
                Weapon.MINE -> {
                    paint.color = 0xFF455A64.toInt()
                    rect.set(-4.5f, -3f, 4.5f, 5f)
                    canvas.drawArc(rect, 180f, 180f, true, paint)
                    canvas.drawRect(-5f, 0.5f, 5f, 2f, paint)
                    // Blinks red once armed.
                    val on = p.armed && (t * 3f).toInt() % 2 == 0
                    paint.color = if (on) 0xFFFF1744.toInt() else 0xFF7F0000.toInt()
                    canvas.drawCircle(0f, -1.5f, 1.2f, paint)
                    if (on) {
                        paint.color = 0x55FF1744
                        canvas.drawCircle(0f, -1.5f, 4f, paint)
                    }
                }
                Weapon.SHEEP -> {
                    canvas.translate(0f, -1f)
                    canvas.scale(p.dir * 0.3f, 0.3f)
                    WeaponIcons.sheep(canvas, t * 18f)
                }
                else -> {
                    paint.color = 0xFF424242.toInt()
                    canvas.drawCircle(0f, 0f, 2f, paint)
                }
            }
            canvas.restoreToCount(save)
            p.fuse?.let {
                if (p.spec.childSpec != null || p.weapon == Weapon.GRENADE || p.weapon == Weapon.DYNAMITE || p.weapon == Weapon.MEGA_GRENADE || p.weapon == Weapon.SHEEP) {
                    textFill.textSize = 8f
                    textFill.color = 0xFFFFFFFF.toInt()
                    textStroke.textSize = 8f
                    textStroke.strokeWidth = 2f
                    val label = kotlin.math.ceil(it).toInt().toString()
                    canvas.drawText(label, x, y - 9, textStroke)
                    canvas.drawText(label, x, y - 9, textFill)
                }
            }
        }
    }

    private fun grenade(canvas: Canvas, color: Int, t: Float) {
        paint.color = color
        canvas.drawCircle(0f, 0f, 3.2f, paint)
        paint.color = 0x88FFFFFF.toInt()
        canvas.drawCircle(-1f, -1.2f, 1f, paint)
        paint.color = 0xFF9E9E9E.toInt()
        canvas.drawRect(-1f, -4.6f, 1f, -3f, paint)
    }

    private fun drawCrates(canvas: Canvas, m: Match, t: Float) {
        for (c in m.crates) {
            val x = c.x.toFloat()
            val y = c.y.toFloat()
            if (!c.landed) {
                // Parachute.
                paint.color = 0xFFFFFFFF.toInt()
                rect.set(x - 16, y - 34, x + 16, y - 14)
                canvas.drawArc(rect, 180f, 180f, true, paint)
                paint.color = 0xFF9E9E9E.toInt()
                paint.strokeWidth = 0.6f
                canvas.drawLine(x - 15, y - 24, x - 6, y - 7, paint)
                canvas.drawLine(x + 15, y - 24, x + 6, y - 7, paint)
            }
            paint.color = if (c.kind == CrateKind.HEALTH) 0xFFFFFFFF.toInt() else 0xFF8D6E63.toInt()
            rect.set(x - 8, y - 8, x + 8, y + 8)
            canvas.drawRoundRect(rect, 2f, 2f, paint)
            paint.color = if (c.kind == CrateKind.HEALTH) 0xFFE53935.toInt() else 0xFFFFD54F.toInt()
            if (c.kind == CrateKind.HEALTH) {
                canvas.drawRect(x - 1.8f, y - 5.5f, x + 1.8f, y + 5.5f, paint)
                canvas.drawRect(x - 5.5f, y - 1.8f, x + 5.5f, y + 1.8f, paint)
            } else {
                textFill.textSize = 12f
                textFill.color = 0xFFFFD54F.toInt()
                canvas.drawText("?", x, y + 4.5f, textFill)
            }
        }
    }

    private fun drawTracers(canvas: Canvas, now: Long) {
        val it = tracers.iterator()
        while (it.hasNext()) {
            val tr = it.next()
            val k = (now - tr.start) / 250f
            if (k >= 1f) {
                it.remove()
                continue
            }
            paint.color = 0xFFFFF59D.toInt()
            paint.alpha = (255 * (1 - k)).toInt()
            paint.strokeWidth = 1.5f
            canvas.drawLine(tr.x0, tr.y0, tr.x1, tr.y1, paint)
            paint.alpha = 255
        }
    }

    private fun drawFireballs(canvas: Canvas, now: Long) {
        val it = fireballs.iterator()
        while (it.hasNext()) {
            val f = it.next()
            val k = (now - f.start) / 450f
            if (k >= 1f) {
                it.remove()
                continue
            }
            // Bright core, orange ball and a fading shockwave ring.
            val grow = 0.6f + 0.6f * k
            paint.color = 0xFFFF6D00.toInt()
            paint.alpha = (230 * (1 - k)).toInt()
            canvas.drawCircle(f.x, f.y, f.r * grow, paint)
            paint.color = 0xFFFFEB3B.toInt()
            paint.alpha = (255 * (1 - k)).toInt()
            canvas.drawCircle(f.x, f.y, f.r * grow * 0.55f, paint)
            paint.color = 0xFFFFFFFF.toInt()
            paint.alpha = (180 * (1 - k)).toInt()
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 2f
            canvas.drawCircle(f.x, f.y, f.r * (1f + k * 1.2f), paint)
            paint.style = Paint.Style.FILL
            paint.alpha = 255
        }
    }

    private fun drawParticles(canvas: Canvas, dt: Float, m: Match) {
        var i = 0
        while (i < particles) {
            pLife[i] -= dt
            if (pLife[i] <= 0f) {
                particles--
                px[i] = px[particles]; py[i] = py[particles]; pvx[i] = pvx[particles]; pvy[i] = pvy[particles]
                pLife[i] = pLife[particles]; pMax[i] = pMax[particles]; pSize[i] = pSize[particles]
                pColor[i] = pColor[particles]; pKind[i] = pKind[particles]
                continue
            }
            val kind = pKind[i].toInt()
            when (kind) {
                2 -> { // smoke rises and drifts with the wind
                    pvx[i] += (m.wind * 60f - pvx[i]).toFloat() * dt
                    pvy[i] += (-25f - pvy[i]) * dt
                    pSize[i] += dt * 8f
                }
                1 -> pvy[i] += 120f * dt
                4 -> { // embers float up
                    pvy[i] += (-40f - pvy[i]) * dt
                    pvx[i] += (m.wind * 30f - pvx[i]).toFloat() * dt
                }
                else -> pvy[i] += 420f * dt
            }
            px[i] += pvx[i] * dt
            py[i] += pvy[i] * dt
            val k = pLife[i] / pMax[i]
            paint.color = pColor[i]
            paint.alpha = ((if (kind == 2) 140 else 255) * min(1f, k * 1.5f)).toInt()
            canvas.drawCircle(px[i], py[i], pSize[i] * (if (kind == 1 || kind == 4) k else 1f), paint)
            i++
        }
        paint.alpha = 255
    }

    private fun drawTexts(canvas: Canvas, now: Long) {
        val it = texts.iterator()
        while (it.hasNext()) {
            val ft = it.next()
            val dur = if (ft.big) 1100f else 1300f
            val k = (now - ft.start) / dur
            if (k >= 1f) {
                it.remove()
                continue
            }
            val size = if (ft.big) 22f else 11f
            val pop = if (ft.big && k < 0.15f) 0.5f + k / 0.15f * 0.5f else 1f
            textFill.textSize = size * pop
            textStroke.textSize = size * pop
            textStroke.strokeWidth = size * 0.22f
            val alpha = (255 * min(1f, (1 - k) * 3)).toInt()
            textFill.color = ft.color
            textFill.alpha = alpha
            textStroke.alpha = alpha
            val y = ft.y - k * 18
            canvas.drawText(ft.text, ft.x, y, textStroke)
            canvas.drawText(ft.text, ft.x, y, textFill)
        }
        textFill.alpha = 255
        textStroke.alpha = 255
    }

    // ---------------------------------------------------------------- HUD (screen pixels)

    private fun drawHud(canvas: Canvas, m: Match, now: Long) {
        drawTurnCard(canvas, m)
        drawWind(canvas, m)
        drawTeams(canvas, m)
        drawMiniMap(canvas, m)
        drawIntro(canvas, m, now)
        drawBanner(canvas, now)
        if (humanTurn && m.phase == Phase.AIM && m.selected.mode == FireMode.TARGET) {
            val verb = when (m.selected) {
                Weapon.TELEPORT -> "teleport"
                Weapon.GIRDER -> "build a girder"
                else -> "strike"
            }
            label(canvas, "👆 Tap where to $verb", width / 2f, height * 0.42f, 15 * dp, 0xFFFFFFFF.toInt(), PANEL)
        }
    }

    /** Top left: whose turn it is and a ring that runs down with the clock. */
    private fun drawTurnCard(canvas: Canvas, m: Match) {
        val left = leftInset + 10 * dp
        val top = topInset + 10 * dp
        val team = m.teams[m.currentTeam]
        val worm = m.activeWorm
        val teamColor = TeamColors.colors[m.currentTeam]
        textFill.textSize = 14 * dp
        val nameW = max(textFill.measureText(worm.name), 70 * dp)
        val h = 50 * dp
        rect.set(left, top, left + h + nameW + 22 * dp, top + h)
        Neon.panel(canvas, rect, teamColor, dp, path, paint)
        paint.style = Paint.Style.STROKE

        // Countdown ring.
        val cx = left + h / 2
        val cy = top + h / 2
        val r = h / 2 - 7 * dp
        val (left01, warn) = when (m.phase) {
            Phase.AIM -> (m.turnTimeLeft / Match.TURN_SECONDS).toFloat() to (m.turnTimeLeft <= 5)
            Phase.RETREAT -> (m.retreatLeft / Match.RETREAT_SECONDS).toFloat() to true
            else -> 0f to false
        }
        paint.strokeWidth = 4.5f * dp
        paint.strokeCap = Paint.Cap.ROUND
        paint.color = 0x2600E5FF
        canvas.drawCircle(cx, cy, r, paint)
        // Tick marks around the dial.
        paint.strokeWidth = 1 * dp
        paint.color = 0x6600E5FF
        for (i in 0 until 12) {
            val a = i * 0.5236f
            canvas.drawLine(cx + kotlin.math.cos(a) * (r + 4 * dp), cy + sin(a) * (r + 4 * dp), cx + kotlin.math.cos(a) * (r + 6 * dp), cy + sin(a) * (r + 6 * dp), paint)
        }
        paint.strokeWidth = 4.5f * dp
        val ring = if (warn) Neon.AMBER else teamColor
        paint.color = ring
        paint.setShadowLayer(6 * dp, 0f, 0f, ring)
        rect.set(cx - r, cy - r, cx + r, cy + r)
        if (left01 > 0f) canvas.drawArc(rect, -90f, 360f * left01.coerceIn(0f, 1f), false, paint)
        paint.clearShadowLayer()
        paint.strokeCap = Paint.Cap.BUTT
        paint.style = Paint.Style.FILL
        val seconds = when (m.phase) {
            Phase.AIM -> kotlin.math.ceil(m.turnTimeLeft).toInt().toString()
            Phase.RETREAT -> kotlin.math.ceil(m.retreatLeft).toInt().toString()
            else -> "…"
        }
        hudText(canvas, seconds, cx, cy + 6 * dp, 17 * dp, if (warn) 0xFFFFE082.toInt() else 0xFFFFFFFF.toInt())

        // Worm and team names.
        textFill.textAlign = Paint.Align.LEFT
        textStroke.textAlign = Paint.Align.LEFT
        val tx = left + h + 4 * dp
        hudText(canvas, worm.name, tx, top + 23 * dp, 14 * dp, 0xFFFFFFFF.toInt())
        val sub = if (m.phase == Phase.RETREAT) "RUN FOR COVER!" else team.name
        hudText(canvas, sub, tx, top + 39 * dp, 10 * dp, if (m.phase == Phase.RETREAT) 0xFFFFE082.toInt() else lighten(teamColor))
        textFill.textAlign = Paint.Align.CENTER
        textStroke.textAlign = Paint.Align.CENTER
    }

    /** Top centre: wind strength as a bar with arrows pointing where it blows. */
    private fun drawWind(canvas: Canvas, m: Match) {
        val cx = width / 2f
        val top = topInset + 12 * dp
        val half = 92 * dp
        val h = 22 * dp
        rect.set(cx - half, top, cx + half, top + h)
        Neon.panel(canvas, rect, Neon.CYAN, dp, path, paint, glow = false)
        val wind = m.wind.toFloat()
        val color = if (wind > 0) Neon.CYAN else Neon.MAGENTA
        val reach = wind * (half - 6 * dp)
        if (abs(reach) > 1f) {
            rect.set(min(cx, cx + reach), top + 5 * dp, max(cx, cx + reach), top + h - 5 * dp)
            paint.color = color
            paint.alpha = 110
            canvas.drawRoundRect(rect, 6 * dp, 6 * dp, paint)
            paint.alpha = 255
            // Chevrons: one for each quarter of full strength.
            val dir = if (wind > 0) 1f else -1f
            val n = kotlin.math.ceil(abs(wind) * 4f).toInt().coerceIn(1, 4)
            paint.color = color
            paint.setShadowLayer(5 * dp, 0f, 0f, color)
            for (i in 0 until n) {
                val x = cx + dir * (12 * dp + i * 18 * dp)
                path.reset()
                path.moveTo(x - dir * 5 * dp, top + 5 * dp)
                path.lineTo(x + dir * 3 * dp, top + h / 2)
                path.lineTo(x - dir * 5 * dp, top + h - 5 * dp)
                path.lineTo(x - dir * 1 * dp, top + h / 2)
                path.close()
                canvas.drawPath(path, paint)
            }
            paint.clearShadowLayer()
        }
        paint.color = 0x88FFFFFF.toInt()
        canvas.drawRect(cx - 1 * dp, top + 4 * dp, cx + 1 * dp, top + h - 4 * dp, paint)
        hudText(canvas, if (abs(wind) < 0.05f) "NO WIND" else "WIND", cx, top + h + 13 * dp, 9.5f * dp, 0xFFFFFFFF.toInt())
    }

    /** Bottom centre: every team's total health. */
    private fun drawTeams(canvas: Canvas, m: Match) {
        val panelW = min(width * 0.34f, 280 * dp)
        val row = 17 * dp
        val pad = 7 * dp
        val panelH = pad * 2 + row * m.teams.size
        val left = (width - panelW) / 2f
        val top = height - bottomInset - 8 * dp - panelH
        rect.set(left, top, left + panelW, top + panelH)
        Neon.panel(canvas, rect, Neon.CYAN, dp, path, paint, glow = false)
        val maxHealth = m.teams.maxOf { it.worms.size * Worm.START_HEALTH }.toFloat()
        val nameW = min(96 * dp, panelW * 0.36f)
        val numW = 30 * dp
        for ((i, team) in m.teams.withIndex()) {
            val y = top + pad + i * row
            val color = TeamColors.colors[team.id]
            val current = team.id == m.currentTeam && m.phase != Phase.GAME_OVER
            textFill.textAlign = Paint.Align.LEFT
            textFill.textSize = 10 * dp
            textFill.color = if (team.alive) lighten(color) else 0x66FFFFFF
            val name = if (current) "▶ ${team.name}" else team.name
            canvas.drawText(ellipsize(name, nameW - 4 * dp), left + pad, y + row * 0.68f, textFill)
            val barL = left + pad + nameW
            val barR = left + panelW - pad - numW
            val barT = y + row * 0.25f
            val barB = y + row * 0.78f
            // Segmented energy bar.
            val fill = (team.totalHealth / maxHealth).coerceIn(0f, 1f)
            val segments = 16
            val gap = 1.5f * dp
            val segW = ((barR - barL) - gap * (segments - 1)) / segments
            val lit = kotlin.math.ceil(fill * segments).toInt()
            for (k in 0 until segments) {
                val sx = barL + k * (segW + gap)
                rect.set(sx, barT, sx + segW, barB)
                paint.color = if (k < lit) color else 0x2600E5FF
                canvas.drawRect(rect, paint)
            }
            textFill.textAlign = Paint.Align.RIGHT
            textFill.color = 0xFFFFFFFF.toInt()
            canvas.drawText(team.totalHealth.toString(), left + panelW - pad, y + row * 0.68f, textFill)
            textFill.textAlign = Paint.Align.CENTER
        }
    }

    /** The turn banner: a ribbon in the team's colour that drops in, then fades. */
    private fun drawBanner(canvas: Canvas, now: Long) {
        val b = banner ?: return
        val k = (now - bannerAt) / (if (subBanner != null) 3000f else 1800f)
        if (k >= 1f) {
            banner = null
            return
        }
        val alpha = (255 * min(1f, (1 - k) * 4)).toInt()
        val drop = min(1f, (now - bannerAt) / 220f)
        val ease = 1 - (1 - drop) * (1 - drop)
        val y = height * 0.28f - (1 - ease) * 24 * dp
        label(canvas, b, width / 2f, y, 20 * dp, 0xFFFFFFFF.toInt(), TerrainArt.mix(Neon.GLASS, bannerColor, 0.3f), alpha, accent = bannerColor)
        subBanner?.let { label(canvas, it, width / 2f, y + 34 * dp, 13 * dp, 0xFFB3E5FC.toInt(), PANEL, alpha) }
    }

    /** Text on a neon glass plate, centred on ([x], [baseline]). */
    private fun label(canvas: Canvas, text: String, x: Float, baseline: Float, size: Float, color: Int, background: Int, alpha: Int = 255, accent: Int = Neon.CYAN) {
        textFill.textSize = size
        val w = textFill.measureText(text) + size * 2f
        val h = size * 1.9f
        rect.set(x - w / 2, baseline - size * 1.25f, x + w / 2, baseline - size * 1.25f + h)
        if (alpha >= 250) {
            Neon.panel(canvas, rect, accent, dp, path, paint, glass = background)
        } else {
            val layer = canvas.saveLayerAlpha(rect.left - 12 * dp, rect.top - 12 * dp, rect.right + 12 * dp, rect.bottom + 12 * dp, alpha)
            Neon.panel(canvas, rect, accent, dp, path, paint, glass = background)
            canvas.restoreToCount(layer)
        }
        hudText(canvas, text, x, baseline, size, color, alpha)
    }

    private fun ellipsize(text: String, maxWidth: Float): String {
        if (textFill.measureText(text) <= maxWidth) return text
        var end = text.length
        while (end > 1 && textFill.measureText(text, 0, end) + textFill.measureText("…") > maxWidth) end--
        return text.substring(0, end) + "…"
    }

    /** Team colours are dark for text on the dark panels; lift them a bit. */
    private fun lighten(color: Int) = TerrainArt.mix(color, 0xFFFFFFFF.toInt(), 0.3f)

    /** The arena's name for the first few seconds of a match. */
    private fun drawIntro(canvas: Canvas, m: Match, now: Long) {
        // Counted from the first frame, since building the map can take a moment.
        if (introAt == 0L) introAt = now
        val k = (now - introAt) / 4500f
        if (k >= 1f) return
        val alpha = (255 * min(1f, (1 - k) * 4) * min(1f, k * 8)).toInt()
        val y = topInset + 86 * dp
        label(canvas, m.arena.displayName.uppercase(), width / 2f, y, 20 * dp, 0xFFFFD54F.toInt(), PANEL, alpha)
        hudText(canvas, m.arena.tagline, width / 2f, y + 26 * dp, 12 * dp, 0xFFFFFFFF.toInt(), alpha)
    }

    /** A small map of the whole battlefield, top right. Tap it to look somewhere. */
    private fun drawMiniMap(canvas: Canvas, m: Match) {
        val art = art ?: return
        val mw = 150 * dp
        val mh = mw * m.terrain.height / m.terrain.width
        val right = width - rightInset - 64 * dp
        miniMap.set(right - mw, topInset + 10 * dp, right, topInset + 10 * dp + mh)
        rect.set(miniMap.left - 4 * dp, miniMap.top - 4 * dp, miniMap.right + 4 * dp, miniMap.bottom + 4 * dp)
        Neon.panel(canvas, rect, Neon.CYAN, dp, path, paint, glow = false)
        paint.color = TerrainArt.mix(theme.skyTop, theme.skyBottom, 0.5f)
        paint.alpha = 160
        canvas.drawRect(miniMap, paint)
        paint.alpha = 255
        val sx = mw / m.terrain.width
        val sy = mh / m.terrain.height
        val waterTop = miniMap.top + m.terrain.waterY * sy
        paint.color = theme.water
        canvas.drawRect(miniMap.left, waterTop, miniMap.right, miniMap.bottom, paint)
        canvas.drawBitmap(art.bitmap, null, miniMap, bitmapPaint)
        for (c in m.crates) {
            paint.color = 0xFFFFD54F.toInt()
            canvas.drawCircle(miniMap.left + c.x.toFloat() * sx, miniMap.top + c.y.toFloat() * sy, 1.6f * dp, paint)
        }
        for (w in m.worms) {
            if (!w.alive) continue
            val x = miniMap.left + w.x.toFloat() * sx
            val y = miniMap.top + w.y.toFloat() * sy
            if (w.id == m.activeWormId) {
                paint.color = 0xFFFFFFFF.toInt()
                canvas.drawCircle(x, y, 3.4f * dp, paint)
            }
            paint.color = TeamColors.colors[w.team]
            canvas.drawCircle(x, y, 2.3f * dp, paint)
        }
        // What the screen is showing.
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1.2f * dp
        paint.color = Neon.CYAN
        rect.set(miniMap.left + camX * sx, miniMap.top + camY * sy, miniMap.left + (camX + width / scale) * sx, miniMap.top + (camY + height / scale) * sy)
        rect.intersect(miniMap)
        canvas.drawRect(rect, paint)
        paint.style = Paint.Style.FILL
    }

    private fun hudText(canvas: Canvas, text: String, x: Float, y: Float, size: Float, color: Int, alpha: Int = 255) {
        textFill.textSize = size
        textFill.color = color
        textFill.alpha = alpha
        textStroke.textSize = size
        textStroke.strokeWidth = size * 0.2f
        textStroke.alpha = alpha
        canvas.drawText(text, x, y, textStroke)
        canvas.drawText(text, x, y, textFill)
        textFill.alpha = 255
        textStroke.alpha = 255
    }

    // ---------------------------------------------------------------- touch

    private var lastX = 0f
    private var lastY = 0f
    private var downX = 0f
    private var downY = 0f
    private var pinchDist = 0f
    private var multi = false
    private var onMiniMap = false

    /** Moves the camera to the spot under ([sx], [sy]) on the mini map. Returns false if that's not on the map. */
    private fun lookAt(m: Match, sx: Float, sy: Float): Boolean {
        if (miniMap.isEmpty) return false
        rect.set(miniMap.left - 8 * dp, miniMap.top - 8 * dp, miniMap.right + 8 * dp, miniMap.bottom + 8 * dp)
        if (!onMiniMap && !rect.contains(sx, sy)) return false
        val wx = (sx - miniMap.left) / miniMap.width() * m.terrain.width
        val wy = (sy - miniMap.top) / miniMap.height() * m.terrain.height
        camX = wx - width / scale / 2
        camY = wy - height / scale / 2
        manualUntil = SystemClock.uptimeMillis() + 3000
        return true
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val m = match ?: return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                if (lookAt(m, event.x, event.y)) {
                    onMiniMap = true
                    return true
                }
                onMiniMap = false
                downX = event.x
                downY = event.y
                lastX = event.x
                lastY = event.y
                multi = false
                if (humanTurn && m.canAct && m.selected.mode != FireMode.TARGET) aimAt(m, event.x, event.y)
            }
            MotionEvent.ACTION_POINTER_DOWN -> if (event.pointerCount == 2) {
                multi = true
                pinchDist = spread(event)
                lastX = (event.getX(0) + event.getX(1)) / 2
                lastY = (event.getY(0) + event.getY(1)) / 2
            }
            MotionEvent.ACTION_MOVE -> {
                if (onMiniMap) {
                    lookAt(m, event.x, event.y)
                    return true
                }
                if (multi && event.pointerCount >= 2) {
                    // Two fingers: pan and pinch to zoom.
                    val mx = (event.getX(0) + event.getX(1)) / 2
                    val my = (event.getY(0) + event.getY(1)) / 2
                    val d = spread(event)
                    if (pinchDist > 0) {
                        val worldX = toWorldX(mx)
                        val worldY = toWorldY(my)
                        zoom = (zoom * d / pinchDist).coerceIn(0.45f, 2.6f)
                        updateScale()
                        camX = worldX - mx / scale
                        camY = worldY - my / scale
                    }
                    camX -= (mx - lastX) / scale
                    camY -= (my - lastY) / scale
                    pinchDist = d
                    lastX = mx
                    lastY = my
                    manualUntil = SystemClock.uptimeMillis() + 2500
                } else if (!multi) {
                    if (humanTurn && m.canAct && m.selected.mode != FireMode.TARGET) {
                        aimAt(m, event.x, event.y)
                    } else {
                        camX -= (event.x - lastX) / scale
                        camY -= (event.y - lastY) / scale
                        manualUntil = SystemClock.uptimeMillis() + 2500
                    }
                    lastX = event.x
                    lastY = event.y
                }
            }
            MotionEvent.ACTION_UP -> {
                performClick()
                if (onMiniMap) {
                    onMiniMap = false
                    return true
                }
                val tap = !multi && hypot(event.x - downX, event.y - downY) < 12 * dp
                if (tap && humanTurn && m.canAct && m.selected.mode == FireMode.TARGET) {
                    listener?.onTarget(toWorldX(event.x).toDouble(), toWorldY(event.y).toDouble())
                }
                multi = false
            }
            MotionEvent.ACTION_CANCEL -> multi = false
        }
        return true
    }

    override fun performClick(): Boolean = super.performClick()

    private fun spread(e: MotionEvent) = hypot(e.getX(0) - e.getX(1), e.getY(0) - e.getY(1))

    private fun aimAt(m: Match, sx: Float, sy: Float) {
        val w = m.activeWorm
        val dx = toWorldX(sx) - w.x
        val dy = toWorldY(sy) - w.y
        if (hypot(dx, dy) < 4) return
        val facing = if (dx >= 0) 1 else -1
        listener?.onAim(facing, atan2(dy, abs(dx)))
    }

    private companion object {
        /** Dark glass behind HUD pieces. */
        const val PANEL = Neon.GLASS
        const val MAX_PARTICLES = 900
        val BIG_WORDS = listOf("BOOM!", "KABOOM!", "POW!", "BLAM!", "WHAMMO!")
    }
}
