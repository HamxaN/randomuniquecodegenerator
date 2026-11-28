package com.hamxanadeem.rewind.ui

import android.app.Activity
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.google.android.material.button.MaterialButton
import com.hamxanadeem.rewind.R
import com.hamxanadeem.rewind.audio.Sfx
import com.hamxanadeem.rewind.core.TowerKind
import com.hamxanadeem.rewind.game.Art

/** Small helpers for building the game's screens in code. */
object Kit {
    fun dp(c: Context, v: Number): Int = (v.toFloat() * c.resources.displayMetrics.density).toInt()

    /** Full screen, bars hidden until swiped in. */
    fun immersive(a: Activity) {
        WindowCompat.setDecorFitsSystemWindows(a.window, false)
        WindowCompat.getInsetsController(a.window, a.window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    fun text(c: Context, s: CharSequence, sizeSp: Float = 16f, bold: Boolean = false, color: Int = R.color.ink): TextView =
        TextView(c).apply {
            text = s
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
            setTextColor(ContextCompat.getColor(c, color))
            if (bold) typeface = Typeface.DEFAULT_BOLD
        }

    fun button(c: Context, s: CharSequence, primary: Boolean = true, onClick: () -> Unit): MaterialButton {
        val b = if (primary) MaterialButton(c) else MaterialButton(c, null, com.google.android.material.R.attr.materialButtonOutlinedStyle)
        b.text = s
        b.isAllCaps = false
        b.minHeight = dp(c, 48)
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        b.setOnClickListener {
            Sfx.play(Sfx.TAP)
            onClick()
        }
        return b
    }

    fun column(c: Context, gravity: Int = Gravity.CENTER_HORIZONTAL): LinearLayout = LinearLayout(c).apply {
        orientation = LinearLayout.VERTICAL
        this.gravity = gravity
    }

    fun row(c: Context, gravity: Int = Gravity.CENTER_VERTICAL): LinearLayout = LinearLayout(c).apply {
        orientation = LinearLayout.HORIZONTAL
        this.gravity = gravity
    }

    fun panel(v: View) {
        v.setBackgroundResource(R.drawable.bg_panel)
        val p = dp(v.context, 12)
        v.setPadding(p, p, p, p)
    }

    fun lp(w: Int, h: Int, weight: Float = 0f, margin: Int = 0): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(w, h, weight).apply { setMargins(margin, margin, margin, margin) }
}

/** A tappable tower card: the tower drawn, its name and cost. */
class TowerChip(context: Context, val kind: TowerKind) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER; typeface = Typeface.DEFAULT_BOLD }
    var affordable = true
        set(v) {
            field = v
            alpha = if (v) 1f else 0.45f
            invalidate()
        }
    var chosen = false
        set(v) {
            field = v
            invalidate()
        }

    init {
        contentDescription = "${kind.title}, ${kind.cost} gold. ${kind.blurb}"
        isClickable = true
        isFocusable = true
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(Kit.dp(context, 76), Kit.dp(context, 84))
    }

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        paint.color = if (chosen) 0x55B388FF else 0x33FFFFFF
        canvas.drawRoundRect(2f, 2f, w - 2, h - 2, w * 0.14f, w * 0.14f, paint)
        Art.tower(canvas, kind, 1, w / 2, h * 0.38f, w * 0.62f, -Math.PI.toFloat() / 2)
        paint.color = 0xFFF3F4F8.toInt()
        paint.textSize = h * 0.15f
        canvas.drawText(kind.title, w / 2, h * 0.78f, paint)
        paint.color = if (affordable) 0xFFFFD54F.toInt() else 0xFFFF8A80.toInt()
        paint.textSize = h * 0.14f
        canvas.drawText("● ${kind.cost}", w / 2, h * 0.94f, paint)
    }
}
