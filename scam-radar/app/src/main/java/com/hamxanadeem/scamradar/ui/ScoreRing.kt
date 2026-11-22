package com.hamxanadeem.scamradar.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View

/** A ring that fills to the risk score, with the number in the middle. */
class ScoreRing @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private var score = 0
    private var color = 0
    private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; color = 0x33FFFFFF }
    private val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER; isFakeBoldText = true; color = 0xFFFFFFFF.toInt() }
    private val small = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER; color = 0xCCFFFFFF.toInt() }
    private val box = RectF()

    fun set(score: Int, color: Int) {
        this.score = score
        this.color = color
        contentDescription = "Risk $score out of 100"
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        val s = minOf(width, height).toFloat()
        val stroke = s * 0.1f
        track.strokeWidth = stroke
        arc.strokeWidth = stroke
        arc.color = 0xFFFFFFFF.toInt()
        box.set(stroke, stroke, s - stroke, s - stroke)
        canvas.drawArc(box, 0f, 360f, false, track)
        canvas.drawArc(box, -90f, 360f * score / 100f, false, arc)
        text.textSize = s * 0.3f
        small.textSize = s * 0.12f
        canvas.drawText("$score", s / 2, s / 2 + text.textSize * 0.3f, text)
        canvas.drawText("/100", s / 2, s / 2 + text.textSize * 0.3f + small.textSize * 1.3f, small)
    }
}
