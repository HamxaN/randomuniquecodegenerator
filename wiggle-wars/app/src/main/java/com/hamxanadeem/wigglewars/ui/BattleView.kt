package com.hamxanadeem.wigglewars.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
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

    private var match: Match? = null
    private var art: TerrainArt? = null
    private var theme = MapTheme.all.first()
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
    private val black = Typeface.create("sans-serif-black", Typeface.NORMAL)
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
    private var banner: String? = null
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
        theme = MapTheme.forSeed(newMatch.config.seed)
        art?.bitmap?.recycle()
        art = TerrainArt(newMatch.terrain, theme)
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

    fun showBanner(text: String, color: Int) {
        banner = text
        bannerColor = color
        bannerAt = SystemClock.uptimeMillis()
    }

    private fun updateScale() {
        if (width == 0) return
        // About 760 world units across at normal zoom.
        scale = width / 760f * zoom
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
                is GameEvent.Fired -> if (e.weapon == Weapon.BAZOOKA || e.weapon == Weapon.SHOTGUN) {
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
            val p = m.projectiles.firstOrNull()
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

    private fun drawMountains(canvas: Canvas, m: Match) {
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

    private fun drawWater(canvas: Canvas, m: Match, t: Float) {
        val waterY = m.terrain.waterY.toFloat()
        val left = camX - 50
        val right = camX + width / scale + 50
        for (layer in 0..2) {
            paint.color = (theme.water and 0x00FFFFFF) or ((150 + layer * 35) shl 24)
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
            val tw = textFill.measureText(label) + 6
            val ly = w.y.toFloat() - 20
            rect.set(w.x.toFloat() - tw / 2, ly - 9, w.x.toFloat() + tw / 2, ly + 2)
            paint.color = TeamColors.colors[w.team]
            canvas.drawRoundRect(rect, 3f, 3f, paint)
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
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1.5f
        paint.color = 0xFFFF1744.toInt()
        canvas.drawCircle(cx, cy, 5f, paint)
        canvas.drawLine(cx - 8, cy, cx - 3, cy, paint)
        canvas.drawLine(cx + 3, cy, cx + 8, cy, paint)
        canvas.drawLine(cx, cy - 8, cx, cy - 3, paint)
        canvas.drawLine(cx, cy + 3, cx, cy + 8, paint)
        paint.style = Paint.Style.FILL
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
                else -> {
                    paint.color = 0xFF424242.toInt()
                    canvas.drawCircle(0f, 0f, 2f, paint)
                }
            }
            canvas.restoreToCount(save)
            p.fuse?.let {
                if (p.spec.childSpec != null || p.weapon == Weapon.GRENADE || p.weapon == Weapon.DYNAMITE) {
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
                else -> pvy[i] += 420f * dt
            }
            px[i] += pvx[i] * dt
            py[i] += pvy[i] * dt
            val k = pLife[i] / pMax[i]
            paint.color = pColor[i]
            paint.alpha = ((if (kind == 2) 140 else 255) * min(1f, k * 1.5f)).toInt()
            canvas.drawCircle(px[i], py[i], pSize[i] * (if (kind == 1) k else 1f), paint)
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
        val top = topInset + 10 * dp

        // Turn timer.
        val seconds = when (m.phase) {
            Phase.AIM -> kotlin.math.ceil(m.turnTimeLeft).toInt()
            Phase.RETREAT -> kotlin.math.ceil(m.retreatLeft).toInt()
            else -> null
        }
        val teamColor = TeamColors.colors[m.currentTeam]
        paint.color = 0x99000000.toInt()
        canvas.drawCircle(34 * dp, top + 24 * dp, 24 * dp, paint)
        paint.color = teamColor
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 4 * dp
        canvas.drawCircle(34 * dp, top + 24 * dp, 22 * dp, paint)
        paint.style = Paint.Style.FILL
        hudText(canvas, seconds?.toString() ?: "…", 34 * dp, top + 31 * dp, 20 * dp,
            if (m.phase == Phase.RETREAT || (seconds ?: 99) <= 5) 0xFFFFEB3B.toInt() else 0xFFFFFFFF.toInt())

        // Wind meter.
        val wx = width / 2f
        val wy = top + 14 * dp
        val half = 80 * dp
        rect.set(wx - half, wy, wx + half, wy + 12 * dp)
        paint.color = 0x99000000.toInt()
        canvas.drawRoundRect(rect, 6 * dp, 6 * dp, paint)
        val windPx = (m.wind * half).toFloat()
        paint.color = if (m.wind > 0) 0xFF4FC3F7.toInt() else 0xFFFF8A65.toInt()
        rect.set(min(wx, wx + windPx), wy + 2 * dp, max(wx, wx + windPx), wy + 10 * dp)
        canvas.drawRoundRect(rect, 4 * dp, 4 * dp, paint)
        hudText(canvas, if (abs(m.wind) < 0.05) "WIND ·" else if (m.wind > 0) "WIND ▶" else "◀ WIND", wx, wy + 28 * dp, 11 * dp, 0xFFFFFFFF.toInt())

        // Team health bars along the bottom.
        val barW = min(width * 0.28f, 220 * dp)
        val barH = 10 * dp
        val maxHealth = m.teams.maxOf { it.worms.size * Worm.START_HEALTH }.toFloat()
        var by = height - 14 * dp - m.teams.size * (barH + 5 * dp)
        for (team in m.teams) {
            val left = (width - barW) / 2f
            rect.set(left, by, left + barW, by + barH)
            paint.color = 0x77000000
            canvas.drawRoundRect(rect, barH / 2, barH / 2, paint)
            val fill = (team.totalHealth / maxHealth).coerceIn(0f, 1f)
            if (fill > 0f) {
                rect.set(left, by, left + barW * fill, by + barH)
                paint.color = TeamColors.colors[team.id]
                canvas.drawRoundRect(rect, barH / 2, barH / 2, paint)
            }
            textFill.textAlign = Paint.Align.RIGHT
            textStroke.textAlign = Paint.Align.RIGHT
            hudText(canvas, team.name, left - 6 * dp, by + barH - 1 * dp, 10 * dp, TeamColors.colors[team.id])
            textFill.textAlign = Paint.Align.CENTER
            textStroke.textAlign = Paint.Align.CENTER
            by += barH + 5 * dp
        }

        // Big banner at the start of each turn.
        val b = banner
        if (b != null) {
            val k = (now - bannerAt) / 1800f
            if (k < 1f) {
                val alpha = (255 * min(1f, (1 - k) * 3)).toInt()
                hudText(canvas, b, width / 2f, height * 0.3f, 26 * dp, bannerColor, alpha)
            } else {
                banner = null
            }
        }
        if (humanTurn && m.phase == Phase.AIM && m.selected.mode == FireMode.TARGET) {
            hudText(canvas, "Tap where to ${if (m.selected == Weapon.TELEPORT) "teleport" else "strike"}", width / 2f, height * 0.42f, 16 * dp, 0xFFFFFFFF.toInt())
        }
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

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val m = match ?: return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
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
        const val MAX_PARTICLES = 900
        val BIG_WORDS = listOf("BOOM!", "KABOOM!", "POW!", "BLAM!", "WHAMMO!")
    }
}
