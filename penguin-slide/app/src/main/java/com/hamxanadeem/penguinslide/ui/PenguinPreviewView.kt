package com.hamxanadeem.penguinslide.ui

import android.content.Context
import android.graphics.Canvas
import android.os.SystemClock
import android.util.AttributeSet
import android.view.View
import com.hamxanadeem.penguinslide.core.Skin
import com.hamxanadeem.penguinslide.core.SkinCatalog
import kotlin.math.sin

/** A small bobbing penguin wearing [skin], for the shop. */
class PenguinPreviewView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    private val painter = PenguinPainter()

    var skin: Skin = SkinCatalog.default
        set(value) {
            field = value
            invalidate()
        }

    override fun onDraw(canvas: Canvas) {
        val t = SystemClock.uptimeMillis() / 1000f
        val save = canvas.save()
        canvas.translate(width * 0.45f, height * 0.78f + sin(t * 3f) * height * 0.04f)
        canvas.rotate(-8f)
        painter.draw(canvas, width * 0.62f, skin, t, 0.5f + 0.5f * sin(t * 6f), 1f, PenguinPainter.Mood.HAPPY)
        canvas.restoreToCount(save)
        if (isShown) postInvalidateOnAnimation()
    }
}
