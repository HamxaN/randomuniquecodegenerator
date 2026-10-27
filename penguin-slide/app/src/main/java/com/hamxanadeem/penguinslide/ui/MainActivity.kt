package com.hamxanadeem.penguinslide.ui

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
import com.hamxanadeem.penguinslide.R
import com.hamxanadeem.penguinslide.ads.AdsManager
import com.hamxanadeem.penguinslide.core.Run
import com.hamxanadeem.penguinslide.data.ProgressStore
import com.hamxanadeem.penguinslide.data.Settings
import com.hamxanadeem.penguinslide.fx.GameSounds
import com.hamxanadeem.penguinslide.fx.Sounds

/** Home screen: an autopilot penguin slides in the background behind the menu. */
class MainActivity : AppCompatActivity() {

    private lateinit var settings: Settings
    private lateinit var store: ProgressStore
    private lateinit var demo: SlideView
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

        demo = findViewById(R.id.demoView)
        demo.demo = true
        demo.start(Run(System.currentTimeMillis()))

        playButton = findViewById(R.id.playButton)
        soundButton = findViewById(R.id.soundButton)
        vibrationButton = findViewById(R.id.vibrationButton)
        playButton.setOnClickListener {
            Sounds.play(GameSounds.TAP)
            startActivity(Intent(this, GameActivity::class.java))
        }
        findViewById<Button>(R.id.skinsButton).setOnClickListener {
            Sounds.play(GameSounds.TAP)
            startActivity(Intent(this, ShopActivity::class.java))
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
            PropertyValuesHolder.ofFloat(View.SCALE_X, 1f, 1.06f),
            PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f, 1.06f),
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
        demo.skin = progress.skin
        demo.paused = false
        findViewById<TextView>(R.id.bestText).text = getString(R.string.best_format, progress.bestDistance, progress.bestScore)
        findViewById<TextView>(R.id.fishText).text = getString(R.string.fish_format, progress.fish)
        findViewById<Button>(R.id.privacyButton).visibility =
            if (AdsManager.isPrivacyOptionsRequired(this)) View.VISIBLE else View.GONE
        renderToggles()
        pulse?.start()
    }

    override fun onPause() {
        super.onPause()
        demo.paused = true
        pulse?.cancel()
        playButton.scaleX = 1f
        playButton.scaleY = 1f
    }
}
