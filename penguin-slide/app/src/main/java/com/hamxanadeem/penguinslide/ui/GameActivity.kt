package com.hamxanadeem.penguinslide.ui

import android.os.Build
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.View
import android.view.animation.OvershootInterpolator
import android.widget.Button
import android.widget.ImageButton
import android.widget.TextView
import androidx.activity.addCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.hamxanadeem.penguinslide.R
import com.hamxanadeem.penguinslide.ads.AdsManager
import com.hamxanadeem.penguinslide.core.Progress
import com.hamxanadeem.penguinslide.core.Run
import com.hamxanadeem.penguinslide.core.RunEvent
import com.hamxanadeem.penguinslide.data.ProgressStore
import com.hamxanadeem.penguinslide.data.Settings
import com.hamxanadeem.penguinslide.fx.GameSounds
import com.hamxanadeem.penguinslide.fx.Sounds

class GameActivity : AppCompatActivity(), SlideView.Listener {

    private lateinit var settings: Settings
    private lateinit var store: ProgressStore
    private lateinit var progress: Progress
    private lateinit var run: Run
    private lateinit var slideView: SlideView
    private lateinit var gameOver: View
    private lateinit var card: View
    private lateinit var pauseOverlay: View
    private lateinit var reviveButton: Button
    private lateinit var doubleButton: Button

