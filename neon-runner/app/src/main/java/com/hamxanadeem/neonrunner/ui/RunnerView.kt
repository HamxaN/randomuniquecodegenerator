package com.hamxanadeem.neonrunner.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.os.SystemClock
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.hamxanadeem.neonrunner.core.ObstacleKind
import com.hamxanadeem.neonrunner.core.PowerKind
import com.hamxanadeem.neonrunner.core.Run
import com.hamxanadeem.neonrunner.core.RunEvent
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Draws the run as a synthwave highway seen from behind and above: a neon sun,
 * a glowing grid, three lanes, obstacles, orbs and the runner on a hover board.
 * Swipe left/right to change lanes, up to jump, down to slide.
 */
class RunnerView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    interface Listener {
        fun onEvents(events: List<RunEvent>)
    }

    var listener: Listener? = null
    var run: Run? = null
    /** While false the run is frozen (menus, game over) but the scenery still moves. */
    var playing = false
    var skin: Skin = Skins.all.first()
    /** Space taken by the camera cutout / status bar at the top. */
    var topInset = 0

    private val dp = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Neon.black(context); textAlign = Paint.Align.CENTER }
    private val path = Path()
    private val rect = RectF()
    private val random = Random(5)
    private var sky: Shader? = null
    private var sun: Shader? = null
    private var lastFrame = 0L
    /** Scenery distance when idle on the menu. */
    private var idleZ = 0.0
    private var shake = 0f

    // Camera: vanishing point, focal length (px), and how high above the track it sits.
    private var horizon = 0f
    private var focal = 0f
    private var camHeight = 0f

    private class Spark(var x: Float, var y: Float, var vx: Float, var vy: Float, var life: Float, val color: Int)
    private val sparks = ArrayList<Spark>()
    private class Popup(val text: String, val color: Int, val start: Long)
    private val popups = ArrayList<Popup>()
    private val stars = List(60) { Triple(random.nextFloat(), random.nextFloat(), random.nextFloat()) }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        horizon = h * 0.36f
        // Three lanes fill about 80% of the width at the runner's distance.
        val trackPx = w * 0.8f
        val scale = trackPx / (LANE_WIDTH * Run.LANES)
        focal = scale * CAM_BEHIND
        val runnerY = h * 0.8f
        camHeight = (runnerY - horizon) / scale
        sky = LinearGradient(0f, 0f, 0f, horizon, intArrayOf(0xFF05021A.toInt(), 0xFF240A52.toInt(), 0xFF7A1C78.toInt(), 0xFFFF3C8E.toInt()), floatArrayOf(0f, 0.5f, 0.85f, 1f), Shader.TileMode.CLAMP)
        val r = w * 0.26f
        sun = LinearGradient(0f, horizon - r * 1.4f, 0f, horizon, 0xFFFFE66D.toInt(), 0xFFFF2BD6.toInt(), Shader.TileMode.CLAMP)
    }

    // ---------------------------------------------------------------- projection

    /** Screen x of lateral position [x] metres at [dz] metres ahead of the camera. */
    private fun sx(x: Float, dz: Float) = width / 2f + x * focal / dz
    private fun sy(y: Float, dz: Float) = horizon + (camHeight - y) * focal / dz
    private fun laneCenter(lane: Float) = (lane - 1) * LANE_WIDTH

    // ---------------------------------------------------------------- frame

    override fun onDraw(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        val dt = if (lastFrame == 0L) 0.016 else ((now - lastFrame) / 1000.0).coerceIn(0.0, 0.05)
        lastFrame = now
        val r = run
        if (r != null && playing) {
            val events = r.update(dt)
            if (events.isNotEmpty()) {
                react(r, events)
                listener?.onEvents(events)
            }
        } else {
            idleZ += dt * 14
        }
        val camZ = (r?.z ?: idleZ).toFloat() - CAM_BEHIND
        val t = now / 1000f

        val save = canvas.save()
        if (shake > 0.5f) {
            canvas.translate((random.nextFloat() - 0.5f) * shake, (random.nextFloat() - 0.5f) * shake)
            shake *= 0.85f
        }
        drawSky(canvas, t)
        drawGround(canvas, camZ)
        if (r != null) drawObjects(canvas, r, camZ, t)
        if (r != null) drawRunner(canvas, r, camZ, t) else drawIdleRunner(canvas, t)
        drawSparks(canvas, dt.toFloat())
        canvas.restoreToCount(save)
        if (r != null) drawHud(canvas, r, now)
        postInvalidateOnAnimation()
    }

    private fun drawSky(canvas: Canvas, t: Float) {
        val w = width.toFloat()
        paint.shader = sky
        canvas.drawRect(0f, 0f, w, horizon, paint)
        paint.shader = null
        for ((i, s) in stars.withIndex()) {
            paint.color = 0xFFFFFFFF.toInt()
            paint.alpha = (90 + 165 * (0.5f + 0.5f * sin(t * (1 + s.third * 2) + i))).toInt()
            canvas.drawCircle(s.first * w, s.second * horizon * 0.7f, (0.6f + s.third) * dp, paint)
        }
        paint.alpha = 255
        // Striped sun on the horizon.
        val r = w * 0.26f
        val cy = horizon - r * 0.25f
        canvas.save()
        canvas.clipRect(0f, 0f, w, horizon)
        paint.shader = sun
        paint.setShadowLayer(30 * dp, 0f, 0f, 0xAAFF2BD6.toInt())
        canvas.drawCircle(w / 2, cy, r, paint)
        paint.clearShadowLayer()
        paint.shader = null
        paint.color = 0xFF3A0F5A.toInt()
        for (i in 0 until 6) {
            val y = cy + r * (0.08f + i * 0.15f)
            canvas.drawRect(w / 2 - r, y, w / 2 + r, y + r * (0.03f + i * 0.015f), paint)
        }
        canvas.restore()
        // Mountain silhouettes.
        paint.color = 0xFF1A0838.toInt()
        path.reset()
        path.moveTo(0f, horizon)
        var x = 0f
        var i = 0
        while (x < w) {
            val peak = (30 + (i * 37 % 5) * 14) * dp
            path.lineTo(x + 30 * dp, horizon - peak)
            path.lineTo(x + 60 * dp, horizon)
            x += 60 * dp
            i++
        }
        path.close()
        canvas.drawPath(path, paint)
        line.color = Neon.MAGENTA
        line.strokeWidth = 1.2f * dp
        canvas.drawPath(path, line)
    }

    private fun drawGround(canvas: Canvas, camZ: Float) {
        val w = width.toFloat()
        val h = height.toFloat()
        paint.color = 0xFF07021A.toInt()
        canvas.drawRect(0f, horizon, w, h, paint)

        // Grid either side of the track.
        line.color = 0x88FF2BD6.toInt()
        line.strokeWidth = 1.2f * dp
        for (k in -12..12) {
            val x = k * LANE_WIDTH * 1.5f
            if (abs(x) < LANE_WIDTH * 1.5f) continue
            canvas.drawLine(sx(x, 400f), sy(0f, 400f), sx(x, 1.2f), sy(0f, 1.2f), line)
        }
        val step = 6f
        var gz = step - (camZ % step)
        while (gz < 300f) {
            val y = sy(0f, gz)
            line.alpha = (220 * (1 - gz / 300f)).toInt().coerceIn(0, 255)
            canvas.drawLine(0f, y, w, y, line)
            gz += step
        }
        line.alpha = 255

        // The track: dark glass with glowing edges and lane lines.
        val half = LANE_WIDTH * 1.5f
        path.reset()
        path.moveTo(sx(-half, 400f), sy(0f, 400f))
        path.lineTo(sx(half, 400f), sy(0f, 400f))
        path.lineTo(sx(half, 1.2f), sy(0f, 1.2f))
        path.lineTo(sx(-half, 1.2f), sy(0f, 1.2f))
        path.close()
        paint.color = 0xE60B1030.toInt()
        canvas.drawPath(path, paint)
        line.color = Neon.CYAN
        line.strokeWidth = 3 * dp
        line.setShadowLayer(8 * dp, 0f, 0f, Neon.CYAN)
        for (x in floatArrayOf(-half, half)) canvas.drawLine(sx(x, 400f), sy(0f, 400f), sx(x, 1.2f), sy(0f, 1.2f), line)
        line.clearShadowLayer()
        // Dashed lane dividers that rush towards you.
        line.strokeWidth = 2 * dp
        line.color = 0xAA00E5FF.toInt()
        for (x in floatArrayOf(-LANE_WIDTH / 2, LANE_WIDTH / 2)) {
            var dz = 4f - (camZ % 4f)
            while (dz < 200f) {
                canvas.drawLine(sx(x, dz), sy(0f, dz), sx(x, dz + 1.6f), sy(0f, dz + 1.6f), line)
                dz += 4f
            }
        }
    }

    private class Thing(val dz: Float, val draw: () -> Unit)

    private fun drawObjects(canvas: Canvas, r: Run, camZ: Float, t: Float) {
        val things = ArrayList<Thing>()
        for (o in r.obstacles) {
            val dz = (o.z - camZ).toFloat()
            if (dz < 1.5f || dz > 160f) continue
            things += Thing(dz) { obstacle(canvas, o.kind, laneCenter(o.lane.toFloat()), dz, t) }
        }
        for (o in r.orbs) {
            val dz = (o.z - camZ).toFloat()
            if (dz < 1.5f || dz > 160f || o.taken) continue
            things += Thing(dz) { orb(canvas, laneCenter(o.lane.toFloat()), if (o.high) 1.6f else 0.6f, dz, t) }
        }
        for (p in r.powerUps) {
            val dz = (p.z - camZ).toFloat()
            if (dz < 1.5f || dz > 160f || p.taken) continue
            things += Thing(dz) { power(canvas, p.kind, laneCenter(p.lane.toFloat()), dz, t) }
        }
        // Far things first.
        things.sortByDescending { it.dz }
        for (th in things) th.draw()
    }

    private fun fade(dz: Float) = (255 * (1 - ((dz - 90f) / 70f).coerceIn(0f, 1f))).toInt()

    private fun obstacle(canvas: Canvas, kind: ObstacleKind, x: Float, dz: Float, t: Float) {
        val hw = LANE_WIDTH * 0.42f
        val a = fade(dz)
        when (kind) {
            ObstacleKind.BARRIER -> {
                // A low glowing hurdle.
                rect.set(sx(x - hw, dz), sy(0.5f, dz), sx(x + hw, dz), sy(0f, dz))
                paint.color = Neon.withAlpha(0xFFFFC23D.toInt(), (a * 0.35f).toInt())
                canvas.drawRect(rect, paint)
                line.color = Neon.withAlpha(Neon.AMBER, a)
                line.strokeWidth = 3 * dp * min(1f, 20f / dz)
                line.setShadowLayer(6 * dp, 0f, 0f, Neon.AMBER)
                canvas.drawLine(rect.left, rect.top, rect.right, rect.top, line)
                line.clearShadowLayer()
                canvas.drawLine(rect.left, rect.top, rect.left, rect.bottom, line)
                canvas.drawLine(rect.right, rect.top, rect.right, rect.bottom, line)
                // Warning chevrons.
                paint.color = Neon.withAlpha(0xFF1A1A1A.toInt(), a)
                val n = 4
                for (i in 0 until n) {
                    val x0 = rect.left + rect.width() * (i + 0.2f) / n
                    canvas.drawRect(x0, rect.top + rect.height() * 0.35f, x0 + rect.width() * 0.3f / n, rect.bottom - rect.height() * 0.2f, paint)
                }
            }
            ObstacleKind.BEAM -> {
                // Posts with a red laser at head height: slide under.
                val top = 1.9f
                line.strokeWidth = 4 * dp * min(1f, 20f / dz)
                line.color = Neon.withAlpha(0xFF37474F.toInt(), a)
                canvas.drawLine(sx(x - hw, dz), sy(0f, dz), sx(x - hw, dz), sy(top + 0.3f, dz), line)
                canvas.drawLine(sx(x + hw, dz), sy(0f, dz), sx(x + hw, dz), sy(top + 0.3f, dz), line)
                val flicker = 0.75f + 0.25f * sin(t * 40f)
                line.color = Neon.withAlpha(Neon.RED, (a * flicker).toInt())
                line.strokeWidth = 5 * dp * min(1f, 20f / dz)
                line.setShadowLayer(10 * dp, 0f, 0f, Neon.RED)
                canvas.drawLine(sx(x - hw, dz), sy(top, dz), sx(x + hw, dz), sy(top, dz), line)
                canvas.drawLine(sx(x - hw, dz), sy(top - 0.35f, dz), sx(x + hw, dz), sy(top - 0.35f, dz), line)
                line.clearShadowLayer()
            }
            ObstacleKind.WALL -> {
                // A tall energy wall: change lanes.
                val height = 3.2f
                rect.set(sx(x - hw, dz), sy(height, dz), sx(x + hw, dz), sy(0f, dz))
                paint.color = Neon.withAlpha(0xFF6A0F6A.toInt(), (a * 0.75f).toInt())
                canvas.drawRect(rect, paint)
                // Scrolling hex lines.
                paint.color = Neon.withAlpha(Neon.MAGENTA, (a * 0.35f).toInt())
                val rows = 6
                for (i in 0 until rows) {
                    val y = rect.top + ((i + t * 1.5f) % rows) / rows * rect.height()
                    canvas.drawRect(rect.left, y, rect.right, y + 1.5f * dp, paint)
                }
                line.color = Neon.withAlpha(Neon.MAGENTA, a)
                line.strokeWidth = 2.5f * dp * min(1f, 20f / dz)
                line.setShadowLayer(8 * dp, 0f, 0f, Neon.MAGENTA)
                canvas.drawRect(rect, line)
                line.clearShadowLayer()
            }
        }
    }

    private fun orb(canvas: Canvas, x: Float, y: Float, dz: Float, t: Float) {
        val cx = sx(x, dz)
        val bob = sin(t * 4f + dz) * 0.1f
        val cy = sy(y + bob, dz)
        val s = 0.32f * focal / dz
        val a = fade(dz)
        path.reset()
        path.moveTo(cx, cy - s)
        path.lineTo(cx + s * 0.7f, cy)
        path.lineTo(cx, cy + s)
        path.lineTo(cx - s * 0.7f, cy)
        path.close()
        paint.color = Neon.withAlpha(Neon.CYAN, a)
        paint.setShadowLayer(s, 0f, 0f, Neon.CYAN)
        canvas.drawPath(path, paint)
        paint.clearShadowLayer()
        paint.color = Neon.withAlpha(0xFFFFFFFF.toInt(), (a * 0.8f).toInt())
        canvas.drawCircle(cx - s * 0.15f, cy - s * 0.3f, s * 0.18f, paint)
    }

    private fun power(canvas: Canvas, kind: PowerKind, x: Float, dz: Float, t: Float) {
        val cx = sx(x, dz)
        val cy = sy(1.0f + sin(t * 3f) * 0.15f, dz)
        val s = 0.5f * focal / dz
        val color = POWER_COLORS[kind.ordinal]
        paint.color = Neon.withAlpha(color, 70)
        canvas.drawCircle(cx, cy, s * 1.3f, paint)
        line.color = color
        line.strokeWidth = 2.5f * dp * min(1f, 20f / dz)
        line.setShadowLayer(s * 0.6f, 0f, 0f, color)
        canvas.drawCircle(cx, cy, s, line)
        line.clearShadowLayer()
        text.textSize = s * 1.1f
        text.color = 0xFFFFFFFF.toInt()
        canvas.drawText(POWER_LETTERS[kind.ordinal], cx, cy + s * 0.4f, text)
    }

    // ---------------------------------------------------------------- the runner

    private fun drawRunner(canvas: Canvas, r: Run, camZ: Float, t: Float) {
        val dz = (r.z - camZ).toFloat()
        val x = laneCenter(r.laneX.toFloat())
        val y = r.height.toFloat()
        val crashed = !r.alive
        board(canvas, x, y, dz, t, r.sliding, crashed, r.shieldLeft > 0, r.boostLeft > 0, r.graceLeft > 0)
    }

    private fun drawIdleRunner(canvas: Canvas, t: Float) {
        board(canvas, 0f, 0.15f + sin(t * 2f) * 0.1f, CAM_BEHIND, t, false, false, false, false, false)
    }

    /** The rider: a hover board with a glowing trail and a suited figure on top. */
    private fun board(canvas: Canvas, x: Float, y: Float, dz: Float, t: Float, sliding: Boolean, crashed: Boolean, shield: Boolean, boost: Boolean, blink: Boolean) {
        if (blink && (t * 10).toInt() % 2 == 0) return
        val s = focal / dz // pixels per metre here
        val cx = sx(x, dz)
        val ground = sy(0f, dz)
        val by = sy(y + 0.35f, dz)

        // Shadow and trail.
        paint.color = 0x55000000
        rect.set(cx - 0.6f * s, ground - 0.08f * s, cx + 0.6f * s, ground + 0.08f * s)
        canvas.drawOval(rect, paint)
        val trailLen = if (boost) 2.4f else 1.2f
        paint.shader = LinearGradient(0f, by, 0f, by + trailLen * s, Neon.withAlpha(skin.trail, 200), Neon.withAlpha(skin.trail, 0), Shader.TileMode.CLAMP)
        rect.set(cx - 0.45f * s, by, cx + 0.45f * s, by + trailLen * s)
        canvas.drawRect(rect, paint)
        paint.shader = null

        // Board.
        rect.set(cx - 0.55f * s, by - 0.1f * s, cx + 0.55f * s, by + 0.1f * s)
        paint.color = 0xFF10162E.toInt()
        canvas.drawRoundRect(rect, 0.1f * s, 0.1f * s, paint)
        line.color = skin.glow
        line.strokeWidth = 2.5f * dp
        line.setShadowLayer(10 * dp, 0f, 0f, skin.glow)
        canvas.drawRoundRect(rect, 0.1f * s, 0.1f * s, line)
        line.clearShadowLayer()

        if (crashed) {
            // Tumbling rider.
            canvas.save()
            canvas.rotate(t * 400f, cx, by - 0.6f * s)
        }
        // Body: crouched while sliding.
        val bodyH = if (sliding) 0.55f else 1.1f
        val lean = if (sliding) 0.25f else 0f
        rect.set(cx - 0.28f * s, by - (0.15f + bodyH) * s, cx + 0.28f * s, by - 0.1f * s)
        paint.color = skin.suit
        canvas.drawRoundRect(rect, 0.2f * s, 0.2f * s, paint)
        line.strokeWidth = 2 * dp
        line.color = skin.glow
        canvas.drawLine(rect.left + 0.08f * s, rect.top + 0.2f * s, rect.left + 0.08f * s, rect.bottom - 0.1f * s, line)
        canvas.drawLine(rect.right - 0.08f * s, rect.top + 0.2f * s, rect.right - 0.08f * s, rect.bottom - 0.1f * s, line)
        // Helmet with a glowing visor.
        val hx = cx + lean * s
        val hy = rect.top - 0.2f * s
        paint.color = 0xFF0E1328.toInt()
        canvas.drawCircle(hx, hy, 0.26f * s, paint)
        rect.set(hx - 0.2f * s, hy - 0.06f * s, hx + 0.2f * s, hy + 0.08f * s)
        paint.color = skin.glow
        paint.setShadowLayer(8 * dp, 0f, 0f, skin.glow)
        canvas.drawRoundRect(rect, 0.06f * s, 0.06f * s, paint)
        paint.clearShadowLayer()
        if (crashed) canvas.restore()

        if (shield) {
            line.color = Neon.withAlpha(Neon.LIME, (150 + 80 * sin(t * 8f)).toInt())
            line.strokeWidth = 2 * dp
            line.setShadowLayer(10 * dp, 0f, 0f, Neon.LIME)
            canvas.drawCircle(cx, by - 0.6f * s, 0.95f * s, line)
            line.clearShadowLayer()
        }
        if (!crashed && random.nextFloat() < 0.6f) {
            sparks += Spark(cx + (random.nextFloat() - 0.5f) * 0.8f * s, by + 0.1f * s, (random.nextFloat() - 0.5f) * 60 * dp, 120 * dp, 0.35f, skin.trail)
        }
    }

    // ---------------------------------------------------------------- effects and HUD

    private fun react(r: Run, events: List<RunEvent>) {
        val cx = sx(laneCenter(r.laneX.toFloat()), CAM_BEHIND)
        val cy = sy(0.8f, CAM_BEHIND)
        for (e in events) when (e) {
            is RunEvent.OrbTaken -> repeat(6) { burst(sx(laneCenter(e.lane.toFloat()), CAM_BEHIND), cy, Neon.CYAN) }
            is RunEvent.PowerTaken -> {
                repeat(24) { burst(cx, cy, POWER_COLORS[e.kind.ordinal]) }
                popups += Popup(POWER_NAMES[e.kind.ordinal], POWER_COLORS[e.kind.ordinal], SystemClock.uptimeMillis())
            }
            RunEvent.ShieldBroke -> {
                repeat(30) { burst(cx, cy, Neon.LIME) }
                shake = 12 * dp
            }
            is RunEvent.Crashed -> {
                repeat(50) { burst(cx, cy, if (random.nextBoolean()) Neon.MAGENTA else skin.glow) }
                shake = 26 * dp
            }
            is RunEvent.Milestone -> popups += Popup("${e.metres} M", Neon.AMBER, SystemClock.uptimeMillis())
            else -> Unit
        }
    }

    private fun burst(x: Float, y: Float, color: Int) {
        val a = random.nextFloat() * 6.283f
        val v = (80 + random.nextFloat() * 260) * dp
        sparks += Spark(x, y, kotlin.math.cos(a) * v, sin(a) * v - 80 * dp, 0.6f + random.nextFloat() * 0.4f, color)
    }

    private fun drawSparks(canvas: Canvas, dt: Float) {
        val it = sparks.iterator()
        while (it.hasNext()) {
            val s = it.next()
            s.life -= dt
            if (s.life <= 0f) {
                it.remove()
                continue
            }
            s.x += s.vx * dt
            s.y += s.vy * dt
            s.vy += 300 * dp * dt
            paint.color = Neon.withAlpha(s.color, (255 * min(1f, s.life * 2)).toInt())
            canvas.drawCircle(s.x, s.y, 2.2f * dp, paint)
        }
    }

    private fun drawHud(canvas: Canvas, r: Run, now: Long) {
        val w = width.toFloat()
        val top = topInset + 14 * dp
        text.textAlign = Paint.Align.CENTER
        text.textSize = 34 * dp
        text.color = 0xFFFFFFFF.toInt()
        text.setShadowLayer(12 * dp, 0f, 0f, Neon.CYAN)
        canvas.drawText(r.score.toString(), w / 2, top + 34 * dp, text)
        text.clearShadowLayer()
        text.textSize = 11 * dp
        text.color = 0xFF9FD8E8.toInt()
        canvas.drawText("${r.z.toInt()} M", w / 2, top + 52 * dp, text)

        // Orbs, top left.
        text.textAlign = Paint.Align.LEFT
        text.textSize = 16 * dp
        text.color = Neon.CYAN
        canvas.drawText("◆ ${r.orbsTaken}", 18 * dp, top + 28 * dp, text)

        // Active power-ups as shrinking bars, under the score.
        var y = top + 66 * dp
        for ((kind, left, total) in listOf(
            Triple(PowerKind.MAGNET, r.magnetLeft, Run.POWER_SECONDS),
            Triple(PowerKind.SHIELD, r.shieldLeft, Run.POWER_SECONDS * 2),
            Triple(PowerKind.BOOST, r.boostLeft, Run.BOOST_SECONDS),
        )) {
            if (left <= 0) continue
            val color = POWER_COLORS[kind.ordinal]
            val bw = 120 * dp
            rect.set(w / 2 - bw / 2, y, w / 2 + bw / 2, y + 6 * dp)
            paint.color = 0x33FFFFFF
            canvas.drawRect(rect, paint)
            rect.right = rect.left + bw * (left / total).toFloat()
            paint.color = color
            canvas.drawRect(rect, paint)
            text.textSize = 9 * dp
            text.color = color
            canvas.drawText(POWER_NAMES[kind.ordinal], rect.left, y - 3 * dp, text)
            y += 18 * dp
        }

        // Pop-up words in the middle.
        val it = popups.iterator()
        text.textAlign = Paint.Align.CENTER
        var py = height * 0.3f
        while (it.hasNext()) {
            val p = it.next()
            val k = (now - p.start) / 1200f
            if (k >= 1f) {
                it.remove()
                continue
            }
            text.textSize = 26 * dp * (if (k < 0.15f) 0.6f + k / 0.15f * 0.4f else 1f)
            text.color = Neon.withAlpha(p.color, (255 * min(1f, (1 - k) * 3)).toInt())
            text.setShadowLayer(10 * dp, 0f, 0f, p.color)
            canvas.drawText(p.text, w / 2, py - k * 30 * dp, text)
            text.clearShadowLayer()
            py += 34 * dp
        }
    }

    // ---------------------------------------------------------------- input

    private var downX = 0f
    private var downY = 0f
    private var swiped = false

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val r = run ?: return false
        if (!playing) return false
        val threshold = 28 * dp
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = event.x
                downY = event.y
                swiped = false
            }
            MotionEvent.ACTION_MOVE -> if (!swiped) {
                val dx = event.x - downX
                val dy = event.y - downY
                if (abs(dx) > threshold || abs(dy) > threshold) {
                    swiped = true
                    if (abs(dx) > abs(dy)) {
                        if (dx < 0) r.left() else r.right()
                    } else {
                        if (dy < 0) r.jump() else r.slide()
                    }
                }
            }
            MotionEvent.ACTION_UP -> {
                // A quick tap also jumps.
                if (!swiped) {
                    performClick()
                    r.jump()
                }
            }
        }
        return true
    }

    override fun performClick(): Boolean = super.performClick()

    companion object {
        const val LANE_WIDTH = 2.4f
        const val CAM_BEHIND = 8f
        val POWER_COLORS = intArrayOf(Neon.AMBER, Neon.LIME, Neon.MAGENTA)
        val POWER_NAMES = listOf("MAGNET", "SHIELD", "BOOST")
        val POWER_LETTERS = listOf("M", "S", "B")
    }
}
