package com.hamxanadeem.screwpuzzle.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.SystemClock
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import androidx.core.graphics.createBitmap
import com.hamxanadeem.screwpuzzle.core.Level
import com.hamxanadeem.screwpuzzle.core.LevelGenerator
import com.hamxanadeem.screwpuzzle.core.Plate
import com.hamxanadeem.screwpuzzle.core.PlateShape
import com.hamxanadeem.screwpuzzle.core.Puzzle
import com.hamxanadeem.screwpuzzle.core.PuzzleEvent
import com.hamxanadeem.screwpuzzle.core.Spot
import com.hamxanadeem.screwpuzzle.core.TapResult
import kotlin.math.PI
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Draws and animates a [Puzzle]: wooden board, acrylic plates, screws, the two boxes
 * and the holding tray. The rules run instantly in the puzzle; this view replays the
 * resulting events as animations. In [demo] mode it plays the solution by itself.
 */
class PuzzleView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    interface Listener {
        fun onScrewMoved(toBox: Boolean)
        fun onBlocked()
        fun onBoxCompleted()
        fun onPlateFreed()
        fun onWon()
        fun onStuck()
        fun onExtraSlotTapped()
    }

    var listener: Listener? = null
    var demo = false
    /** Space reserved at the top for the activity's HUD. */
    var topInset = 0

    private var puzzle: Puzzle? = null
    private val dp = resources.displayMetrics.density
    private val random = Random(SystemClock.uptimeMillis())

    // ---- Layout (pixels) ----
    private var boardLeft = 0f
    private var boardTop = 0f
    private var boardScale = 1f
    private var boxY = 0f
    private var boxW = 0f
    private var boxH = 0f
    private var trayY = 0f
    private var holeR = 0f

    // ---- Animation state ----
    private class ScrewAnim(var from: Spot, var to: Spot, var start: Long, var spin: Boolean)
    private class BoxVisual(val id: Int, val color: Int, val slot: Int, val arriveAt: Long, var leaveAt: Long = Long.MAX_VALUE)
    private class FallingPlate(val start: Long, val vx: Float, val spin: Float)

    private val screwAnims = HashMap<Int, ScrewAnim>()
    private val boxes = ArrayList<BoxVisual>()
    private val falling = HashMap<Int, FallingPlate>()
    private val shakeAt = HashMap<Int, Long>()
    private val flashAt = HashMap<Int, Long>()
    private val lastIntoBox = HashMap<Int, Long>()
    private val slotLeaveAt = LongArray(Puzzle.ACTIVE_BOXES)
    private var lastFrame = 0L
    private var demoNext = 0L
    private var demoStep = 0

    // ---- Drawing ----
    private var wood: Bitmap? = null
    private val screwBitmaps = HashMap<Int, Bitmap>()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bitmapPaint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val rect = RectF()
    private val sheen = RectF()
    private val pos = FloatArray(3)
    private val boxShaders = HashMap<Int, Shader>()
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Typeface.create("sans-serif-black", Typeface.NORMAL)
        textAlign = Paint.Align.CENTER
        color = 0xFFFFFFFF.toInt()
    }

    // Confetti, in screen pixels.
    private val cx = FloatArray(MAX_CONFETTI)
    private val cy = FloatArray(MAX_CONFETTI)
    private val cvx = FloatArray(MAX_CONFETTI)
    private val cvy = FloatArray(MAX_CONFETTI)
    private val cRot = FloatArray(MAX_CONFETTI)
    private val cColor = IntArray(MAX_CONFETTI)
    private var confetti = 0

    fun start(newPuzzle: Puzzle) {
        puzzle = newPuzzle
        screwAnims.clear()
        boxes.clear()
        falling.clear()
        shakeAt.clear()
        flashAt.clear()
        lastIntoBox.clear()
        slotLeaveAt.fill(0)
        confetti = 0
        demoStep = 0
        val now = SystemClock.uptimeMillis()
        demoNext = now + 1200
        for (slot in 0 until Puzzle.ACTIVE_BOXES) {
            newPuzzle.activeBox(slot)?.let { boxes += BoxVisual(it.id, it.color, slot, now + slot * 120L) }
        }
        lastFrame = 0L
        buildWood()
        postInvalidateOnAnimation()
    }

    /** Called after the extra tray slot is granted. */
    fun refresh() = postInvalidateOnAnimation()

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) = layoutAreas()

    private fun layoutAreas() {
        val w = width.toFloat()
        val h = height.toFloat()
        if (w == 0f) return
        val pad = 14 * dp
        boxW = min(w * 0.38f, 170 * dp)
        boxH = boxW * 0.5f
        holeR = boxH * 0.17f
        boxY = topInset + 8 * dp + boxH / 2
        trayY = boxY + boxH / 2 + 18 * dp + holeR * 1.6f
        val top = trayY + holeR * 1.6f + 18 * dp
        val availW = w - pad * 2
        val availH = h - top - pad
        boardScale = min(availW, (availH / Level.BOARD_HEIGHT).toFloat())
        boardLeft = (w - boardScale) / 2
        boardTop = top
        buildWood()
    }

    // ---------------------------------------------------------------- positions

    private fun boardX(x: Double) = boardLeft + (x * boardScale).toFloat()
    private fun boardY(y: Double) = boardTop + (y * boardScale).toFloat()
    private val screwR: Float get() = (Level.SCREW_RADIUS * boardScale).toFloat()

    private fun slotX(slot: Int) = width * (if (slot == 0) 0.29f else 0.71f)

    private fun boxOffset(box: BoxVisual, now: Long): Float {
        val inT = ((now - box.arriveAt) / BOX_MILLIS.toFloat()).coerceIn(0f, 1f)
        val outT = ((now - box.leaveAt) / BOX_MILLIS.toFloat()).coerceIn(0f, 1f)
        return -(1 - easeOut(inT)) * width * 0.7f + easeIn(outT) * width * 0.7f
    }

    private fun boxCenterX(box: BoxVisual, now: Long) = slotX(box.slot) + boxOffset(box, now)

    private fun holeX(box: BoxVisual, hole: Int, now: Long) = boxCenterX(box, now) + (hole - 1) * boxW * 0.28f

    private fun trayX(index: Int, capacity: Int): Float {
        val gap = holeR * 2.7f
        return width / 2f + (index - (capacity - 1) / 2f) * gap
    }

    /** Pixel centre and radius of a screw at [spot]. */
    private fun spotPosition(screwId: Int, spot: Spot, now: Long, out: FloatArray) {
        val puzzle = puzzle ?: return
        when (spot) {
            Spot.Board -> {
                val s = puzzle.level.screws[screwId]
                out[0] = boardX(s.x); out[1] = boardY(s.y); out[2] = screwR
            }
            is Spot.InBox -> {
                val box = boxes.firstOrNull { it.id == spot.boxId }
                if (box == null) {
                    out[0] = width * 2f; out[1] = boxY; out[2] = holeR
                } else {
                    out[0] = holeX(box, spot.hole, now); out[1] = boxY + boxH * 0.08f; out[2] = holeR
                }
            }
            is Spot.InTray -> {
                out[0] = trayX(spot.index, TRAY_SLOTS); out[1] = trayY; out[2] = holeR
            }
        }
    }

    // ---------------------------------------------------------------- drawing

    override fun onDraw(canvas: Canvas) {
        val puzzle = puzzle ?: return
        val now = SystemClock.uptimeMillis()
        val dt = if (lastFrame == 0L) 0f else ((now - lastFrame) / 1000f).coerceAtMost(0.05f)
        lastFrame = now
        if (demo && now >= demoNext) demoTick(puzzle, now)

        wood?.let { canvas.drawBitmap(it, 0f, 0f, null) }
        drawBoxes(canvas, puzzle, now)
        drawTray(canvas, puzzle)
        drawPlatesAndScrews(canvas, puzzle, now)
        drawFlyingScrews(canvas, puzzle, now)
        drawConfetti(canvas, dt)

        boxes.removeAll { now - it.leaveAt > BOX_MILLIS }
        postInvalidateOnAnimation()
    }

    private fun drawBoxes(canvas: Canvas, puzzle: Puzzle, now: Long) {
        for (box in boxes) {
            val x = boxCenterX(box, now)
            if (x < -boxW || x > width + boxW) continue
            val color = Palette.screw[box.color]
            val top = boxY - boxH / 2
            // Body with a darker base and a shiny lid line.
            rect.set(x - boxW / 2, top + 4 * dp, x + boxW / 2, boxY + boxH / 2 + 4 * dp)
            paint.shader = null
            paint.color = Palette.darker(color, 0.55f)
            canvas.drawRoundRect(rect, 14 * dp, 14 * dp, paint)
            rect.set(x - boxW / 2, top, x + boxW / 2, boxY + boxH / 2)
            paint.shader = boxShaders.getOrPut(color) {
                LinearGradient(0f, rect.top, 0f, rect.bottom, lighten(color), Palette.darker(color, 0.85f), Shader.TileMode.CLAMP)
            }
            canvas.drawRoundRect(rect, 14 * dp, 14 * dp, paint)
            paint.shader = null
            paint.color = 0x40FFFFFF
            rect.set(x - boxW / 2 + 8 * dp, top + 5 * dp, x + boxW / 2 - 8 * dp, top + boxH * 0.3f)
            canvas.drawRoundRect(rect, 10 * dp, 10 * dp, paint)
            for (hole in 0 until Puzzle.BOX_SIZE) {
                paint.color = 0x66000000
                canvas.drawCircle(holeX(box, hole, now), boxY + boxH * 0.08f, holeR * 1.1f, paint)
            }
        }
        // Boxes still to come.
        textPaint.textSize = 13 * dp
        textPaint.alpha = 200
        canvas.drawText("${puzzle.boxesLeft} boxes left", width / 2f, boxY + boxH / 2 + 16 * dp, textPaint)
    }

    private fun drawTray(canvas: Canvas, puzzle: Puzzle) {
        val capacity = TRAY_SLOTS
        val left = trayX(0, capacity) - holeR * 1.5f
        val right = trayX(capacity - 1, capacity) + holeR * 1.5f
        rect.set(left, trayY - holeR * 1.5f, right, trayY + holeR * 1.5f)
        paint.shader = null
        paint.color = 0x99301B10.toInt()
        canvas.drawRoundRect(rect, holeR * 1.5f, holeR * 1.5f, paint)
        for (i in 0 until capacity) {
            val x = trayX(i, capacity)
            if (i < puzzle.trayCapacity) {
                paint.color = 0xAA000000.toInt()
                canvas.drawCircle(x, trayY, holeR * 1.1f, paint)
            } else {
                // The locked extra slot: tap it to watch an ad.
                strokePaint.color = 0xCCFFD54F.toInt()
                strokePaint.strokeWidth = 2 * dp
                strokePaint.pathEffect = android.graphics.DashPathEffect(floatArrayOf(5 * dp, 4 * dp), 0f)
                canvas.drawCircle(x, trayY, holeR * 1.1f, strokePaint)
                strokePaint.pathEffect = null
                textPaint.textSize = holeR * 1.3f
                textPaint.color = 0xFFFFD54F.toInt()
                textPaint.alpha = 255
                canvas.drawText("+", x, trayY + holeR * 0.45f, textPaint)
                textPaint.color = 0xFFFFFFFF.toInt()
            }
        }
    }

    private fun drawPlatesAndScrews(canvas: Canvas, puzzle: Puzzle, now: Long) {
        for (plate in puzzle.level.plates.sortedBy { it.layer }) {
            val fall = falling[plate.id]
            if (!puzzle.isPlatePresent(plate.id) && fall == null) continue
            val save = canvas.save()
            var alpha = 255
            if (fall != null) {
                val t = (now - fall.start) / 1000f
                if (t > 0f) {
                    val (px, py) = plateCenter(plate)
                    canvas.translate(fall.vx * t, 2600 * dp * t * t / 2 - 120 * dp * t)
                    canvas.rotate(fall.spin * t, px, py)
                    alpha = (255 * (1f - t / 1.2f)).toInt()
                    if (t > 1.2f) {
                        falling.remove(plate.id)
                        canvas.restoreToCount(save)
                        continue
                    }
                }
            }
            drawPlate(canvas, puzzle, plate, now, alpha)
            // Screws still in this plate (falling plates have none).
            for (screw in puzzle.level.screws) {
                if (screw.plateId != plate.id) continue
                val anim = screwAnims[screw.id]
                val onBoard = puzzle.spotOf(screw.id) == Spot.Board || (anim != null && now < anim.start && anim.from == Spot.Board)
                if (!onBoard) continue
                spotPosition(screw.id, Spot.Board, now, pos)
                var x = pos[0]
                val shake = shakeAt[screw.id]
                if (shake != null && now - shake < SHAKE_MILLIS) {
                    x += sin((now - shake) / 25f) * 4 * dp * (1f - (now - shake) / SHAKE_MILLIS.toFloat())
                }
                drawScrew(canvas, screw.color, x, pos[1], pos[2], 0f)
            }
            canvas.restoreToCount(save)
        }
    }

    private fun plateCenter(plate: Plate): Pair<Float, Float> = when (val s = plate.shape) {
        is PlateShape.Rect -> boardX(s.cx) to boardY(s.cy)
        is PlateShape.Circle -> boardX(s.cx) to boardY(s.cy)
    }

    private fun drawPlate(canvas: Canvas, puzzle: Puzzle, plate: Plate, now: Long, alpha: Int) {
        val tint = Palette.plate[plate.tint % Palette.plate.size]
        val flash = flashAt[plate.id]?.let { now - it < FLASH_MILLIS } == true
        val fillAlpha = (if (flash) 220 else 150) * alpha / 255
        paint.shader = null
        paint.color = Palette.withAlpha(if (flash) 0xFFFF5252.toInt() else tint, fillAlpha)
        strokePaint.color = Palette.withAlpha(0xFFFFFFFF.toInt(), 170 * alpha / 255)
        strokePaint.strokeWidth = 2.5f * dp
        when (val s = plate.shape) {
            is PlateShape.Rect -> {
                rect.set(boardX(s.cx - s.w / 2), boardY(s.cy - s.h / 2), boardX(s.cx + s.w / 2), boardY(s.cy + s.h / 2))
                val r = 12 * dp
                canvas.drawRoundRect(rect, r, r, paint)
                // A soft sheen along the top edge, like real acrylic.
                paint.color = Palette.withAlpha(0xFFFFFFFF.toInt(), 60 * alpha / 255)
                sheen.set(rect.left + 6 * dp, rect.top + 4 * dp, rect.right - 6 * dp, rect.top + min(rect.height() * 0.3f, 14 * dp))
                canvas.drawRoundRect(sheen, r / 2, r / 2, paint)
                canvas.drawRoundRect(rect, r, r, strokePaint)
            }
            is PlateShape.Circle -> {
                val x = boardX(s.cx)
                val y = boardY(s.cy)
                val r = (s.r * boardScale).toFloat()
                canvas.drawCircle(x, y, r, paint)
                paint.color = Palette.withAlpha(0xFFFFFFFF.toInt(), 60 * alpha / 255)
                canvas.drawCircle(x - r * 0.3f, y - r * 0.35f, r * 0.35f, paint)
                canvas.drawCircle(x, y, r, strokePaint)
            }
        }
        // Holes for this plate's screws.
        paint.color = Palette.withAlpha(0xFF000000.toInt(), 70 * alpha / 255)
        for (screw in puzzle.level.screws) {
            if (screw.plateId == plate.id) canvas.drawCircle(boardX(screw.x), boardY(screw.y), screwR * 1.15f, paint)
        }
    }

    private fun drawFlyingScrews(canvas: Canvas, puzzle: Puzzle, now: Long) {
        val from = FloatArray(3)
        val to = FloatArray(3)
        for (screw in puzzle.level.screws) {
            val spot = puzzle.spotOf(screw.id)
            if (spot == Spot.Board) continue
            val anim = screwAnims[screw.id]
            if (anim != null && now < anim.start) {
                // Waiting to move: still drawn where it was (board screws are drawn with their plate).
                if (anim.from == Spot.Board) continue
                spotPosition(screw.id, anim.from, now, from)
                drawScrew(canvas, screw.color, from[0], from[1], from[2], 0f)
                continue
            }
            val t = if (anim == null) 1f else ((now - anim.start) / FLY_MILLIS.toFloat()).coerceIn(0f, 1f)
            spotPosition(screw.id, spot, now, to)
            if (t >= 1f) {
                if (to[0] > width + to[2] * 2) continue
                drawScrew(canvas, screw.color, to[0], to[1], to[2], 0f)
                continue
            }
            spotPosition(screw.id, anim!!.from, now, from)
            // Unscrew (spin and lift) for the first part, then fly in an arc.
            val lift = 0.3f
            val (x, y, r, rotation) = if (anim.spin && t < lift) {
                val k = t / lift
                listOf(from[0], from[1] - 6 * dp * k, from[2] * (1f + 0.35f * k), 720f * k)
            } else {
                val k = if (anim.spin) (t - lift) / (1f - lift) else t
                val e = easeInOut(k)
                val arc = sin(k * PI.toFloat()) * 60 * dp
                listOf(
                    from[0] + (to[0] - from[0]) * e,
                    from[1] + (to[1] - from[1]) * e - arc,
                    from[2] * (if (anim.spin) 1.35f else 1f) + (to[2] - from[2] * (if (anim.spin) 1.35f else 1f)) * e,
                    if (anim.spin) 720f else 0f,
                )
            }
            drawScrew(canvas, screw.color, x, y, r, rotation)
        }
    }

    private fun drawScrew(canvas: Canvas, color: Int, x: Float, y: Float, r: Float, rotation: Float) {
        val bitmap = screwBitmap(color)
        // Shadow.
        paint.shader = null
        paint.color = 0x55000000
        canvas.drawCircle(x + r * 0.12f, y + r * 0.2f, r, paint)
        val save = canvas.save()
        canvas.rotate(rotation, x, y)
        rect.set(x - r, y - r, x + r, y + r)
        canvas.drawBitmap(bitmap, null, rect, bitmapPaint)
        canvas.restoreToCount(save)
    }

    /** A metal screw head with a coloured rim and a cross slot, rendered once per colour. */
    private fun screwBitmap(color: Int): Bitmap = screwBitmaps.getOrPut(color) {
        val size = 96
        val b = createBitmap(size, size)
        val c = Canvas(b)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        val r = size / 2f
        val tint = Palette.screw[color]
        p.shader = RadialGradient(r * 0.7f, r * 0.6f, r * 1.2f, lighten(tint), Palette.darker(tint, 0.6f), Shader.TileMode.CLAMP)
        c.drawCircle(r, r, r - 1, p)
        p.shader = RadialGradient(r * 0.8f, r * 0.7f, r * 0.8f, 0xFFFFFFFF.toInt(), 0xFF9E9E9E.toInt(), Shader.TileMode.CLAMP)
        c.drawCircle(r, r, r * 0.62f, p)
        p.shader = null
        p.color = 0xFF616161.toInt()
        p.strokeWidth = r * 0.16f
        p.strokeCap = Paint.Cap.ROUND
        c.drawLine(r - r * 0.38f, r, r + r * 0.38f, r, p)
        c.drawLine(r, r - r * 0.38f, r, r + r * 0.38f, p)
        p.color = 0x99FFFFFF.toInt()
        c.drawCircle(r * 0.62f, r * 0.55f, r * 0.12f, p)
        b
    }

    private fun lighten(color: Int): Int {
        val r = (color shr 16 and 0xFF) + ((255 - (color shr 16 and 0xFF)) * 0.45f).toInt()
        val g = (color shr 8 and 0xFF) + ((255 - (color shr 8 and 0xFF)) * 0.45f).toInt()
        val b = (color and 0xFF) + ((255 - (color and 0xFF)) * 0.45f).toInt()
        return 0xFF000000.toInt() or (r shl 16) or (g shl 8) or b
    }

    private fun buildWood() {
        if (width == 0 || height == 0) return
        wood?.recycle()
        val b = createBitmap(width, height)
        val c = Canvas(b)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.shader = LinearGradient(0f, 0f, 0f, height.toFloat(), 0xFF8D5A3B.toInt(), 0xFF5D3A24.toInt(), Shader.TileMode.CLAMP)
        c.drawRect(0f, 0f, width.toFloat(), height.toFloat(), p)
        // Wood grain: wavy lines.
        p.shader = null
        p.style = Paint.Style.STROKE
        p.strokeWidth = 1.5f * dp
        val grain = Random(7)
        var y = 0f
        while (y < height) {
            p.color = if (grain.nextBoolean()) 0x22000000 else 0x18FFFFFF
            val path = android.graphics.Path()
            path.moveTo(0f, y)
            var x = 0f
            val phase = grain.nextFloat() * 6f
            val amp = (2 + grain.nextFloat() * 5) * dp
            while (x <= width) {
                path.lineTo(x, y + sin(x / (60 * dp) + phase) * amp)
                x += 8 * dp
            }
            c.drawPath(path, p)
            y += (6 + grain.nextFloat() * 10) * dp
        }
        // A lighter inset panel for the board.
        p.style = Paint.Style.FILL
        p.color = 0x22FFFFFF
        val pad = 8 * dp
        c.drawRoundRect(RectF(boardLeft - pad, boardTop - pad, boardLeft + boardScale + pad, boardTop + (Level.BOARD_HEIGHT * boardScale).toFloat() + pad), 18 * dp, 18 * dp, p)
        // Vignette.
        p.shader = RadialGradient(width / 2f, height / 2f, hypot(width.toFloat(), height.toFloat()) / 1.6f, 0x00000000, 0x88000000.toInt(), Shader.TileMode.CLAMP)
        c.drawRect(0f, 0f, width.toFloat(), height.toFloat(), p)
        // Holes drilled into the board under every screw.
        p.shader = null
        puzzle?.level?.screws?.forEach {
            p.color = 0x66000000
            c.drawCircle(boardX(it.x), boardY(it.y), screwR * 0.7f, p)
        }
        wood = b
    }

    // ---------------------------------------------------------------- effects

    private fun drawConfetti(canvas: Canvas, dt: Float) {
        var i = 0
        while (i < confetti) {
            cvy[i] += 900 * dp * dt
            cx[i] += cvx[i] * dt
            cy[i] += cvy[i] * dt
            cRot[i] += 360 * dt
            if (cy[i] > height + 20 * dp) {
                confetti--
                cx[i] = cx[confetti]; cy[i] = cy[confetti]; cvx[i] = cvx[confetti]; cvy[i] = cvy[confetti]
                cRot[i] = cRot[confetti]; cColor[i] = cColor[confetti]
                continue
            }
            paint.shader = null
            paint.color = cColor[i]
            val save = canvas.save()
            canvas.rotate(cRot[i], cx[i], cy[i])
            canvas.drawRect(cx[i] - 4 * dp, cy[i] - 2.5f * dp, cx[i] + 4 * dp, cy[i] + 2.5f * dp, paint)
            canvas.restoreToCount(save)
            i++
        }
    }

    private fun celebrate() {
        repeat(150) {
            if (confetti >= MAX_CONFETTI) return
            val i = confetti++
            cx[i] = width * random.nextFloat()
            cy[i] = -random.nextFloat() * height * 0.3f
            cvx[i] = (random.nextFloat() - 0.5f) * 300 * dp
            cvy[i] = random.nextFloat() * 200 * dp
            cRot[i] = random.nextFloat() * 360
            cColor[i] = Palette.screw[random.nextInt(Palette.screw.size)]
        }
    }

    // ---------------------------------------------------------------- input

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (demo) return false
        if (event.actionMasked == MotionEvent.ACTION_DOWN) return true
        if (event.actionMasked != MotionEvent.ACTION_UP) return true
        performClick()
        val puzzle = puzzle ?: return true
        if (puzzle.isWon) return true

        // The locked tray slot.
        val extra = Puzzle.TRAY_SIZE
        if (!puzzle.extraSlotUsed && hypot(event.x - trayX(extra, TRAY_SLOTS), event.y - trayY) < holeR * 1.8f) {
            listener?.onExtraSlotTapped()
            return true
        }
        tapScrewAt(puzzle, event.x, event.y)
        return true
    }

    override fun performClick(): Boolean = super.performClick()

    private fun tapScrewAt(puzzle: Puzzle, x: Float, y: Float) {
        val platesById = puzzle.level.plates.associateBy { it.id }
        val target = puzzle.level.screws
            .filter { puzzle.spotOf(it.id) == Spot.Board && hypot(boardX(it.x) - x, boardY(it.y) - y) < screwR * 1.9f }
            .maxByOrNull { platesById.getValue(it.plateId).layer } ?: return
        handleTap(puzzle, target.id)
    }

    private fun handleTap(puzzle: Puzzle, screwId: Int) {
        val now = SystemClock.uptimeMillis()
        when (val result = puzzle.tap(screwId)) {
            is TapResult.Blocked -> {
                shakeAt[screwId] = now
                result.by.forEach { flashAt[it] = now }
                listener?.onBlocked()
            }
            TapResult.NoRoom -> {
                // Tray full, but other screws may still fit a box.
                shakeAt[screwId] = now
                listener?.onBlocked()
            }
            TapResult.Ignored -> Unit
            is TapResult.Moved -> play(result.events, now)
        }
        postInvalidateOnAnimation()
    }

    /** Turns rule events into timed animations. */
    private fun play(events: List<PuzzleEvent>, now: Long) {
        var won = false
        var stuck = false
        for (event in events) {
            when (event) {
                is PuzzleEvent.ScrewMoved -> {
                    val fromBoard = event.from == Spot.Board
                    val to = event.to
                    val start = if (fromBoard) now else {
                        val box = (to as? Spot.InBox)?.let { b -> boxes.firstOrNull { it.id == b.boxId } }
                        (box?.arriveAt ?: now) + BOX_MILLIS
                    }
                    screwAnims[event.screwId] = ScrewAnim(event.from, to, start, spin = fromBoard)
                    if (to is Spot.InBox) lastIntoBox[to.boxId] = maxOf(lastIntoBox[to.boxId] ?: 0L, start + FLY_MILLIS)
                    if (fromBoard) listener?.onScrewMoved(to is Spot.InBox)
                }
                is PuzzleEvent.PlateFreed -> {
                    falling[event.plateId] = FallingPlate(now + 180, (random.nextFloat() - 0.5f) * 200 * dp, (random.nextFloat() - 0.5f) * 240)
                    listener?.onPlateFreed()
                }
                is PuzzleEvent.BoxCompleted -> {
                    val box = boxes.firstOrNull { it.id == event.boxId }
                    if (box != null) {
                        box.leaveAt = maxOf(now, lastIntoBox[event.boxId] ?: now) + 150
                        slotLeaveAt[box.slot] = box.leaveAt
                    }
                    postDelayed({ listener?.onBoxCompleted() }, maxOf(0L, (box?.leaveAt ?: now) - now))
                }
                is PuzzleEvent.BoxArrived -> {
                    val arrive = maxOf(now, slotLeaveAt[event.box.slot] + 200)
                    boxes += BoxVisual(event.box.id, event.box.color, event.box.slot, arrive)
                }
                PuzzleEvent.Won -> won = true
                PuzzleEvent.Stuck -> stuck = true
            }
        }
        if (won) {
            postDelayed({
                celebrate()
                listener?.onWon()
            }, 900)
        } else if (stuck) {
            postDelayed({ listener?.onStuck() }, 700)
        }
    }

    private fun demoTick(puzzle: Puzzle, now: Long) {
        demoNext = now + 650
        if (puzzle.isWon) {
            start(Puzzle(LevelGenerator.generate(1 + random.nextInt(12))))
            return
        }
        val solution = puzzle.level.solution
        if (demoStep < solution.size) handleTap(puzzle, solution[demoStep++])
        if (puzzle.isWon) demoNext = now + 2500
    }

    private fun easeOut(t: Float) = 1f - (1f - t) * (1f - t)
    private fun easeIn(t: Float) = t * t
    private fun easeInOut(t: Float) = if (t < 0.5f) 2 * t * t else 1 - (-2 * t + 2) * (-2 * t + 2) / 2

    private companion object {
        const val FLY_MILLIS = 480L
        const val BOX_MILLIS = 380L
        const val SHAKE_MILLIS = 350L
        const val FLASH_MILLIS = 300L
        const val MAX_CONFETTI = 200
        const val TRAY_SLOTS = Puzzle.TRAY_SIZE + 1
    }
}
