package com.hamxanadeem.neonrunner.ui

import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.LayoutInflater
import android.view.View
import android.view.animation.OvershootInterpolator
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.hamxanadeem.neonrunner.R
import com.hamxanadeem.neonrunner.ads.AdsManager
import com.hamxanadeem.neonrunner.core.PowerKind
import com.hamxanadeem.neonrunner.core.Run
import com.hamxanadeem.neonrunner.core.RunEvent
import com.hamxanadeem.neonrunner.data.Progress
import com.hamxanadeem.neonrunner.data.Settings
import com.hamxanadeem.neonrunner.fx.GameSounds
import com.hamxanadeem.neonrunner.fx.Sounds

/** The whole game: menu, the run itself, pause, game over and the skins shop. */
class MainActivity : AppCompatActivity(), RunnerView.Listener {

    private lateinit var settings: Settings
    private lateinit var progress: Progress
    private lateinit var runner: RunnerView
    private lateinit var menu: View
    private lateinit var pausePanel: View
    private lateinit var overPanel: View
    private lateinit var skinsPanel: View
    private lateinit var pauseButton: View
    private lateinit var hint: View
    private lateinit var soundButton: ImageButton
    private lateinit var vibrationButton: ImageButton

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        Screen.immersive(this)
        settings = Settings(this)
        progress = Progress(this)
        GameSounds.init(this)
        Sounds.enabled = settings.soundOn
        AdsManager.initialize(this)

        runner = findViewById(R.id.runner)
        menu = findViewById(R.id.menuPanel)
        pausePanel = findViewById(R.id.pausePanel)
        overPanel = findViewById(R.id.overPanel)
        skinsPanel = findViewById(R.id.skinsPanel)
        pauseButton = findViewById(R.id.pauseButton)
        hint = findViewById(R.id.hintText)
        soundButton = findViewById(R.id.soundButton)
        vibrationButton = findViewById(R.id.vibrationButton)
        runner.listener = this
        runner.skin = Skins.byId(progress.skin)
        AdsManager.loadBanner(this, findViewById<FrameLayout>(R.id.bannerContainer))

