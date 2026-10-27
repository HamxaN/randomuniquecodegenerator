package com.hamxanadeem.parkingjam.ui

import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.View
import android.view.animation.OvershootInterpolator
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.hamxanadeem.parkingjam.R
import com.hamxanadeem.parkingjam.ads.AdsManager
import com.hamxanadeem.parkingjam.core.Lot
import com.hamxanadeem.parkingjam.core.LotGenerator
import com.hamxanadeem.parkingjam.core.TapResult
import com.hamxanadeem.parkingjam.data.Progress
import com.hamxanadeem.parkingjam.data.Settings
import com.hamxanadeem.parkingjam.fx.GameSounds
import com.hamxanadeem.parkingjam.fx.Sounds

/** Menu, the parking lot, hints and the level-cleared card. */
class MainActivity : AppCompatActivity(), LotView.Listener {

    private lateinit var settings: Settings
    private lateinit var progress: Progress
    private lateinit var lotView: LotView
    private lateinit var menu: View
    private lateinit var win: View
    private lateinit var soundButton: ImageButton
    private lateinit var vibrationButton: ImageButton
    private var lastCoins = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        Screen.immersive(this)
        settings = Settings(this)
        progress = Progress(this)
        GameSounds.init(this)
        Sounds.enabled = settings.soundOn
        AdsManager.initialize(this)
        AdsManager.loadBanner(this, findViewById<FrameLayout>(R.id.bannerContainer))
        Screen.padForInsets(findViewById(R.id.content))
        Screen.padForInsets(findViewById(R.id.menuContent))

        lotView = findViewById(R.id.lotView)
        menu = findViewById(R.id.menuPanel)
        win = findViewById(R.id.winPanel)
        soundButton = findViewById(R.id.soundButton)
        vibrationButton = findViewById(R.id.vibrationButton)
        lotView.listener = this

        findViewById<Button>(R.id.playButton).setOnClickListener {
            tap()
            menu.visibility = View.GONE
            loadLevel()
        }
        findViewById<View>(R.id.homeButton).setOnClickListener { showMenu() }
        findViewById<Button>(R.id.restartButton).setOnClickListener {
            tap()
            loadLevel()
        }
        findViewById<Button>(R.id.hintButton).setOnClickListener { hint() }
        findViewById<Button>(R.id.nextButton).setOnClickListener {
            tap()
            AdsManager.maybeShowInterstitial(this, settings.roundsPlayed, settings.roundsSinceInterstitial) { shown ->
                if (shown) settings.roundsSinceInterstitial = 0
                win.visibility = View.GONE
                loadLevel()
            }
        }
        findViewById<Button>(R.id.doubleButton).setOnClickListener { doubleCoins() }
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
                if (menu.visibility == View.VISIBLE) finish() else showMenu()
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

    private fun showMenu() {
        tap()
        win.visibility = View.GONE
        menu.visibility = View.VISIBLE
        findViewById<Button>(R.id.playButton).text = getString(R.string.play_level, progress.level)
        findViewById<TextView>(R.id.menuStats).text = getString(R.string.menu_stats, progress.stars, progress.coins)
    }

    private fun loadLevel() {
        lotView.lot = LotGenerator.generate(progress.level)
        render()
    }

    private fun render() {
        val lot = lotView.lot ?: return
        findViewById<TextView>(R.id.levelText).text = getString(R.string.level_format, progress.level)
        findViewById<TextView>(R.id.carsText).text = getString(R.string.cars_left, lot.cars.size, lot.bumps)
        findViewById<TextView>(R.id.coinsText).text = getString(R.string.coins_format, progress.coins)
        findViewById<Button>(R.id.hintButton).text = getString(R.string.hint_cost, HINT_COST)
    }

    private fun hint() {
        val lot = lotView.lot ?: return
        val car = lot.hint() ?: return
        if (progress.coins >= HINT_COST) {
            progress.coins -= HINT_COST
            showHint(car.id)
            return
        }
        if (!AdsManager.isRewardedReady()) {
            Toast.makeText(this, R.string.not_enough_coins, Toast.LENGTH_SHORT).show()
            return
        }
        AdsManager.showRewarded(this, onRewarded = { showHint(car.id) }, onFinished = {})
    }

    private fun showHint(id: Int) {
        Sounds.play(GameSounds.HINT)
        lotView.hintCar = id
        lotView.invalidate()
        render()
    }

    private fun doubleCoins() {
        if (!AdsManager.isRewardedReady()) {
            Toast.makeText(this, R.string.no_ad, Toast.LENGTH_SHORT).show()
            return
        }
        AdsManager.showRewarded(
            this,
            onRewarded = {
                progress.coins += lastCoins
                Sounds.play(GameSounds.COIN)
                findViewById<View>(R.id.doubleButton).visibility = View.GONE
                findViewById<TextView>(R.id.winText).text = getString(R.string.win_text, lastCoins * 2, lotView.lot?.bumps ?: 0)
                render()
            },
            onFinished = {},
        )
    }

    // ---------------------------------------------------------------- LotView.Listener

    override fun onTapped(result: TapResult) {
        when (result) {
            is TapResult.Exited -> Sounds.play(GameSounds.VROOM, rate = 0.9f + (result.car.id % 4) * 0.08f)
            is TapResult.Bumped -> {
                Sounds.play(GameSounds.HONK)
                if (settings.vibrationOn) lotView.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
            }
            TapResult.Nothing -> Unit
        }
        render()
    }

    override fun onCleared() {
        val lot: Lot = lotView.lot ?: return
        val stars = lot.stars()
        lastCoins = 10 + stars * 5 + progress.level / 5
        progress.coins += lastCoins
        progress.stars += stars
        progress.level += 1
        settings.roundsPlayed += 1
        settings.roundsSinceInterstitial += 1
        lotView.celebrate()
        Sounds.play(GameSounds.WIN)
        findViewById<TextView>(R.id.winStars).text = "★".repeat(stars) + "☆".repeat(3 - stars)
        findViewById<TextView>(R.id.winText).text = getString(R.string.win_text, lastCoins, lot.bumps)
        findViewById<View>(R.id.doubleButton).visibility = View.VISIBLE
        render()
        lotView.postDelayed({
            if (isFinishing) return@postDelayed
            win.visibility = View.VISIBLE
            win.alpha = 0f
            win.animate().alpha(1f).setDuration(250).start()
            val card = findViewById<View>(R.id.winCard)
            card.scaleX = 0.7f
            card.scaleY = 0.7f
            card.animate().scaleX(1f).scaleY(1f).setDuration(400).setInterpolator(OvershootInterpolator(2f)).start()
        }, 900)
    }

    // ---------------------------------------------------------------- bits

    private fun tap() = Sounds.play(GameSounds.TAP)

    private fun renderToggles() {
        soundButton.setImageResource(if (settings.soundOn) R.drawable.ic_volume_on else R.drawable.ic_volume_off)
        soundButton.alpha = if (settings.soundOn) 1f else 0.5f
        vibrationButton.alpha = if (settings.vibrationOn) 1f else 0.35f
    }

    private companion object {
        const val HINT_COST = 30
    }
}
