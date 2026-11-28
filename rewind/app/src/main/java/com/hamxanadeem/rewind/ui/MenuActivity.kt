package com.hamxanadeem.rewind.ui

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.gms.ads.AdView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.materialswitch.MaterialSwitch
import com.hamxanadeem.rewind.R
import com.hamxanadeem.rewind.ads.Ads
import com.hamxanadeem.rewind.ads.Billing
import com.hamxanadeem.rewind.audio.Sfx
import com.hamxanadeem.rewind.core.Bot
import com.hamxanadeem.rewind.core.Level
import com.hamxanadeem.rewind.core.Progress
import com.hamxanadeem.rewind.core.Research
import com.hamxanadeem.rewind.data.Store
import com.hamxanadeem.rewind.game.GameView

/** Title screen: a live demo battle behind the menu, Play, Research and Settings. */
class MenuActivity : AppCompatActivity() {

    private lateinit var demo: GameView
    private lateinit var info: android.widget.TextView
    private lateinit var banner: FrameLayout
    private var adView: AdView? = null
    private val handler = Handler(Looper.getMainLooper())
    private val bot = Bot()
    private val demoTick = object : Runnable {
        override fun run() {
            demo.withGame { g ->
                if (g.state.over) null else bot.act(g)
            }
            if (demo.withGame { it.state.over } == true) newDemo()
            handler.postDelayed(this, 400)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Kit.immersive(this)
        Sfx.enabled = Store.sound(this)
        val root = FrameLayout(this)
        demo = GameView(this).apply {
            silent = true
            speed = 2
        }
        root.addView(demo, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        // Darken the demo so the menu reads clearly.
        root.addView(android.view.View(this).apply { setBackgroundColor(0xB30B0F1A.toInt()) },
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))

        val col = Kit.column(this)
        col.addView(Kit.text(this, getString(R.string.app_name), 40f, bold = true).apply { letterSpacing = 0.06f })
        col.addView(Kit.text(this, getString(R.string.tagline), 15f, color = R.color.ink_soft).apply {
            gravity = Gravity.CENTER
            maxWidth = Kit.dp(this@MenuActivity, 520)
        }, Kit.lp(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 6)))
        info = Kit.text(this, "", 16f, bold = true, color = R.color.gold)
        col.addView(info, Kit.lp(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 6)))
        val buttons = Kit.row(this, Gravity.CENTER)
        val w = Kit.dp(this, 170)
        buttons.addView(Kit.button(this, getString(R.string.play)) {
            startActivity(Intent(this, LevelsActivity::class.java))
        }, Kit.lp(w, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 6)))
        buttons.addView(Kit.button(this, getString(R.string.research), primary = false) { research() },
            Kit.lp(w, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 6)))
        buttons.addView(Kit.button(this, getString(R.string.settings), primary = false) { settings() },
            Kit.lp(w, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 6)))
        col.addView(buttons)
        root.addView(col, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER))

        banner = FrameLayout(this)
        root.addView(banner, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL))
        setContentView(root)
        newDemo()

        Billing.start(this)
        Ads.start(this) { showBanner() }
    }

    private fun newDemo() {
        val p = Progress(stars = List(Level.ALL.size) { 3 })
        demo.replaceGame(p.newGame(Level.ALL[(System.currentTimeMillis() / 1000 % 3).toInt()]))
    }

    private fun showBanner() {
        adView?.destroy()
        adView = Ads.banner(this, banner)
    }

    override fun onResume() {
        super.onResume()
        Kit.immersive(this)
        refresh()
        adView?.resume()
        handler.post(demoTick)
        Billing.onChange = {
            refresh()
            showBanner()
        }
        if (!Store.seenTutorial(this)) {
            Store.setSeenTutorial(this)
            tutorial()
        }
    }

    override fun onPause() {
        handler.removeCallbacks(demoTick)
        adView?.pause()
        super.onPause()
    }

    override fun onDestroy() {
        adView?.destroy()
        super.onDestroy()
    }

    private fun refresh() {
        val p = Store.progress(this)
        info.text = getString(R.string.stars_total, p.totalStars, Level.ALL.size * 3) + "     " + getString(R.string.crystals, p.crystals)
    }

    private fun tutorial() {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.tutorial_title)
            .setMessage(R.string.tutorial_body)
            .setPositiveButton(R.string.got_it, null)
            .show()
    }

    private fun research() {
        val list = Kit.column(this, Gravity.START)
        val pad = Kit.dp(this, 20)
        list.setPadding(pad, Kit.dp(this, 8), pad, 0)
        val dialog = MaterialAlertDialogBuilder(this)
            .setTitle(getString(R.string.research_title) + "   " + getString(R.string.crystals, Store.progress(this).crystals))
            .setView(ScrollView(this).apply { addView(list) })
            .setPositiveButton(R.string.back, null)
            .create()
        fun fill() {
            list.removeAllViews()
            val p = Store.progress(this)
            dialog.setTitle(getString(R.string.research_title) + "   " + getString(R.string.crystals, p.crystals))
            for (r in Research.entries) {
                val row = Kit.row(this)
                val text = Kit.column(this, Gravity.START)
                text.addView(Kit.text(this, r.title, 17f, bold = true))
                text.addView(Kit.text(this, r.blurb + " · " + getString(R.string.research_level, p.level(r), r.max), 14f, color = R.color.ink_soft))
                row.addView(text, Kit.lp(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
                val done = p.level(r) >= r.max
                val b = Kit.button(this, if (done) getString(R.string.research_done) else getString(R.string.research_buy, r.cost(p.level(r))), primary = !done) {
                    val now = Store.progress(this)
                    if (now.canBuy(r)) {
                        Store.save(this, now.buy(r))
                        Sfx.play(Sfx.COIN)
                        fill()
                        refresh()
                    } else {
                        Ui.toast(this, getString(R.string.no_crystals))
                    }
                }
                b.isEnabled = !done
                row.addView(b)
                list.addView(row, Kit.lp(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 4)))
            }
        }
        fill()
        dialog.show()
    }

    private fun settings() {
        val col = Kit.column(this, Gravity.START)
        val pad = Kit.dp(this, 20)
        col.setPadding(pad, Kit.dp(this, 8), pad, 0)
        val sound = MaterialSwitch(this).apply {
            text = getString(R.string.sound)
            isChecked = Store.sound(this@MenuActivity)
            minHeight = Kit.dp(this@MenuActivity, 48)
            setOnCheckedChangeListener { _, on ->
                Store.setSound(this@MenuActivity, on)
                Sfx.enabled = on
            }
        }
        col.addView(sound, Kit.lp(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        val full = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = Kit.dp(this, 6) }
        if (Store.adsRemoved(this)) {
            col.addView(Kit.text(this, getString(R.string.ads_removed), 16f, bold = true, color = R.color.gold), full)
        } else {
            val label = Billing.price?.let { getString(R.string.remove_ads, it) } ?: getString(R.string.remove_ads_plain)
            col.addView(Kit.button(this, label) {
                if (!Billing.buy(this)) Ui.toast(this, getString(R.string.billing_unavailable))
            }, full)
            col.addView(Kit.button(this, getString(R.string.restore), primary = false) { Billing.restore() }, LinearLayout.LayoutParams(full))
        }
        if (Ads.privacyOptionsRequired) {
            col.addView(Kit.button(this, getString(R.string.privacy_options), primary = false) { Ads.showPrivacyOptions(this) }, LinearLayout.LayoutParams(full))
        }
        col.addView(Kit.button(this, getString(R.string.how_to_play), primary = false) { tutorial() }, LinearLayout.LayoutParams(full))
        col.addView(Kit.text(this, getString(R.string.about_ads), 13f, color = R.color.ink_soft), LinearLayout.LayoutParams(full))
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.settings)
            .setView(ScrollView(this).apply { addView(col) })
            .setPositiveButton(R.string.back, null)
            .show()
    }
}

object Ui {
    fun toast(c: android.content.Context, s: String) = android.widget.Toast.makeText(c, s, android.widget.Toast.LENGTH_SHORT).show()
}
