package com.hamxanadeem.rewind.ui

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButton
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.hamxanadeem.rewind.R
import com.hamxanadeem.rewind.ads.Ads
import com.hamxanadeem.rewind.audio.Sfx
import com.hamxanadeem.rewind.core.Cell
import com.hamxanadeem.rewind.core.Event
import com.hamxanadeem.rewind.core.Game
import com.hamxanadeem.rewind.core.Level
import com.hamxanadeem.rewind.core.Sim
import com.hamxanadeem.rewind.core.TowerKind
import com.hamxanadeem.rewind.data.Store
import com.hamxanadeem.rewind.game.GameView

/** A battle: the map, the HUD, building, the rewind button, and the end screens. */
class GameActivity : AppCompatActivity(), GameView.Listener {

    companion object {
        const val EXTRA_LEVEL = "level"
        private const val REVIVE_LIVES = 10
    }

    private lateinit var level: Level
    private lateinit var view: GameView
    private lateinit var gold: TextView
    private lateinit var lives: TextView
    private lateinit var wave: TextView
    private lateinit var rewindBtn: MaterialButton
    private lateinit var speedBtn: MaterialButton
    private lateinit var startBtn: MaterialButton
    private lateinit var nextInfo: TextView
    private lateinit var hint: TextView
    private lateinit var buildBar: LinearLayout
    private lateinit var buildScroll: HorizontalScrollView
    private lateinit var towerBar: LinearLayout
    private lateinit var towerTitle: TextView
    private lateinit var upgradeBtn: MaterialButton
    private lateinit var sellBtn: MaterialButton
    private val chips = mutableListOf<TowerChip>()
    private val handler = Handler(Looper.getMainLooper())
    private var dialog: AlertDialog? = null
    private var finished = false
    private var revived = false
    private var adRewindWave = -1
    private var hideHintAt = 0L
    /** An ad is on screen (its own activity), so leaving this screen isn't a pause. */
    private var inAd = false

