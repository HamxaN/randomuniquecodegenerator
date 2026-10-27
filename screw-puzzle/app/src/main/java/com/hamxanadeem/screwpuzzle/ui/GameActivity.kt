package com.hamxanadeem.screwpuzzle.ui

import android.os.Build
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.View
import android.view.animation.OvershootInterpolator
import android.widget.Button
import android.widget.ImageButton
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.hamxanadeem.screwpuzzle.R
import com.hamxanadeem.screwpuzzle.ads.AdsManager
import com.hamxanadeem.screwpuzzle.core.LevelGenerator
import com.hamxanadeem.screwpuzzle.core.Progress
import com.hamxanadeem.screwpuzzle.core.Puzzle
import com.hamxanadeem.screwpuzzle.data.ProgressStore
import com.hamxanadeem.screwpuzzle.data.Settings
import com.hamxanadeem.screwpuzzle.fx.GameSounds
import com.hamxanadeem.screwpuzzle.fx.Sounds

class GameActivity : AppCompatActivity(), PuzzleView.Listener {

    private lateinit var settings: Settings
    private lateinit var store: ProgressStore
    private lateinit var progress: Progress
    private lateinit var puzzle: Puzzle
    private lateinit var puzzleView: PuzzleView
    private lateinit var wonOverlay: View
    private lateinit var stuckOverlay: View
    private lateinit var doubleButton: Button
    private lateinit var extraSlotButton: Button
    private var rewardFor = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_game)
        settings = Settings(this)
        store = ProgressStore(this)
        GameSounds.init(this)
        Sounds.enabled = settings.soundOn

        puzzleView = findViewById(R.id.puzzleView)
        wonOverlay = findViewById(R.id.wonOverlay)
        stuckOverlay = findViewById(R.id.stuckOverlay)
        doubleButton = findViewById(R.id.doubleButton)
        extraSlotButton = findViewById(R.id.extraSlotButton)
        puzzleView.listener = this
        // Leave room for the HUD row above the boxes.
        puzzleView.topInset = (64 * resources.displayMetrics.density).toInt()

        findViewById<ImageButton>(R.id.homeButton).setOnClickListener {
            Sounds.play(GameSounds.TAP)
            finish()
        }
        findViewById<ImageButton>(R.id.restartButton).setOnClickListener {
            Sounds.play(GameSounds.TAP)
            loadLevel()
        }
        findViewById<Button>(R.id.nextButton).setOnClickListener { next() }
        doubleButton.setOnClickListener { doubleCoins() }
        extraSlotButton.setOnClickListener { requestExtraSlot() }
        findViewById<Button>(R.id.retryButton).setOnClickListener {
            Sounds.play(GameSounds.TAP)
            loadLevel()
        }
        wonOverlay.setOnClickListener { }
        stuckOverlay.setOnClickListener { }
        loadLevel()
    }

    private fun loadLevel() {
        progress = store.load()
        puzzle = Puzzle(LevelGenerator.generate(progress.level))
        wonOverlay.visibility = View.GONE
        stuckOverlay.visibility = View.GONE
        findViewById<TextView>(R.id.levelText).text = getString(R.string.level_format, progress.level)
        findViewById<TextView>(R.id.coinsText).text = getString(R.string.coins_format, progress.coins)
        puzzleView.start(puzzle)
    }

    private fun haptic(type: Int) {
        if (settings.vibrationOn) puzzleView.performHapticFeedback(type)
    }

    // ---------------------------------------------------------------- puzzle events

    override fun onScrewMoved(toBox: Boolean) {
        Sounds.play(GameSounds.UNSCREW, volume = 0.7f)
        puzzleView.postDelayed({ Sounds.play(if (toBox) GameSounds.CLINK else GameSounds.TRAY) }, 450)
        haptic(HapticFeedbackConstants.CLOCK_TICK)
    }

    override fun onBlocked() {
        Sounds.play(GameSounds.BLOCKED)
        haptic(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS)
    }

    override fun onBoxCompleted() {
        Sounds.play(GameSounds.BOX)
        haptic(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY)
    }

    override fun onPlateFreed() {
        Sounds.play(GameSounds.PLATE, volume = 0.8f)
    }

    override fun onWon() {
        if (isFinishing) return
        Sounds.play(GameSounds.WIN)
        rewardFor = Progress.reward(puzzle.level.number)
        progress = store.load().completeLevel(puzzle)
        store.save(progress)
        settings.roundsPlayed += 1
        settings.roundsSinceInterstitial += 1
        findViewById<TextView>(R.id.coinsText).text = getString(R.string.coins_format, progress.coins)
        findViewById<TextView>(R.id.wonCoinsText).text = getString(R.string.won_coins, rewardFor)
        doubleButton.visibility = if (AdsManager.isRewardedReady()) View.VISIBLE else View.GONE
        show(wonOverlay)
    }

    override fun onStuck() {
        if (isFinishing || !puzzle.isStuck) return
        Sounds.play(GameSounds.STUCK)
        extraSlotButton.visibility = if (!puzzle.extraSlotUsed && AdsManager.isRewardedReady()) View.VISIBLE else View.GONE
        show(stuckOverlay)
    }

    override fun onExtraSlotTapped() {
        Sounds.play(GameSounds.TAP)
        requestExtraSlot()
    }

    // ---------------------------------------------------------------- overlays and ads

    private fun show(overlay: View) {
        overlay.visibility = View.VISIBLE
        overlay.alpha = 0f
        overlay.animate().alpha(1f).setDuration(250).start()
        val card = (overlay as android.view.ViewGroup).getChildAt(0)
        card.scaleX = 0.7f
        card.scaleY = 0.7f
        card.animate().scaleX(1f).scaleY(1f).setDuration(380).setInterpolator(OvershootInterpolator(2f)).start()
    }

    private fun requestExtraSlot() {
        if (puzzle.extraSlotUsed) {
            Toast.makeText(this, R.string.extra_slot_used, Toast.LENGTH_SHORT).show()
            return
        }
        if (!AdsManager.isRewardedReady()) {
            Toast.makeText(this, R.string.no_ad, Toast.LENGTH_SHORT).show()
            return
        }
        extraSlotButton.isEnabled = false
        AdsManager.showRewarded(
            this,
            onRewarded = {
                if (puzzle.addTraySlot()) {
                    Sounds.play(GameSounds.BOX)
                    stuckOverlay.visibility = View.GONE
                    puzzleView.refresh()
                }
            },
            onFinished = { extraSlotButton.isEnabled = true },
        )
    }

    private fun doubleCoins() {
        Sounds.play(GameSounds.TAP)
        doubleButton.isEnabled = false
        AdsManager.showRewarded(
            this,
            onRewarded = {
                progress = store.load().addCoins(rewardFor)
                store.save(progress)
                findViewById<TextView>(R.id.coinsText).text = getString(R.string.coins_format, progress.coins)
                findViewById<TextView>(R.id.wonCoinsText).text = getString(R.string.won_coins, rewardFor * 2)
                doubleButton.visibility = View.GONE
                Sounds.play(GameSounds.BOX)
            },
            onFinished = { doubleButton.isEnabled = true },
        )
    }

    private fun next() {
        Sounds.play(GameSounds.TAP)
        AdsManager.maybeShowInterstitial(this, settings.roundsPlayed, settings.roundsSinceInterstitial) { shown ->
            if (shown) settings.roundsSinceInterstitial = 0
            loadLevel()
        }
    }
}
