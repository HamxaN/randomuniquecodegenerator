package com.hamxanadeem.idlebakery.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View

/** A striped shop awning with a scalloped edge, across the top of the bakery. */
class AwningView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

    override fun onDraw(canvas: Canvas) {
        val stripe = height * 0.9f
        val body = height * 0.65f
        var x = 0f
        var i = 0
        while (x < width) {
            paint.color = if (i % 2 == 0) 0xFFE53935.toInt() else 0xFFFFF8E1.toInt()
            canvas.drawRect(x, 0f, x + stripe, body, paint)
            canvas.drawCircle(x + stripe / 2, body, stripe / 2, paint)
            x += stripe
            i++
        }
        paint.color = 0x33000000
        canvas.drawRect(0f, 0f, width.toFloat(), height * 0.08f, paint)
    }
}
