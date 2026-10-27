package com.hamxanadeem.wigglewars.ui

import android.content.Intent
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.hamxanadeem.wigglewars.R
import com.hamxanadeem.wigglewars.ads.AdsManager
import com.hamxanadeem.wigglewars.core.Difficulty
import com.hamxanadeem.wigglewars.data.Settings
import com.hamxanadeem.wigglewars.data.Stats
import com.hamxanadeem.wigglewars.fx.GameSounds
import com.hamxanadeem.wigglewars.fx.Sounds

/** Menu and match setup. */
class MainActivity : AppCompatActivity() {

    private enum class Mode { CPU, LOCAL }

    private lateinit var settings: Settings
    private lateinit var stats: Stats
    private lateinit var menu: View
    private lateinit var setup: View
    private lateinit var soundButton: ImageButton
    private lateinit var vibrationButton: ImageButton
    private var mode = Mode.CPU
    private var teams = 2
    private var worms = 3
    private var difficulty = Difficulty.NORMAL
    private var bananas = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        settings = Settings(this)
        stats = Stats(this)
        GameSounds.init(this)
        Sounds.enabled = settings.soundOn
        AdsManager.initialize(this)
        AdsManager.loadBanner(this, findViewById<FrameLayout>(R.id.bannerContainer))

        menu = findViewById(R.id.menuPanel)
        setup = findViewById(R.id.setupPanel)
        soundButton = findViewById(R.id.soundButton)
        vibrationButton = findViewById(R.id.vibrationButton)

        findViewById<Button>(R.id.cpuButton).setOnClickListener { openSetup(Mode.CPU) }
        findViewById<Button>(R.id.localButton).setOnClickListener { openSetup(Mode.LOCAL) }
        findViewById<Button>(R.id.onlineButton).setOnClickListener {
            Sounds.play(GameSounds.TAP)
            startActivity(Intent(this, OnlineActivity::class.java))
        }
        findViewById<Button>(R.id.backButton).setOnClickListener {
            Sounds.play(GameSounds.TAP)
            setup.visibility = View.GONE
            menu.visibility = View.VISIBLE
        }
        findViewById<Button>(R.id.teamsMinus).setOnClickListener { teams = (teams - 1).coerceAtLeast(2); renderSetup() }
        findViewById<Button>(R.id.teamsPlus).setOnClickListener { teams = (teams + 1).coerceAtMost(4); renderSetup() }
        findViewById<Button>(R.id.wormsMinus).setOnClickListener { worms = (worms - 1).coerceAtLeast(1); renderSetup() }
        findViewById<Button>(R.id.wormsPlus).setOnClickListener { worms = (worms + 1).coerceAtMost(5); renderSetup() }
        findViewById<Button>(R.id.difficultyButton).setOnClickListener {
            difficulty = Difficulty.entries[(difficulty.ordinal + 1) % Difficulty.entries.size]
            renderSetup()
        }
        findViewById<Button>(R.id.bananaButton).setOnClickListener { earnBananas() }
        findViewById<Button>(R.id.startButton).setOnClickListener { start() }
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
    }

    override fun onResume() {
        super.onResume()
        findViewById<TextView>(R.id.statsText).text = getString(R.string.stats_format, stats.wins, stats.matches)
        findViewById<Button>(R.id.privacyButton).visibility =
            if (AdsManager.isPrivacyOptionsRequired(this)) View.VISIBLE else View.GONE
        renderToggles()
        renderSetup()
    }

    private fun openSetup(newMode: Mode) {
        Sounds.play(GameSounds.TAP)
        mode = newMode
        menu.visibility = View.GONE
        setup.visibility = View.VISIBLE
        renderSetup()
    }

    private fun renderSetup() {
        findViewById<TextView>(R.id.setupTitle).setText(if (mode == Mode.CPU) R.string.vs_cpu else R.string.pass_and_play)
        findViewById<TextView>(R.id.teamsText).text = getString(if (mode == Mode.CPU) R.string.teams_cpu_format else R.string.teams_format, teams, teams - 1)
        findViewById<TextView>(R.id.wormsText).text = getString(R.string.worms_format, worms)
        val diff = findViewById<Button>(R.id.difficultyButton)
        diff.visibility = if (mode == Mode.CPU) View.VISIBLE else View.GONE
        diff.text = getString(R.string.difficulty_format, getString(DIFFICULTY_NAMES[difficulty.ordinal]))
        findViewById<Button>(R.id.bananaButton).text =
            if (bananas > 0) getString(R.string.bananas_ready, bananas) else getString(R.string.bananas_offer)
    }

    private fun earnBananas() {
        Sounds.play(GameSounds.TAP)
        if (bananas > 0) return
        if (!AdsManager.isRewardedReady()) {
            Toast.makeText(this, R.string.no_ad, Toast.LENGTH_SHORT).show()
            return
        }
        AdsManager.showRewarded(
            this,
            onRewarded = {
                bananas = BONUS_BANANAS
                Sounds.play(GameSounds.CRATE)
            },
            onFinished = { renderSetup() },
        )
    }

    private fun start() {
        Sounds.play(GameSounds.TAP)
        val cpu = BooleanArray(teams) { mode == Mode.CPU && it > 0 }
        startActivity(
            Intent(this, GameActivity::class.java)
                .putExtra(GameActivity.EXTRA_CPU, cpu)
                .putExtra(GameActivity.EXTRA_WORMS, worms)
                .putExtra(GameActivity.EXTRA_DIFFICULTY, difficulty.ordinal)
                .putExtra(GameActivity.EXTRA_BANANAS, bananas),
        )
        // The bonus is for one match.
        bananas = 0
    }

    private fun renderToggles() {
        soundButton.setImageResource(if (settings.soundOn) R.drawable.ic_volume_on else R.drawable.ic_volume_off)
        soundButton.alpha = if (settings.soundOn) 1f else 0.5f
        vibrationButton.alpha = if (settings.vibrationOn) 1f else 0.35f
    }

    private companion object {
        const val BONUS_BANANAS = 2
        val DIFFICULTY_NAMES = intArrayOf(R.string.easy, R.string.normal, R.string.hard)
    }
}
