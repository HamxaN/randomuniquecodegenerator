package com.hamxanadeem.tidyroom.ui

import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.View
import android.view.animation.OvershootInterpolator
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import com.hamxanadeem.tidyroom.R
import com.hamxanadeem.tidyroom.ads.AdsManager
import com.hamxanadeem.tidyroom.core.DropResult
import com.hamxanadeem.tidyroom.core.RoomGenerator
import com.hamxanadeem.tidyroom.data.Progress
import com.hamxanadeem.tidyroom.data.Settings
import com.hamxanadeem.tidyroom.fx.GameSounds
import com.hamxanadeem.tidyroom.fx.Sounds

/** Menu, the room being tidied, hints and the "tidied!" card. */
class MainActivity : AppCompatActivity(), RoomView.Listener {

    private lateinit var settings: Settings
    private lateinit var progress: Progress
    private lateinit var roomView: RoomView
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

        roomView = findViewById(R.id.roomView)
        menu = findViewById(R.id.menuPanel)
        win = findViewById(R.id.winPanel)
        soundButton = findViewById(R.id.soundButton)
        vibrationButton = findViewById(R.id.vibrationButton)
        roomView.listener = this

        findViewById<Button>(R.id.playButton).setOnClickListener {
            tap()
            menu.visibility = View.GONE
        }
        findViewById<View>(R.id.homeButton).setOnClickListener { showMenu() }
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
        loadLevel()
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
        win.visibility = View.GONE
        menu.visibility = View.VISIBLE
        findViewById<Button>(R.id.playButton).text = getString(R.string.play_level, progress.level)
        findViewById<TextView>(R.id.menuStats).text = getString(R.string.menu_stats, progress.stars, progress.coins)
    }

    private fun loadLevel() {
        roomView.room = RoomGenerator.generate(progress.level)
        render()
    }

    private fun render() {
        val room = roomView.room ?: return
        findViewById<TextView>(R.id.levelText).text = getString(R.string.level_format, room.kind.displayName, progress.level)
        val bar = findViewById<ProgressBar>(R.id.tidyBar)
        bar.max = room.items.size
        bar.progress = room.placedCount
        findViewById<TextView>(R.id.coinsText).text = getString(R.string.coins_format, progress.coins)
        findViewById<Button>(R.id.hintButton).text = getString(R.string.hint_cost, HINT_COST)
    }

    private fun hint() {
        val room = roomView.room ?: return
        val (item, slot) = room.hint() ?: return
        if (progress.coins >= HINT_COST) {
            progress.coins -= HINT_COST
            showHint(item.id, slot.id)
            return
        }
        if (!AdsManager.isRewardedReady()) {
            Toast.makeText(this, R.string.not_enough_coins, Toast.LENGTH_SHORT).show()
            return
        }
        AdsManager.showRewarded(this, onRewarded = { showHint(item.id, slot.id) }, onFinished = {})
    }

    private fun showHint(item: Int, slot: Int) {
        Sounds.play(GameSounds.PICK)
        roomView.hint = item to slot
        roomView.invalidate()
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
                findViewById<TextView>(R.id.winText).text = getString(R.string.win_text, lastCoins * 2, roomView.room?.mistakes ?: 0)
                render()
            },
            onFinished = {},
        )
    }

    // ---------------------------------------------------------------- RoomView.Listener

    override fun onPickedUp() = Sounds.play(GameSounds.PICK, volume = 0.6f)

    override fun onDropped(result: DropResult) {
        when (result) {
            is DropResult.Placed -> {
                Sounds.play(GameSounds.PLACE, rate = 0.95f + (roomView.room?.placedCount ?: 0) * 0.02f)
                if (settings.vibrationOn) roomView.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
            }
            is DropResult.Missed -> if (result.wrongSlot != null) Sounds.play(GameSounds.MISS)
        }
        render()
    }

    override fun onTidy() {
        val room = roomView.room ?: return
        val stars = room.stars()
        lastCoins = 10 + stars * 5 + room.items.size
        progress.coins += lastCoins
        progress.stars += stars
        progress.level += 1
        settings.roundsPlayed += 1
        settings.roundsSinceInterstitial += 1
        roomView.celebrate()
        Sounds.play(GameSounds.TIDY)
        findViewById<TextView>(R.id.winTitle).text = getString(R.string.tidied, room.kind.displayName)
        findViewById<TextView>(R.id.winStars).text = "★".repeat(stars) + "☆".repeat(3 - stars)
        findViewById<TextView>(R.id.winText).text = getString(R.string.win_text, lastCoins, room.mistakes)
        findViewById<View>(R.id.doubleButton).visibility = View.VISIBLE
        render()
        roomView.postDelayed({
            if (isFinishing) return@postDelayed
            win.visibility = View.VISIBLE
            win.alpha = 0f
            win.animate().alpha(1f).setDuration(250).start()
            val card = findViewById<View>(R.id.winCard)
            card.scaleX = 0.7f
            card.scaleY = 0.7f
            card.animate().scaleX(1f).scaleY(1f).setDuration(400).setInterpolator(OvershootInterpolator(2f)).start()
        }, 1100)
    }

    // ---------------------------------------------------------------- bits

    private fun tap() = Sounds.play(GameSounds.TAP)

    private fun renderToggles() {
        soundButton.setImageResource(if (settings.soundOn) R.drawable.ic_volume_on else R.drawable.ic_volume_off)
        soundButton.alpha = if (settings.soundOn) 1f else 0.5f
        vibrationButton.alpha = if (settings.vibrationOn) 1f else 0.35f
    }

    private companion object {
        const val HINT_COST = 25
    }
}
