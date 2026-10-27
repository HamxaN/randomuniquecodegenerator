package com.hamxanadeem.penguinslide.ui

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
import com.hamxanadeem.penguinslide.core.Run
import com.hamxanadeem.penguinslide.core.RunEvent
import com.hamxanadeem.penguinslide.core.Skin
import com.hamxanadeem.penguinslide.core.SkinCatalog
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Runs and draws a slide. In [demo] mode a simple autopilot plays and there is no HUD,
 * which makes a lively background for the menu.
 */
class SlideView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    interface Listener {
        fun onRunEvent(event: RunEvent)
        fun onRunOver()
    }

    var listener: Listener? = null
    var skin: Skin = SkinCatalog.default
    var bestDistance = 0
    var demo = false

    /** Space taken by the status bar, so the HUD stays visible. */
    var hudTopInset = 0

    var paused = false
        set(value) {
            field = value
            lastFrame = 0L
            if (!value) postInvalidateOnAnimation()
        }

    private var run: Run? = null
    private var holding = false
    private var overNotified = false
    private var startedAt = 0L
    private var lastFrame = 0L
    private var wipeoutAt = -10f
    private val dp = resources.displayMetrics.density
    private val random = Random(SystemClock.uptimeMillis())

    private val scenery = Scenery()
    private val penguinPainter = PenguinPainter()

    // Camera, in metres.
    private var viewH = BASE_VIEW_H
    private var camBottom = 0.0
    private var camLeft = 0.0
    private var ppm = 1f

    private val terrainPath = Path()
    private val edgePath = Path()
    private val snowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val edgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = 0xFFFFFFFF.toInt()
        strokeJoin = Paint.Join.ROUND
    }
    private val layerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = 0x5590CAF9
    }
    private val fishPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val fishPath = Path()
    private val flagPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val particlePaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x88FFFFFF.toInt() }
    private val barBack = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x55000000 }
    private val barFill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rect = RectF()
    private val black = Typeface.create("sans-serif-black", Typeface.NORMAL)
    private val textFill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = black
        textAlign = Paint.Align.CENTER
    }
    private val textStroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = black
        textAlign = Paint.Align.CENTER
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
        color = 0xFF1F2A44.toInt()
    }

    private class FloatingText(val text: String, val color: Int, val x: Float, val y: Float, val big: Boolean, val start: Float)
    private val texts = ArrayList<FloatingText>()

    // Particles live in world coordinates (metres) so they stay put as the camera moves.
    private val px = DoubleArray(MAX_PARTICLES)
    private val py = DoubleArray(MAX_PARTICLES)
    private val pvx = FloatArray(MAX_PARTICLES)
    private val pvy = FloatArray(MAX_PARTICLES)
    private val pLife = FloatArray(MAX_PARTICLES)
    private val pSize = FloatArray(MAX_PARTICLES)
    private val pColor = IntArray(MAX_PARTICLES)
    private var particleCount = 0

    fun start(newRun: Run) {
        run = newRun
        overNotified = false
        holding = false
        texts.clear()
        particleCount = 0
        viewH = BASE_VIEW_H
        camBottom = newRun.terrain.heightAt(0.0) - viewH * 0.38
        startedAt = SystemClock.uptimeMillis()
        lastFrame = 0L
        postInvalidateOnAnimation()
    }

    /** Continue after a revive. */
    fun continueRun() {
        overNotified = false
        addText("+${Run.REVIVE_SECONDS.toInt()}s! Keep sliding!", 0xFFFFEB3B.toInt(), big = true)
        lastFrame = 0L
        postInvalidateOnAnimation()
    }

    private val seconds: Float get() = (SystemClock.uptimeMillis() - startedAt) / 1000f

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        scenery.resize(w, h)
        snowPaint.shader = LinearGradient(0f, h * 0.3f, 0f, h.toFloat(), 0xFFFFFFFF.toInt(), 0xFFBBD7F0.toInt(), Shader.TileMode.CLAMP)
        edgePaint.strokeWidth = 4 * dp
        layerPaint.strokeWidth = 3 * dp
    }

    private fun sx(x: Double) = ((x - camLeft) * ppm).toFloat()
    private fun sy(y: Double) = (height - (y - camBottom) * ppm).toFloat()

    // ---------------------------------------------------------------- frame

    override fun onDraw(canvas: Canvas) {
        val run = run ?: return
        val now = SystemClock.uptimeMillis()
        val dt = if (lastFrame == 0L) 0f else ((now - lastFrame) / 1000f).coerceAtMost(0.05f)
        lastFrame = now

        if (!paused && dt > 0f) {
            if (demo) holding = autopilot(run)
            for (event in run.update(dt.toDouble(), holding)) {
                showEffect(run, event)
                if (!demo) listener?.onRunEvent(event)
            }
            if (demo && run.isOver) start(Run(random.nextLong()))
            updateParticles(dt)
            emitTrail(run, dt)
        }
        updateCamera(run, dt)

        val day = min(1.0, run.timeLeft / Run.START_SECONDS).toFloat()
        scenery.draw(canvas, if (demo) 1f else day, (camLeft * ppm * 0.5).toFloat(), seconds)
        drawTerrain(canvas, run)
        drawFlags(canvas, run)
        drawFish(canvas, run)
        drawParticles(canvas)
        drawPenguin(canvas, run)
        drawSpeedLines(canvas, run)
        drawTexts(canvas)
        if (!demo) drawHud(canvas, run)

        if (!demo && run.isOver && !overNotified) {
            overNotified = true
            postDelayed({ if (this.run === run && run.isOver) listener?.onRunOver() }, 700)
        }
        if (!paused) postInvalidateOnAnimation()
    }

    private fun autopilot(run: Run): Boolean {
        val p = run.penguin
        return p.onGround && run.terrain.slopeAt(p.x) < 0
    }

    private fun updateCamera(run: Run, dt: Float) {
        val p = run.penguin
        val target = max(BASE_VIEW_H, (p.altitude + 8) / 0.6)
        val k = if (dt == 0f) 1.0 else min(1.0, dt * 2.5)
        viewH += (target - viewH) * k
        ppm = (height / viewH).toFloat()
        val viewW = width / ppm
        camLeft = p.x - viewW * 0.28
        val targetBottom = run.terrain.heightAt(p.x) - viewH * 0.38
        camBottom += (targetBottom - camBottom) * (if (dt == 0f) 1.0 else min(1.0, dt * 6.0))
    }

    // ---------------------------------------------------------------- world

    private fun drawTerrain(canvas: Canvas, run: Run) {
        terrainPath.reset()
        edgePath.reset()
        terrainPath.moveTo(0f, height.toFloat())
        val step = 6 * dp
        var x = 0f
        var first = true
        while (x <= width + step) {
            val wx = camLeft + x / ppm
            val y = sy(run.terrain.heightAt(wx))
            terrainPath.lineTo(x, y)
            if (first) edgePath.moveTo(x, y) else edgePath.lineTo(x, y)
            first = false
            x += step
        }
        terrainPath.lineTo(width + step, height.toFloat())
        terrainPath.close()
        canvas.drawPath(terrainPath, snowPaint)
        // A pale-blue band just under the surface gives the snow some depth.
        val save = canvas.save()
        canvas.translate(0f, 14 * dp)
        canvas.drawPath(edgePath, layerPaint)
        canvas.restoreToCount(save)
        canvas.drawPath(edgePath, edgePaint)
    }

    private fun drawFlags(canvas: Canvas, run: Run) {
        if (!demo) {
            drawFlag(canvas, run, run.nextCheckpointX, 0xFFE53935.toInt(), "+TIME")
            if (bestDistance > 0 && bestDistance > run.penguin.x) {
                drawFlag(canvas, run, bestDistance.toDouble(), 0xFFFFC107.toInt(), "BEST")
            }
        }
    }

    private fun drawFlag(canvas: Canvas, run: Run, wx: Double, color: Int, label: String) {
        val x = sx(wx)
        if (x < -100 || x > width + 100) return
        val ground = sy(run.terrain.heightAt(wx))
        val top = ground - 3.2f * ppm
        flagPaint.color = 0xFF5D4037.toInt()
        flagPaint.strokeWidth = 3 * dp
        canvas.drawLine(x, ground, x, top, flagPaint)
        flagPaint.color = color
        fishPath.reset()
        fishPath.moveTo(x, top)
        fishPath.lineTo(x + 1.4f * ppm, top + 0.45f * ppm)
        fishPath.lineTo(x, top + 0.9f * ppm)
        fishPath.close()
        canvas.drawPath(fishPath, flagPaint)
        drawLabel(canvas, label, x, top - 6 * dp, 14 * dp, color)
    }

    private fun drawFish(canvas: Canvas, run: Run) {
        val viewW = width / ppm
        val t = seconds
        for (fish in run.fishBetween(camLeft - 2, camLeft + viewW + 2)) {
            val bob = sin(t * 4f + fish.id) * 0.15f
            val x = sx(fish.x)
            val y = sy(fish.y + bob)
            val l = 0.55f * ppm
            fishPaint.shader = null
            fishPaint.color = 0xFFFFB300.toInt()
            fishPath.reset()
            fishPath.moveTo(x - l * 0.6f, y)
            fishPath.lineTo(x - l * 1.05f, y - l * 0.35f)
            fishPath.lineTo(x - l * 1.05f, y + l * 0.35f)
            fishPath.close()
            canvas.drawPath(fishPath, fishPaint)
            fishPaint.color = 0xFFFFCA28.toInt()
            rect.set(x - l * 0.75f, y - l * 0.38f, x + l * 0.6f, y + l * 0.38f)
            canvas.drawOval(rect, fishPaint)
            fishPaint.color = 0x88FFFFFF.toInt()
            rect.set(x - l * 0.4f, y - l * 0.3f, x + l * 0.3f, y - l * 0.08f)
            canvas.drawOval(rect, fishPaint)
            fishPaint.color = 0xFF1F2A44.toInt()
            canvas.drawCircle(x + l * 0.32f, y - l * 0.06f, l * 0.08f, fishPaint)
        }
    }

    private fun drawPenguin(canvas: Canvas, run: Run) {
        val p = run.penguin
        val t = seconds
        val x = sx(p.x)
        val y = sy(p.y)
        val save = canvas.save()
        canvas.translate(x, y)
        canvas.rotate(-Math.toDegrees(p.rotation).toFloat())
        val flap = when {
            p.onGround -> if (holding) 0f else 0.15f
            holding -> 1f
            else -> 0.5f + 0.5f * sin(t * 22f)
        }
        val squash = if (p.onGround && holding) 1.15f else 1f
        val mood = when {
            t - wipeoutAt < 0.9f -> PenguinPainter.Mood.DIZZY
            holding -> PenguinPainter.Mood.FOCUSED
            else -> PenguinPainter.Mood.HAPPY
        }
        penguinPainter.draw(canvas, PENGUIN_SIZE * ppm, skin, t, flap, squash, mood)
        canvas.restoreToCount(save)
    }

    private fun drawSpeedLines(canvas: Canvas, run: Run) {
        val speed = run.penguin.speed
        if (speed < 30 && !run.inFever) return
        val alpha = ((speed - 25) / 30).coerceIn(0.2, 0.8)
        linePaint.alpha = (255 * alpha).toInt()
        linePaint.strokeWidth = 2 * dp
        repeat(6) {
            val y = random.nextFloat() * height * 0.7f
            val x = random.nextFloat() * width
            canvas.drawLine(x, y, x + 60 * dp, y, linePaint)
        }
    }

    // ---------------------------------------------------------------- effects

    private fun showEffect(run: Run, event: RunEvent) {
        val p = run.penguin
        when (event) {
            RunEvent.PerfectLanding -> {
                burst(p.x, p.y + 0.5, 0xFFFFD54F.toInt(), 16)
                addText("Perfect!", 0xFFFFEB3B.toInt(), big = false)
            }
            RunEvent.GoodLanding -> burst(p.x, p.y + 0.2, 0xFFFFFFFF.toInt(), 10)
            RunEvent.Wipeout -> {
                wipeoutAt = seconds
                burst(p.x, p.y + 0.4, 0xFFFFFFFF.toInt(), 30)
                addText("Wipeout!", 0xFFFF7043.toInt(), big = false)
            }
            is RunEvent.Flips -> {
                val name = when (event.count) {
                    1 -> "Flip!"
                    2 -> "Double Flip!"
                    3 -> "Triple Flip!"
                    else -> "${event.count}x Flip!!"
                }
                addText("$name +${event.points}", 0xFF80DEEA.toInt(), big = true)
                burst(p.x, p.y + 0.6, 0xFF80DEEA.toInt(), 24)
            }
            is RunEvent.FishCaught -> burst(event.fish.x, event.fish.y, 0xFFFFCA28.toInt(), 8)
            is RunEvent.Checkpoint -> addText("Checkpoint! +${event.bonusSeconds.toInt()}s", 0xFF69F0AE.toInt(), big = true)
            RunEvent.FeverStart -> addText("FEVER!", 0xFFFF4081.toInt(), big = true)
            RunEvent.TimeUp -> addText("Time's up!", 0xFFFFFFFF.toInt(), big = true)
            RunEvent.TakeOff, RunEvent.FeverEnd -> Unit
        }
    }

    private fun emitTrail(run: Run, dt: Float) {
        val p = run.penguin
        if (p.onGround && p.speed > 12 && random.nextFloat() < (p.speed / 40).toFloat()) {
            val back = -cos(p.rotation) * 0.7
            spawn(p.x + back, p.y + 0.1, (-p.speed * 0.15 + random.nextFloat() * 2).toFloat(), (2 + random.nextFloat() * 4), 0xFFFFFFFF.toInt(), 0.6f)
        }
        if (run.inFever) {
            val hue = intArrayOf(0xFFFF4081.toInt(), 0xFFFFEB3B.toInt(), 0xFF69F0AE.toInt(), 0xFF40C4FF.toInt())
            repeat(2) {
                spawn(p.x - 0.6, p.y + 0.5, (random.nextFloat() - 0.5f) * 2, (random.nextFloat() - 0.5f) * 2, hue[random.nextInt(hue.size)], 0.5f)
            }
        }
    }

    private fun burst(x: Double, y: Double, color: Int, count: Int) {
        repeat(count) {
            val angle = random.nextFloat() * 6.2832f
            val speed = 2f + random.nextFloat() * 7f
            spawn(x, y, cos(angle) * speed, sin(angle) * speed + 3f, color, 0.8f)
        }
    }

    private fun spawn(x: Double, y: Double, vx: Float, vy: Float, color: Int, life: Float) {
        if (particleCount >= MAX_PARTICLES) return
        val i = particleCount++
        px[i] = x
        py[i] = y
        pvx[i] = vx
        pvy[i] = vy
        pLife[i] = life * (0.7f + random.nextFloat() * 0.6f)
        pSize[i] = (3 + random.nextFloat() * 4) * dp
        pColor[i] = color
    }

    private fun updateParticles(dt: Float) {
        var i = 0
        while (i < particleCount) {
            pLife[i] -= dt
            if (pLife[i] <= 0f) {
                particleCount--
                px[i] = px[particleCount]; py[i] = py[particleCount]
                pvx[i] = pvx[particleCount]; pvy[i] = pvy[particleCount]
                pLife[i] = pLife[particleCount]; pSize[i] = pSize[particleCount]; pColor[i] = pColor[particleCount]
                continue
            }
            pvy[i] -= 12f * dt
            px[i] += pvx[i] * dt
            py[i] += pvy[i] * dt
            i++
        }
    }

    private fun drawParticles(canvas: Canvas) {
        for (i in 0 until particleCount) {
            particlePaint.color = pColor[i]
            particlePaint.alpha = (255 * min(1f, pLife[i] * 2f)).toInt()
            canvas.drawCircle(sx(px[i]), sy(py[i]), pSize[i] * min(1f, pLife[i] * 2f + 0.3f), particlePaint)
        }
    }

    private fun addText(text: String, color: Int, big: Boolean) {
        if (big) texts.removeAll { it.big }
        val run = run
        val x = if (big || run == null) width / 2f else sx(run.penguin.x)
        val y = if (big || run == null) height * 0.32f else sy(run.penguin.y) - 70 * dp
        texts += FloatingText(text, color, x, y, big, seconds)
    }

    private fun drawTexts(canvas: Canvas) {
        val t = seconds
        val iterator = texts.iterator()
        while (iterator.hasNext()) {
            val text = iterator.next()
            val duration = if (text.big) 1.4f else 0.9f
            val k = (t - text.start) / duration
            if (k >= 1f || k < 0f) {
                iterator.remove()
                continue
            }
            val alpha = (255 * min(1f, (1f - k) * 3f)).toInt()
            val scale = if (text.big && k < 0.2f) easeOutBack(k / 0.2f) else 1f
            val y = if (text.big) text.y else text.y - 40 * dp * k
            val save = canvas.save()
            canvas.scale(scale, scale, text.x, y)
            drawLabel(canvas, text.text, text.x, y, if (text.big) 38 * dp else 24 * dp, text.color, alpha)
            canvas.restoreToCount(save)
        }
    }

    private fun drawLabel(canvas: Canvas, text: String, x: Float, y: Float, size: Float, color: Int, alpha: Int = 255) {
        textStroke.textSize = size
        textStroke.strokeWidth = size * 0.2f
        textStroke.alpha = alpha
        textFill.textSize = size
        textFill.color = color
        textFill.alpha = alpha
        canvas.drawText(text, x, y, textStroke)
        canvas.drawText(text, x, y, textFill)
    }

    // ---------------------------------------------------------------- HUD

    private fun drawHud(canvas: Canvas, run: Run) {
        val top = hudTopInset + 12 * dp
        drawLabel(canvas, "${run.distance} m", width / 2f, top + 34 * dp, 34 * dp, 0xFFFFFFFF.toInt())

        // Time bar: green, then orange, then red as the sun goes down.
        val barW = width * 0.5f
        val barH = 14 * dp
        val left = (width - barW) / 2f
        val barTop = top + 48 * dp
        rect.set(left, barTop, left + barW, barTop + barH)
        canvas.drawRoundRect(rect, barH / 2, barH / 2, barBack)
        val fraction = min(1.0, run.timeLeft / Run.START_SECONDS).toFloat()
        barFill.color = when {
            run.timeLeft < 8 -> 0xFFFF5252.toInt()
            run.timeLeft < 20 -> 0xFFFFAB40.toInt()
            else -> 0xFF69F0AE.toInt()
        }
        if (fraction > 0f) {
            rect.set(left, barTop, left + barW * fraction, barTop + barH)
            canvas.drawRoundRect(rect, barH / 2, barH / 2, barFill)
        }
        drawLabel(canvas, "${ceil(run.timeLeft).toInt()}s", left + barW + 26 * dp, barTop + barH, 16 * dp, 0xFFFFFFFF.toInt())

        // Fish counter in the top-left.
        fishPaint.color = 0xFFFFCA28.toInt()
        val fx = 26 * dp
        val fy = top + 26 * dp
        rect.set(fx - 12 * dp, fy - 7 * dp, fx + 10 * dp, fy + 7 * dp)
        canvas.drawOval(rect, fishPaint)
        fishPath.reset()
        fishPath.moveTo(fx - 9 * dp, fy)
        fishPath.lineTo(fx - 18 * dp, fy - 7 * dp)
        fishPath.lineTo(fx - 18 * dp, fy + 7 * dp)
        fishPath.close()
        canvas.drawPath(fishPath, fishPaint)
        textFill.textAlign = Paint.Align.LEFT
        textStroke.textAlign = Paint.Align.LEFT
        drawLabel(canvas, run.fishCaught.toString(), fx + 16 * dp, fy + 7 * dp, 20 * dp, 0xFFFFFFFF.toInt())
        textFill.textAlign = Paint.Align.CENTER
        textStroke.textAlign = Paint.Align.CENTER

        if (run.inFever) {
            val pulse = 1f + 0.08f * sin(seconds * 12f)
            val save = canvas.save()
            canvas.scale(pulse, pulse, width / 2f, barTop + 44 * dp)
            drawLabel(canvas, "🔥 FEVER 🔥", width / 2f, barTop + 44 * dp, 22 * dp, 0xFFFF4081.toInt())
            canvas.restoreToCount(save)
        }
        if (seconds < 5f && run.distance < 200) {
            val alpha = (255 * min(1f, (5f - seconds))).toInt()
            drawLabel(canvas, "Hold to dive downhill", width / 2f, height * 0.82f, 20 * dp, 0xFFFFFFFF.toInt(), alpha)
            drawLabel(canvas, "Let go on uphills to fly · Hold in the air to flip", width / 2f, height * 0.82f + 28 * dp, 14 * dp, 0xFFFFFFFF.toInt(), alpha)
        }
    }

    // ---------------------------------------------------------------- touch

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (demo) return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> holding = true
            MotionEvent.ACTION_POINTER_UP -> holding = event.pointerCount > 1
            MotionEvent.ACTION_UP -> {
                holding = false
                performClick()
            }
            MotionEvent.ACTION_CANCEL -> holding = false
        }
        return true
    }

    override fun performClick(): Boolean = super.performClick()

    private fun easeOutBack(t: Float): Float {
        val c1 = 1.70158f
        val x = t - 1f
        return 1f + (c1 + 1f) * x * x * x + c1 * x * x
    }

    private companion object {
        const val BASE_VIEW_H = 26.0
        const val PENGUIN_SIZE = 1.9f
        const val MAX_PARTICLES = 500
    }
}
