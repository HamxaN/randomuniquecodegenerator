package com.hamxanadeem.rewind.ui

import android.content.Intent
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.ScrollView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.gms.ads.AdView
import com.hamxanadeem.rewind.R
import com.hamxanadeem.rewind.ads.Ads
import com.hamxanadeem.rewind.audio.Sfx
import com.hamxanadeem.rewind.core.Level
import com.hamxanadeem.rewind.data.Store

/** The eight maps, with a mini preview of each road and the stars earned. */
class LevelsActivity : AppCompatActivity() {

    private lateinit var grid: GridLayout
    private var adView: AdView? = null
    private lateinit var banner: FrameLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Kit.immersive(this)
        val root = FrameLayout(this).apply { setBackgroundResource(R.drawable.bg_menu) }
        val col = Kit.column(this)
        val top = Kit.row(this)
        top.addView(Kit.button(this, "‹ " + getString(R.string.back), primary = false) { finish() })
        top.addView(Kit.text(this, getString(R.string.choose_level), 22f, bold = true).apply { setPadding(Kit.dp(this@LevelsActivity, 16), 0, 0, 0) })
        col.addView(top, Kit.lp(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 8)))
        grid = GridLayout(this).apply { columnCount = 4 }
        col.addView(ScrollView(this).apply { addView(grid) }, Kit.lp(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        root.addView(col, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        banner = FrameLayout(this)
        root.addView(banner, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL))
        setContentView(root)
        adView = Ads.banner(this, banner)
    }

    override fun onResume() {
        super.onResume()
        Kit.immersive(this)
        adView?.resume()
        fill()
    }

    override fun onPause() {
        adView?.pause()
        super.onPause()
    }

    override fun onDestroy() {
        adView?.destroy()
        super.onDestroy()
    }

    private fun fill() {
        grid.removeAllViews()
        val p = Store.progress(this)
        val w = Kit.dp(this, 168)
        val h = Kit.dp(this, 118)
        for (lv in Level.ALL) {
            val open = p.isUnlocked(lv.index)
            val card = LevelCard(this, lv, p.stars[lv.index], open)
            card.setOnClickListener {
                if (!open) {
                    Ui.toast(this, getString(R.string.locked))
                    return@setOnClickListener
                }
                Sfx.play(Sfx.TAP)
                startActivity(Intent(this, GameActivity::class.java).putExtra(GameActivity.EXTRA_LEVEL, lv.index))
            }
            grid.addView(card, GridLayout.LayoutParams().apply {
                width = w
                height = h
                setMargins(Kit.dp(this@LevelsActivity, 6), Kit.dp(this@LevelsActivity, 6), Kit.dp(this@LevelsActivity, 6), Kit.dp(this@LevelsActivity, 6))
            })
        }
    }
}

/** One map card: the road in miniature, the name, waves and stars (or a lock). */
class LevelCard(context: android.content.Context, private val level: Level, private val stars: Int, private val open: Boolean) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val road = Path()

    init {
        isClickable = true
        isFocusable = true
        contentDescription = "${level.name}, ${level.waveCount} waves, " + if (open) "$stars of 3 stars" else "locked"
    }

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        paint.style = Paint.Style.FILL
        paint.color = if (open) 0xFF1E3A26.toInt() else 0xFF2A2F3A.toInt()
        canvas.drawRoundRect(0f, 0f, w, h, w * 0.08f, w * 0.08f, paint)
        // Mini map.
        val mh = h * 0.62f
        val cell = minOf(w / Level.COLS, mh / Level.ROWS)
        val ox = (w - cell * Level.COLS) / 2
        val oy = h * 0.04f
        road.reset()
        level.points.forEachIndexed { i, p ->
            val x = ox + (p.x * cell).toFloat()
            val y = oy + (p.y * cell).toFloat()
            if (i == 0) road.moveTo(x, y) else road.lineTo(x, y)
        }
        canvas.save()
        canvas.clipRect(ox, oy, ox + cell * Level.COLS, oy + cell * Level.ROWS)
        paint.style = Paint.Style.STROKE
        paint.strokeJoin = Paint.Join.ROUND
        paint.strokeWidth = cell * 0.8f
        paint.color = if (open) 0xFFA1845C.toInt() else 0xFF555B66.toInt()
        canvas.drawPath(road, paint)
        canvas.restore()
        paint.style = Paint.Style.FILL
        paint.textAlign = Paint.Align.LEFT
        paint.typeface = Typeface.DEFAULT_BOLD
        paint.color = 0xFFF3F4F8.toInt()
        paint.textSize = h * 0.14f
        canvas.drawText("${level.index + 1}. ${level.name}", w * 0.06f, h * 0.8f, paint)
        paint.textSize = h * 0.11f
        paint.typeface = Typeface.DEFAULT
        paint.color = 0xFFA9B0C2.toInt()
        canvas.drawText("${level.waveCount} waves", w * 0.06f, h * 0.94f, paint)
        paint.textAlign = Paint.Align.RIGHT
        paint.textSize = h * 0.15f
        if (open) {
            paint.color = 0xFFFFD54F.toInt()
            canvas.drawText("★".repeat(stars) + "☆".repeat(3 - stars), w * 0.94f, h * 0.94f, paint)
        } else {
            paint.color = 0xFFA9B0C2.toInt()
            canvas.drawText("🔒", w * 0.94f, h * 0.94f, paint)
        }
    }
}
