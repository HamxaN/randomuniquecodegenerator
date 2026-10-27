package com.hamxanadeem.screwpuzzle.ui

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.content.Intent
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.hamxanadeem.screwpuzzle.R
import com.hamxanadeem.screwpuzzle.ads.AdsManager
import com.hamxanadeem.screwpuzzle.core.LevelGenerator
import com.hamxanadeem.screwpuzzle.core.Puzzle
import com.hamxanadeem.screwpuzzle.data.ProgressStore
import com.hamxanadeem.screwpuzzle.data.Settings
import com.hamxanadeem.screwpuzzle.fx.GameSounds
import com.hamxanadeem.screwpuzzle.fx.Sounds

/** Home: a puzzle that solves itself shows how to play, above the menu. */
class MainActivity : AppCompatActivity() {

    private lateinit var settings: Settings
    private lateinit var store: ProgressStore
    private lateinit var playButton: Button
    private lateinit var soundButton: ImageButton
    private lateinit var vibrationButton: ImageButton
    private var pulse: ObjectAnimator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        settings = Settings(this)
        store = ProgressStore(this)
        GameSounds.init(this)
        Sounds.enabled = settings.soundOn
        AdsManager.initialize(this)
        AdsManager.loadBanner(this, findViewById<FrameLayout>(R.id.bannerContainer))

        findViewById<PuzzleView>(R.id.demoView).apply {
            demo = true
            start(Puzzle(LevelGenerator.generate(2)))
        }
        playButton = findViewById(R.id.playButton)
        soundButton = findViewById(R.id.soundButton)
        vibrationButton = findViewById(R.id.vibrationButton)
        playButton.setOnClickListener {
            Sounds.play(GameSounds.TAP)
            startActivity(Intent(this, GameActivity::class.java))
        }
        soundButton.setOnClickListener {
            settings.soundOn = !settings.soundOn
            Sounds.enabled = settings.soundOn
            Sounds.play(GameSounds.TAP)
            renderToggles()
        }
        vibrationButton.setOnClickListener {
            settings.vibrationOn = !settings.vibrationOn
            if (settings.vibrationOn) it.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
            renderToggles()
        }
        findViewById<Button>(R.id.privacyButton).setOnClickListener { AdsManager.showPrivacyOptions(this) }
        pulse = ObjectAnimator.ofPropertyValuesHolder(
            playButton,
            PropertyValuesHolder.ofFloat(View.SCALE_X, 1f, 1.05f),
            PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f, 1.05f),
        ).apply {
            duration = 700
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
        }
    }

    private fun renderToggles() {
        soundButton.setImageResource(if (settings.soundOn) R.drawable.ic_volume_on else R.drawable.ic_volume_off)
        soundButton.alpha = if (settings.soundOn) 1f else 0.5f
        vibrationButton.alpha = if (settings.vibrationOn) 1f else 0.35f
    }

    override fun onResume() {
        super.onResume()
        val progress = store.load()
        playButton.text = getString(R.string.play_level, progress.level)
        findViewById<TextView>(R.id.coinsText).text = getString(R.string.coins_format, progress.coins)
        findViewById<Button>(R.id.privacyButton).visibility =
            if (AdsManager.isPrivacyOptionsRequired(this)) View.VISIBLE else View.GONE
        renderToggles()
        pulse?.start()
    }

    override fun onPause() {
        super.onPause()
        pulse?.cancel()
        playButton.scaleX = 1f
        playButton.scaleY = 1f
    }
}