    private val hud = object : Runnable {
        override fun run() {
            refresh()
            handler.postDelayed(this, 150)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Kit.immersive(this)
        level = Level.ALL[intent.getIntExtra(EXTRA_LEVEL, 0).coerceIn(0, Level.ALL.size - 1)]
        val progress = Store.progress(this)
        val root = FrameLayout(this)
        view = GameView(this)
        view.game = progress.newGame(level)
        view.listener = this
        root.addView(view, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))

        // Top bar.
        val top = Kit.row(this)
        top.setPadding(Kit.dp(this, 10), Kit.dp(this, 4), Kit.dp(this, 10), 0)
        top.addView(Kit.button(this, getString(R.string.pause), primary = false) { pause() }.apply { contentDescription = getString(R.string.paused) })
        gold = Kit.text(this, "", 18f, bold = true, color = R.color.gold)
        lives = Kit.text(this, "", 18f, bold = true, color = R.color.life)
        wave = Kit.text(this, "", 16f, bold = true)
        for (t in listOf(gold, lives, wave)) top.addView(t, Kit.lp(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 10)))
        top.addView(View(this), Kit.lp(0, 1, 1f))
        rewindBtn = Kit.button(this, getString(R.string.rewind_wait)) { rewind() }
        top.addView(rewindBtn, Kit.lp(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 4)))
        speedBtn = Kit.button(this, getString(R.string.speed, 1), primary = false) {
            view.speed = if (view.speed >= 3) 1 else view.speed + 1
            speedBtn.text = getString(R.string.speed, view.speed)
        }
        top.addView(speedBtn, Kit.lp(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 4)))
        root.addView(top, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.TOP))

        hint = Kit.text(this, "", 15f, bold = true, color = R.color.accent).apply {
            gravity = Gravity.CENTER
            setBackgroundResource(R.drawable.bg_panel)
            setPadding(Kit.dp(this@GameActivity, 14), Kit.dp(this@GameActivity, 6), Kit.dp(this@GameActivity, 14), Kit.dp(this@GameActivity, 6))
            visibility = View.GONE
        }
        root.addView(hint, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply { topMargin = Kit.dp(this, 64) })

        // Start wave (bottom centre).
        val startBox = Kit.column(this)
        nextInfo = Kit.text(this, "", 13f, color = R.color.ink_soft).apply { gravity = Gravity.CENTER }
        startBtn = Kit.button(this, "") { startWave() }
        startBox.addView(nextInfo)
        startBox.addView(startBtn)
        Kit.panel(startBox)
        root.addView(startBox, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.END).apply {
            setMargins(0, 0, Kit.dp(this@GameActivity, 12), Kit.dp(this@GameActivity, 10))
        })

        // Build bar (bottom left).
        buildBar = Kit.row(this)
        for (k in progress.towers()) {
            val chip = TowerChip(this, k)
            chip.setOnTouchListener(chipTouch(k))
            chip.setOnClickListener { build(k) }
            chips += chip
            buildBar.addView(chip, Kit.lp(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 3)))
        }
        Kit.panel(buildBar)
        buildScroll = HorizontalScrollView(this).apply {
            addView(buildBar)
            visibility = View.GONE
            isHorizontalScrollBarEnabled = false
        }
        root.addView(buildScroll, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.START).apply {
            setMargins(Kit.dp(this@GameActivity, 12), 0, 0, Kit.dp(this@GameActivity, 10))
        })

        // Tower panel (bottom left).
        towerBar = Kit.row(this)
        towerTitle = Kit.text(this, "", 16f, bold = true)
        upgradeBtn = Kit.button(this, "") { upgrade() }
        sellBtn = Kit.button(this, "", primary = false) { sell() }
        towerBar.addView(towerTitle, Kit.lp(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 6)))
        towerBar.addView(upgradeBtn, Kit.lp(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 4)))
        towerBar.addView(sellBtn, Kit.lp(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, margin = Kit.dp(this, 4)))
        Kit.panel(towerBar)
        towerBar.visibility = View.GONE
        root.addView(towerBar, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM or Gravity.START).apply {
            setMargins(Kit.dp(this@GameActivity, 12), 0, 0, Kit.dp(this@GameActivity, 10))
        })

        setContentView(root)
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (view.selected != null) deselect() else pause()
            }
        })
        Ads.levelStarted()
        refresh()
    }

    override fun onResume() {
        super.onResume()
        Kit.immersive(this)
        handler.post(hud)
    }

    override fun onPause() {
        handler.removeCallbacks(hud)
        if (!finished && dialog == null && !inAd) pause()
        super.onPause()
    }

    private fun game(): Game = view.game!!

    // ---- HUD ---------------------------------------------------------------------

    private fun refresh() {
        val s = game().state
        gold.text = "● " + getString(R.string.gold, s.gold)
        lives.text = "♥ " + getString(R.string.lives, s.lives)
        wave.text = getString(R.string.wave_of, minOf(s.wave + 1, level.waveCount), level.waveCount)
        val canRewind = view.withGame { it.canRewind } == true
        val adRewind = !canRewind && s.waveActive && s.rewindsLeft == 0 && adRewindWave != s.wave && Ads.rewardedReady()
        rewindBtn.isEnabled = canRewind || adRewind
        rewindBtn.text = when {
            canRewind -> getString(R.string.rewind, s.rewindsLeft)
            adRewind -> getString(R.string.rewind_ad)
            else -> getString(R.string.rewind_wait)
        }
        rewindBtn.alpha = if (rewindBtn.isEnabled) 1f else 0.5f
        val between = !s.waveActive && !s.over
        startBtn.visibility = if (between) View.VISIBLE else View.GONE
        nextInfo.visibility = startBtn.visibility
        if (between) {
            startBtn.text = getString(R.string.start_wave, s.wave + 1)
            val w = level.waves.getOrNull(s.wave)
            if (w != null) {
                val parts = w.spawns.groupingBy { it.kind }.eachCount().entries.joinToString(" · ") { "${it.value} ${it.key.title}" }
                nextInfo.text = if (w.hasBoss) getString(R.string.boss_warning) + "\n" + parts else getString(R.string.next_wave_has, parts)
            }
        }
        for (c in chips) c.affordable = s.gold >= c.kind.cost
        val sel = view.selected
        val t = sel?.let { s.towerAt(it) }
        if (t != null) {
            towerTitle.text = getString(R.string.tower_level, t.kind.title, t.level)
            if (t.level >= TowerKind.MAX_LEVEL) {
                upgradeBtn.text = getString(R.string.max_level)
                upgradeBtn.isEnabled = false
            } else {
                upgradeBtn.text = getString(R.string.upgrade, t.kind.upgradeCost(t.level))
                upgradeBtn.isEnabled = s.gold >= t.kind.upgradeCost(t.level)
            }
            sellBtn.text = getString(R.string.sell, Sim.sellValue(t))
        } else if (towerBar.visibility == View.VISIBLE) {
            deselect()
        }
        if (hint.visibility == View.VISIBLE && System.currentTimeMillis() > hideHintAt && view.withGame { it.ghosts == null } == true) {
            hint.visibility = View.GONE
        }
    }

    private fun showHint(text: String, ms: Long) {
        hint.text = text
        hint.visibility = View.VISIBLE
        hideHintAt = System.currentTimeMillis() + ms
    }

    // ---- Actions -----------------------------------------------------------------

    override fun onTap(cell: Cell) {
        val s = game().state
        val t = s.towerAt(cell)
        when {
            t != null -> {
                view.selected = cell
                view.preview = null
                buildScroll.visibility = View.GONE
                towerBar.visibility = View.VISIBLE
                Sfx.play(Sfx.TAP)
            }
            level.buildable(cell) -> {
                view.selected = cell
                view.preview = null
                towerBar.visibility = View.GONE
                buildScroll.visibility = View.VISIBLE
                Sfx.play(Sfx.TAP)
            }
            else -> {
                deselect()
                Ui.toast(this, getString(R.string.cant_build_road))
            }
        }
        refresh()
    }

    private fun deselect() {
        view.selected = null
        view.preview = null
        buildScroll.visibility = View.GONE
        towerBar.visibility = View.GONE
        chips.forEach { it.chosen = false }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun chipTouch(k: TowerKind) = View.OnTouchListener { v, e ->
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                view.preview = k
                (v as TowerChip).chosen = true
            }
            MotionEvent.ACTION_CANCEL -> {
                view.preview = null
                (v as TowerChip).chosen = false
            }
        }
        false
    }

    private fun build(k: TowerKind) {
        val cell = view.selected ?: return
        val built = view.withGame { it.build(cell, k) }
        if (built != null) {
            Sfx.play(Sfx.BUILD)
            deselect()
        } else {
            view.preview = null
            chips.forEach { it.chosen = false }
            Ui.toast(this, getString(R.string.need_gold))
        }
        refresh()
    }

    private fun upgrade() {
        val cell = view.selected ?: return
        val ok = view.withGame { g -> g.state.towerAt(cell)?.let { g.upgrade(it.id) } } == true
        if (ok) Sfx.play(Sfx.BUILD) else Ui.toast(this, getString(R.string.need_gold))
        refresh()
    }

    private fun sell() {
        val cell = view.selected ?: return
        view.withGame { g -> g.state.towerAt(cell)?.let { g.sell(it.id) } }
        Sfx.play(Sfx.COIN)
        deselect()
        refresh()
    }

    private fun startWave() {
        if (view.withGame { it.startWave() } == true) Sfx.play(Sfx.TAP)
        refresh()
    }

    private fun rewind() {
        val frames = view.withGame { it.rewind() }
        if (frames != null) {
            view.playRewind(frames)
            deselect()
            val lost = view.withGame { it.ghosts?.livesLost } ?: 0
            showHint(if (lost > 0) getString(R.string.ghost_leak, lost) else getString(R.string.ghost_hint), 4500)
            refresh()
            return
        }
        // Out of rewinds this wave: an optional video grants one more.
        val s = game().state
        if (s.waveActive && s.rewindsLeft == 0 && adRewindWave != s.wave) {
            view.paused = true
            inAd = true
            Ads.showRewarded(this, onReward = {
                view.withGame { it.grantRewind() }
                adRewindWave = game().state.wave
            }, onClosed = {
                inAd = false
                view.paused = false
                Kit.immersive(this)
                refresh()
            })
        }
    }

    // ---- Events from the game ----------------------------------------------------------

    override fun onEvents(events: List<Event>) {
        if (events.any { it == Event.Won || it == Event.Lost }) {
            runOnUiThread {
                if (events.any { it == Event.Won }) won() else lost()
            }
        }
    }

    private fun pause() {
        if (dialog != null || finished) return
        view.paused = true
        dialog = MaterialAlertDialogBuilder(this)
            .setTitle(R.string.paused)
            .setPositiveButton(R.string.resume) { _, _ -> }
            .setNeutralButton(R.string.restart) { _, _ -> restart() }
            .setNegativeButton(R.string.quit) { _, _ -> finish() }
            .setOnDismissListener {
                dialog = null
                view.paused = false
                Kit.immersive(this)
            }
            .show()
    }

    private fun restart() {
        view.replaceGame(Store.progress(this).newGame(level))
        revived = false
        adRewindWave = -1
        Ads.levelStarted()
        deselect()
        refresh()
    }

    private fun lost() {
        val s = game().state
        val canRevive = !revived && Ads.rewardedReady()
        val b = MaterialAlertDialogBuilder(this)
            .setTitle(R.string.lost_title)
            .setMessage(getString(R.string.lost_body, s.wave + 1, level.waveCount))
            .setCancelable(false)
        if (canRevive) {
            b.setPositiveButton(R.string.revive) { _, _ ->
                inAd = true
                Ads.showRewarded(this, onReward = {
                    revived = true
                    view.withGame { it.revive(REVIVE_LIVES) }
                    refresh()
                }, onClosed = {
                    inAd = false
                    Kit.immersive(this)
                    // Closed early or the video failed: back to the choices.
                    if (!revived) lost()
                })
            }
            b.setNegativeButton(R.string.retry) { _, _ -> endLevel(0) { restart() } }
        } else {
            b.setPositiveButton(R.string.retry) { _, _ -> endLevel(0) { restart() } }
        }
        b.setNeutralButton(R.string.menu) { _, _ -> endLevel(0) { finish() } }
        b.show()
    }

    private fun won() {
        val g = game()
        val stars = g.stars()
        val before = Store.progress(this)
        val reward = before.reward(level.index, stars)
        val after = before.finish(level.index, stars, reward)
        Store.save(this, after)
        finished = true
        Ads.levelFinished()
        var doubled = false
        val msg = "★".repeat(stars) + "☆".repeat(3 - stars) + "\n\n" +
            getString(R.string.won_body, g.state.lives, level.lives, g.state.kills, g.rewindsUsed) + "\n" +
            getString(R.string.reward, reward)
        val b = MaterialAlertDialogBuilder(this)
            .setTitle(R.string.won_title)
            .setMessage(msg)
            .setCancelable(false)
        val hasNext = level.index + 1 < Level.ALL.size
        b.setPositiveButton(if (hasNext) R.string.next_level else R.string.menu) { _, _ ->
            next { if (hasNext) openLevel(level.index + 1) else finish() }
        }
        b.setNegativeButton(R.string.menu) { _, _ -> next { finish() } }
        if (Ads.rewardedReady()) {
            b.setNeutralButton(R.string.double_reward) { _, _ ->
                inAd = true
                Ads.showRewarded(this, onReward = {
                    doubled = true
                    Store.save(this, Store.progress(this).let { it.copy(crystals = it.crystals + reward) })
                    Sfx.play(Sfx.COIN)
                }, onClosed = {
                    inAd = false
                    Kit.immersive(this)
                    Ui.toast(this, getString(R.string.reward, if (doubled) reward * 2 else reward))
                    next { if (hasNext) openLevel(level.index + 1) else finish() }
                })
            }
        }
        b.show()
    }

    /** A loss: records the game (for ad pacing and the small consolation reward). */
    private fun endLevel(stars: Int, then: () -> Unit = { finish() }) {
        if (!finished) {
            finished = true
            val p = Store.progress(this)
            Store.save(this, p.finish(level.index, stars, p.reward(level.index, stars)))
            Ads.levelFinished()
        }
        next {
            finished = false
            then()
        }
    }

    private fun next(go: () -> Unit) {
        inAd = true
        Ads.betweenLevels(this, Store.progress(this).gamesPlayed) {
            inAd = false
            Kit.immersive(this)
            go()
        }
    }

    private fun openLevel(i: Int) {
        startActivity(Intent(this, GameActivity::class.java).putExtra(EXTRA_LEVEL, i))
        finish()
    }
}