    /** True once the current run's fish and records are saved. */
    private var banked = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_game)
        settings = Settings(this)
        store = ProgressStore(this)
        GameSounds.init(this)
        Sounds.enabled = settings.soundOn

        slideView = findViewById(R.id.slideView)
        gameOver = findViewById(R.id.gameOverOverlay)
        card = findViewById(R.id.gameOverCard)
        pauseOverlay = findViewById(R.id.pauseOverlay)
        reviveButton = findViewById(R.id.reviveButton)
        doubleButton = findViewById(R.id.doubleFishButton)

        // Draw behind the status bar, but keep the HUD and buttons clear of it.
        val content = findViewById<View>(R.id.overlayContent)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.root)) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            slideView.hudTopInset = bars.top
            content.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }

        slideView.listener = this
        findViewById<ImageButton>(R.id.pauseButton).setOnClickListener { pause() }
        findViewById<Button>(R.id.resumeButton).setOnClickListener { resume() }
        findViewById<Button>(R.id.quitButton).setOnClickListener {
            Sounds.play(GameSounds.TAP)
            finish()
        }
        reviveButton.setOnClickListener { revive() }
        doubleButton.setOnClickListener { doubleFish() }
        findViewById<Button>(R.id.playAgainButton).setOnClickListener { playAgain() }
        findViewById<Button>(R.id.homeButton).setOnClickListener {
            Sounds.play(GameSounds.TAP)
            finish()
        }
        gameOver.setOnClickListener { }
        pauseOverlay.setOnClickListener { }
        onBackPressedDispatcher.addCallback(this) {
            if (gameOver.visibility == View.VISIBLE || pauseOverlay.visibility == View.VISIBLE) finish() else pause()
        }

        startRun()
    }

    private fun startRun() {
        progress = store.load()
        run = Run(System.nanoTime())
        banked = false
        slideView.skin = progress.skin
        slideView.bestDistance = progress.bestDistance
        gameOver.visibility = View.GONE
        slideView.start(run)
    }

    override fun onPause() {
        super.onPause()
        if (gameOver.visibility != View.VISIBLE) pause()
    }

    private fun pause() {
        if (run.isOver) return
        slideView.paused = true
        pauseOverlay.visibility = View.VISIBLE
    }

    private fun resume() {
        Sounds.play(GameSounds.TAP)
        pauseOverlay.visibility = View.GONE
        slideView.paused = false
    }

    // ---------------------------------------------------------------- events

    override fun onRunEvent(event: RunEvent) {
        when (event) {
            RunEvent.TakeOff -> Sounds.play(GameSounds.TAKEOFF, volume = 0.6f)
            RunEvent.PerfectLanding -> {
                Sounds.play(GameSounds.PERFECT)
                haptic(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY)
            }
            RunEvent.GoodLanding -> {
                Sounds.play(GameSounds.LAND)
                haptic(HapticFeedbackConstants.CLOCK_TICK)
            }
            RunEvent.Wipeout -> {
                Sounds.play(GameSounds.WIPEOUT)
                haptic(HapticFeedbackConstants.LONG_PRESS)
            }
            is RunEvent.Flips -> Sounds.play(GameSounds.FLIP, rate = 1f + 0.06f * (event.count - 1))
            is RunEvent.FishCaught -> Sounds.play(GameSounds.FISH, rate = 0.9f + (run.fishCaught % 5) * 0.06f)
            is RunEvent.Checkpoint -> Sounds.play(GameSounds.CHECKPOINT)
            RunEvent.FeverStart -> Sounds.play(GameSounds.FEVER)
            RunEvent.TimeUp -> Sounds.play(GameSounds.TIME_UP)
            RunEvent.FeverEnd -> Unit
        }
    }

    private fun haptic(type: Int) {
        if (settings.vibrationOn) slideView.performHapticFeedback(type)
    }

    override fun onRunOver() {
        bank()
        showGameOver()
    }

    /** Saves the run's fish and records straight away so nothing is lost. */
    private fun bank() {
        if (banked) return
        banked = true
        progress = store.load().afterRun(run)
        store.save(progress)
    }

    private fun showGameOver() {
        val previousBest = slideView.bestDistance
        findViewById<TextView>(R.id.distanceText).text = getString(R.string.distance_format, run.distance)
        findViewById<TextView>(R.id.newBestText).visibility = if (run.distance > previousBest && previousBest > 0) View.VISIBLE else View.GONE
        findViewById<TextView>(R.id.statsText).text = getString(
            R.string.stats_format, run.score, run.flips, run.perfectLandings, run.fishCaught,
        )
        reviveButton.visibility = if (run.canRevive && AdsManager.isRewardedReady()) View.VISIBLE else View.GONE
        doubleButton.visibility = if (run.fishCaught > 0 && AdsManager.isRewardedReady()) View.VISIBLE else View.GONE
        doubleButton.text = getString(R.string.double_fish, run.fishCaught * 2)

        gameOver.visibility = View.VISIBLE
        gameOver.alpha = 0f
        gameOver.animate().alpha(1f).setDuration(250).start()
        card.scaleX = 0.7f
        card.scaleY = 0.7f
        card.animate().scaleX(1f).scaleY(1f).setDuration(380).setInterpolator(OvershootInterpolator(2f)).start()
    }

    private fun revive() {
        Sounds.play(GameSounds.TAP)
        reviveButton.isEnabled = false
        AdsManager.showRewarded(
            this,
            onRewarded = {
                if (run.canRevive) {
                    // Un-bank: the run continues, its fish will be banked again at the end.
                    progress = store.load().let { it.copy(fish = it.fish - run.fishCaught) }
                    store.save(progress)
                    banked = false
                    run.revive()
                    gameOver.visibility = View.GONE
                    slideView.continueRun()
                }
            },
            onFinished = {
                reviveButton.isEnabled = true
                if (!run.canRevive) reviveButton.visibility = View.GONE
            },
        )
    }

    private fun doubleFish() {
        Sounds.play(GameSounds.TAP)
        doubleButton.isEnabled = false
        AdsManager.showRewarded(
            this,
            onRewarded = {
                progress = store.load().addFish(run.fishCaught)
                store.save(progress)
                Sounds.play(GameSounds.CHECKPOINT)
                doubleButton.visibility = View.GONE
            },
            onFinished = { doubleButton.isEnabled = true },
        )
    }

    private fun playAgain() {
        Sounds.play(GameSounds.TAP)
        settings.roundsPlayed += 1
        settings.roundsSinceInterstitial += 1
        AdsManager.maybeShowInterstitial(this, settings.roundsPlayed, settings.roundsSinceInterstitial) { shown ->
            if (shown) settings.roundsSinceInterstitial = 0
            startRun()
        }
    }
}