        Screen.padForInsets(findViewById(R.id.content))
        ViewCompat.setOnApplyWindowInsetsListener(runner) { _, insets ->
            runner.topInset = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()).top
            insets
        }

        findViewById<Button>(R.id.playButton).setOnClickListener { startRun() }
        findViewById<Button>(R.id.againButton).setOnClickListener { afterRound { startRun() } }
        findViewById<Button>(R.id.menuButton).setOnClickListener { afterRound { showMenu() } }
        findViewById<Button>(R.id.reviveButton).setOnClickListener { revive() }
        findViewById<Button>(R.id.skinsButton).setOnClickListener { showSkins() }
        findViewById<Button>(R.id.skinsClose).setOnClickListener {
            tap()
            skinsPanel.visibility = View.GONE
        }
        pauseButton.setOnClickListener { setPaused(true) }
        findViewById<Button>(R.id.resumeButton).setOnClickListener { setPaused(false) }
        findViewById<Button>(R.id.quitButton).setOnClickListener {
            tap()
            pausePanel.visibility = View.GONE
            showMenu()
        }
        soundButton.setOnClickListener {
            settings.soundOn = !settings.soundOn
            Sounds.enabled = settings.soundOn
            tap()
            renderToggles()
        }
        vibrationButton.setOnClickListener {
            settings.vibrationOn = !settings.vibrationOn
            if (settings.vibrationOn) it.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
            renderToggles()
        }
        findViewById<Button>(R.id.privacyButton).setOnClickListener { AdsManager.showPrivacyOptions(this) }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                when {
                    skinsPanel.visibility == View.VISIBLE -> skinsPanel.visibility = View.GONE
                    runner.playing -> setPaused(true)
                    pausePanel.visibility == View.VISIBLE -> setPaused(false)
                    overPanel.visibility == View.VISIBLE -> showMenu()
                    else -> finish()
                }
            }
        })
        showMenu()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) Screen.immersive(this)
    }

    override fun onResume() {
        super.onResume()
        findViewById<Button>(R.id.privacyButton).visibility =
            if (AdsManager.isPrivacyOptionsRequired(this)) View.VISIBLE else View.GONE
        renderToggles()
    }

    override fun onPause() {
        super.onPause()
        if (runner.playing) setPaused(true)
    }

    // ---------------------------------------------------------------- flow

    private fun showMenu() {
        runner.playing = false
        runner.run = null
        overPanel.visibility = View.GONE
        pauseButton.visibility = View.GONE
        hint.visibility = View.GONE
        menu.visibility = View.VISIBLE
        menu.alpha = 0f
        menu.animate().alpha(1f).setDuration(250).start()
        findViewById<TextView>(R.id.statsText).text = getString(R.string.stats_format, progress.best, progress.orbs)
    }

    private fun startRun() {
        tap()
        menu.visibility = View.GONE
        overPanel.visibility = View.GONE
        runner.skin = Skins.byId(progress.skin)
        runner.run = Run(System.nanoTime())
        runner.playing = true
        pauseButton.visibility = View.VISIBLE
        if (!progress.tutorialDone) {
            hint.visibility = View.VISIBLE
            hint.postDelayed({ hint.animate().alpha(0f).setDuration(400).withEndAction { hint.visibility = View.GONE; hint.alpha = 1f }.start() }, 4500)
            progress.tutorialDone = true
        }
    }

    private fun setPaused(value: Boolean) {
        if (runner.run?.alive != true) return
        tap()
        runner.playing = !value
        pausePanel.visibility = if (value) View.VISIBLE else View.GONE
    }

    private fun revive() {
        val run = runner.run ?: return
        if (!AdsManager.isRewardedReady()) {
            Toast.makeText(this, R.string.no_ad, Toast.LENGTH_SHORT).show()
            return
        }
        AdsManager.showRewarded(
            this,
            onRewarded = {
                run.revive()
                overPanel.visibility = View.GONE
                pauseButton.visibility = View.VISIBLE
                runner.playing = true
            },
            onFinished = {},
        )
    }

    private fun gameOver(run: Run) {
        runner.playing = false
        pauseButton.visibility = View.GONE
        progress.orbs += run.orbsTaken
        val best = run.score > progress.best
        if (best) progress.best = run.score
        settings.roundsPlayed += 1
        settings.roundsSinceInterstitial += 1
        findViewById<TextView>(R.id.overTitle).setText(if (best) R.string.new_best else R.string.crashed)
        findViewById<TextView>(R.id.overScore).text = run.score.toString()
        findViewById<TextView>(R.id.overStats).text = getString(R.string.over_stats, run.z.toInt(), run.orbsTaken, progress.best)
        findViewById<View>(R.id.reviveButton).visibility = if (run.revived) View.GONE else View.VISIBLE
        runner.postDelayed({
            if (isFinishing || runner.run !== run || run.alive) return@postDelayed
            overPanel.visibility = View.VISIBLE
            overPanel.alpha = 0f
            overPanel.animate().alpha(1f).setDuration(250).start()
            val card = findViewById<View>(R.id.overCard)
            card.scaleX = 0.75f
            card.scaleY = 0.75f
            card.animate().scaleX(1f).scaleY(1f).setDuration(380).setInterpolator(OvershootInterpolator(2f)).start()
        }, 900)
    }

    private fun afterRound(then: () -> Unit) {
        tap()
        AdsManager.maybeShowInterstitial(this, settings.roundsPlayed, settings.roundsSinceInterstitial) { shown ->
            if (shown) settings.roundsSinceInterstitial = 0
            then()
        }
    }

    // ---------------------------------------------------------------- skins

    private fun showSkins() {
        tap()
        skinsPanel.visibility = View.VISIBLE
        renderSkins()
    }

    private fun renderSkins() {
        findViewById<TextView>(R.id.skinsOrbs).text = getString(R.string.orbs_format, progress.orbs)
        val list = findViewById<LinearLayout>(R.id.skinList)
        list.removeAllViews()
        for (skin in Skins.all) {
            val row = LayoutInflater.from(this).inflate(R.layout.item_skin, list, false)
            row.findViewById<View>(R.id.swatch).background = NeonDrawable(skin.glow, resources.displayMetrics.density, cut = 6f)
            val name = row.findViewById<TextView>(R.id.skinName)
            name.text = skin.name
            name.setTextColor(skin.glow)
            val action = row.findViewById<Button>(R.id.skinAction)
            val owned = progress.owns(skin.id)
            action.text = when {
                progress.skin == skin.id -> getString(R.string.equipped)
                owned -> getString(R.string.owned)
                else -> getString(R.string.price_format, skin.price)
            }
            action.setOnClickListener {
                when {
                    progress.skin == skin.id -> Unit
                    owned -> {
                        tap()
                        progress.skin = skin.id
                    }
                    progress.orbs >= skin.price -> {
                        Sounds.play(GameSounds.BUY)
                        progress.orbs -= skin.price
                        progress.unlock(skin.id)
                        progress.skin = skin.id
                    }
                    else -> Toast.makeText(this, R.string.not_enough, Toast.LENGTH_SHORT).show()
                }
                runner.skin = Skins.byId(progress.skin)
                findViewById<TextView>(R.id.statsText).text = getString(R.string.stats_format, progress.best, progress.orbs)
                renderSkins()
            }
            list.addView(row)
        }
    }

    // ---------------------------------------------------------------- RunnerView.Listener

    override fun onEvents(events: List<RunEvent>) {
        val run = runner.run ?: return
        for (e in events) {
            when (e) {
                is RunEvent.OrbTaken -> Sounds.play(GameSounds.ORB, rate = 0.95f + (run.orbsTaken % 5) * 0.03f, volume = 0.7f)
                RunEvent.Jumped -> Sounds.play(GameSounds.JUMP, volume = 0.6f)
                RunEvent.Slid -> Sounds.play(GameSounds.SLIDE, volume = 0.6f)
                RunEvent.LaneChanged -> Sounds.play(GameSounds.SWOOSH, volume = 0.5f)
                is RunEvent.PowerTaken -> {
                    Sounds.play(GameSounds.POWER)
                    if (e.kind == PowerKind.BOOST) haptic(HapticFeedbackConstants.VIRTUAL_KEY)
                }
                RunEvent.ShieldBroke -> {
                    Sounds.play(GameSounds.SHIELD)
                    haptic(HapticFeedbackConstants.LONG_PRESS)
                }
                is RunEvent.Milestone -> Sounds.play(GameSounds.MILESTONE)
                is RunEvent.Crashed -> {
                    Sounds.play(GameSounds.CRASH)
                    haptic(HapticFeedbackConstants.LONG_PRESS)
                    gameOver(run)
                }
            }
        }
    }

    // ---------------------------------------------------------------- bits

    private fun tap() = Sounds.play(GameSounds.TAP)

    private fun haptic(type: Int) {
        if (settings.vibrationOn) runner.performHapticFeedback(type)
    }

    private fun renderToggles() {
        soundButton.setImageResource(if (settings.soundOn) R.drawable.ic_volume_on else R.drawable.ic_volume_off)
        soundButton.alpha = if (settings.soundOn) 1f else 0.5f
        vibrationButton.alpha = if (settings.vibrationOn) 1f else 0.35f
    }
}
