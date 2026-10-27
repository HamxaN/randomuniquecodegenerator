package com.hamxanadeem.idlebakery.ui

import android.os.Build
import android.os.Bundle
import android.view.Choreographer
import android.view.HapticFeedbackConstants
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.hamxanadeem.idlebakery.R
import com.hamxanadeem.idlebakery.ads.AdsManager
import com.hamxanadeem.idlebakery.core.Bakery
import com.hamxanadeem.idlebakery.core.Menu
import com.hamxanadeem.idlebakery.core.Numbers
import com.hamxanadeem.idlebakery.data.BakeryStore
import com.hamxanadeem.idlebakery.data.Settings
import com.hamxanadeem.idlebakery.fx.GameSounds
import com.hamxanadeem.idlebakery.fx.Sounds
import kotlin.math.max

/** The bakery itself. Idle games open straight into play. */
class MainActivity : AppCompatActivity(), Choreographer.FrameCallback {

    private class Row(val station: StationView, val buy: Button, val manager: Button)

    private lateinit var settings: Settings
    private lateinit var store: BakeryStore
    private lateinit var bakery: Bakery
    private lateinit var moneyText: TextView
    private lateinit var incomeText: TextView
    private lateinit var starsText: TextView
    private lateinit var boostButton: Button
    private lateinit var buyModeButton: Button
    private lateinit var franchiseButton: Button
    private lateinit var soundButton: ImageButton
    private lateinit var vibrationButton: ImageButton
    private lateinit var coinLayer: CoinLayer
    private val rows = ArrayList<Row>()

    /** 1, 10, 100, or [MAX] for "as many as I can afford". */
    private var buyMode = 1
    private var lastFrameNanos = 0L
    private var lastUiUpdate = 0L
    private var lastSave = 0L
    private var lastCoinSound = 0L
    private val lastCoinLaunch = LongArray(Menu.stations.size)
    private val from = IntArray(2)
    private val to = IntArray(2)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        settings = Settings(this)
        store = BakeryStore(this)
        bakery = store.load()
        GameSounds.init(this)
        Sounds.enabled = settings.soundOn
        AdsManager.initialize(this)
        AdsManager.loadBanner(this, findViewById<FrameLayout>(R.id.bannerContainer))

        moneyText = findViewById(R.id.moneyText)
        incomeText = findViewById(R.id.incomeText)
        starsText = findViewById(R.id.starsText)
        boostButton = findViewById(R.id.boostButton)
        buyModeButton = findViewById(R.id.buyModeButton)
        franchiseButton = findViewById(R.id.franchiseButton)
        soundButton = findViewById(R.id.soundButton)
        vibrationButton = findViewById(R.id.vibrationButton)
        coinLayer = findViewById(R.id.coinLayer)
        coinLayer.onLanded = { bumpMoney() }

        val list = findViewById<LinearLayout>(R.id.stationList)
        val inflater = LayoutInflater.from(this)
        for (i in Menu.stations.indices) {
            val view = inflater.inflate(R.layout.item_station, list, false)
            val row = Row(view.findViewById(R.id.stationView), view.findViewById(R.id.buyButton), view.findViewById(R.id.managerButton))
            row.station.index = i
            row.station.bakery = bakery
            row.station.onBake = { bake(it) }
            row.buy.setOnClickListener { buy(i) }
            row.manager.setOnClickListener { hire(i) }
            rows += row
            list.addView(view)
        }

        buyModeButton.setOnClickListener {
            buyMode = when (buyMode) {
                1 -> 10
                10 -> 100
                100 -> MAX
                else -> 1
            }
            Sounds.play(GameSounds.TAP)
            updateUi()
        }
        boostButton.setOnClickListener { boost() }
        franchiseButton.setOnClickListener { franchise() }
        soundButton.setOnClickListener {
            settings.soundOn = !settings.soundOn
            Sounds.enabled = settings.soundOn
            Sounds.play(GameSounds.TAP)
            renderToggles()
        }
        vibrationButton.setOnClickListener {
            settings.vibrationOn = !settings.vibrationOn
            haptic(HapticFeedbackConstants.VIRTUAL_KEY)
            renderToggles()
        }
        findViewById<Button>(R.id.privacyButton).setOnClickListener { AdsManager.showPrivacyOptions(this) }
        renderToggles()
    }

    override fun onResume() {
        super.onResume()
        val now = System.currentTimeMillis()
        val offline = bakery.offlineEarnings(now)
        // Restart the clock so the same time away is never paid twice.
        store.save(bakery, now)
        if (offline >= 1) showWelcomeBack(offline)
        findViewById<Button>(R.id.privacyButton).visibility =
            if (AdsManager.isPrivacyOptionsRequired(this)) View.VISIBLE else View.GONE
        lastFrameNanos = 0L
        Choreographer.getInstance().postFrameCallback(this)
        updateUi()
    }

    override fun onPause() {
        super.onPause()
        Choreographer.getInstance().removeFrameCallback(this)
        store.save(bakery, System.currentTimeMillis())
    }

    // ---------------------------------------------------------------- game loop

    override fun doFrame(frameTimeNanos: Long) {
        val dt = if (lastFrameNanos == 0L) 0.0 else ((frameTimeNanos - lastFrameNanos) / 1e9).coerceAtMost(1.0)
        lastFrameNanos = frameTimeNanos
        val now = System.currentTimeMillis()
        for (payout in bakery.tick(dt, now)) {
            val row = rows[payout.station]
            row.station.pop(payout.amount)
            // Throttle coins so fast stations don't flood the screen.
            if (now - lastCoinLaunch[payout.station] > 400) {
                lastCoinLaunch[payout.station] = now
                row.station.pastryCenterInWindow(from)
                moneyText.getLocationInWindow(to)
                coinLayer.launch(from[0], from[1], to[0] + moneyText.height / 2, to[1] + moneyText.height / 2, 3)
            }
            if (now - lastCoinSound > 110) {
                lastCoinSound = now
                Sounds.play(GameSounds.COIN, rate = 0.9f + (payout.station % 4) * 0.08f, volume = 0.6f)
            }
        }
        rows.forEach { it.station.invalidate() }
        if (now - lastUiUpdate > 100) {
            lastUiUpdate = now
            updateUi()
        }
        if (now - lastSave > 15_000) {
            lastSave = now
            store.save(bakery, now)
        }
        Choreographer.getInstance().postFrameCallback(this)
    }

    private fun updateUi() {
        val now = System.currentTimeMillis()
        moneyText.text = Numbers.format(bakery.money)
        incomeText.text = getString(R.string.income_format, Numbers.format(bakery.incomePerSecond(now)))
        starsText.text = getString(R.string.stars_format, bakery.stars, (bakery.stars * Bakery.STAR_BONUS * 100).toInt())
        val boosted = bakery.isBoosted(now)
        boostButton.text = if (boosted) {
            getString(R.string.boost_active, Numbers.duration((bakery.boostEndsAt - now) / 1000.0))
        } else {
            getString(R.string.boost)
        }
        val canBoost = AdsManager.isRewardedReady() && bakery.boostEndsAt - now < Bakery.MAX_BOOST_MILLIS - Bakery.BOOST_MILLIS
        boostButton.isEnabled = canBoost
        boostButton.alpha = if (canBoost || boosted) 1f else 0.5f
        buyModeButton.text = if (buyMode == MAX) getString(R.string.buy_max) else getString(R.string.buy_mode, buyMode)
        val stars = bakery.starsAvailable()
        franchiseButton.text = if (stars > 0) getString(R.string.franchise_ready, stars) else getString(R.string.franchise)

        for ((i, row) in rows.withIndex()) {
            val count = countFor(i)
            val cost = bakery.upgradeCost(i, count)
            val affordable = cost <= bakery.money
            row.buy.text = if (bakery.isUnlocked(i)) {
                getString(R.string.buy_button, count, Numbers.format(cost))
            } else {
                getString(R.string.unlock_button, Numbers.format(cost))
            }
            row.buy.alpha = if (affordable) 1f else 0.55f
            val showManager = bakery.isUnlocked(i) && !bakery.managers[i]
            row.manager.visibility = if (showManager) View.VISIBLE else View.GONE
            if (showManager) {
                row.manager.text = getString(R.string.hire_button, Numbers.format(bakery.managerCost(i)))
                row.manager.alpha = if (bakery.canHire(i)) 1f else 0.55f
            }
        }
    }

    private fun countFor(i: Int): Int = when {
        !bakery.isUnlocked(i) -> 1
        buyMode == MAX -> max(1, bakery.maxAffordable(i))
        else -> buyMode
    }

    private fun bumpMoney() {
        if (moneyText.scaleX > 1.01f) return
        moneyText.animate().scaleX(1.08f).scaleY(1.08f).setDuration(60).withEndAction {
            moneyText.animate().scaleX(1f).scaleY(1f).setDuration(120).start()
        }.start()
    }

    // ---------------------------------------------------------------- actions

    private fun bake(i: Int) {
        when {
            !bakery.isUnlocked(i) -> Toast.makeText(this, R.string.unlock_first, Toast.LENGTH_SHORT).show()
            bakery.tap(i) -> {
                Sounds.play(GameSounds.BAKE)
                haptic(HapticFeedbackConstants.CLOCK_TICK)
            }
        }
    }

    private fun buy(i: Int) {
        val before = bakery.levels[i]
        if (bakery.buy(i, countFor(i))) {
            val after = bakery.levels[i]
            val milestone = Menu.milestones.any { it in (before + 1)..after }
            when {
                before == 0 -> {
                    Sounds.play(GameSounds.HIRE)
                    Toast.makeText(this, getString(R.string.unlocked, Menu.stations[i].name), Toast.LENGTH_SHORT).show()
                }
                milestone -> {
                    Sounds.play(GameSounds.MILESTONE)
                    Toast.makeText(this, getString(R.string.milestone, Menu.stations[i].name), Toast.LENGTH_SHORT).show()
                }
                else -> Sounds.play(GameSounds.BUY, rate = 1f + minOf(after, 50) * 0.004f)
            }
            haptic(HapticFeedbackConstants.VIRTUAL_KEY)
        } else {
            denied()
        }
        updateUi()
    }

    private fun hire(i: Int) {
        if (bakery.hireManager(i)) {
            Sounds.play(GameSounds.HIRE)
            haptic(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY)
            Toast.makeText(this, getString(R.string.hired, Menu.stations[i].name), Toast.LENGTH_SHORT).show()
        } else {
            denied()
        }
        updateUi()
    }

    private fun denied() {
        Sounds.play(GameSounds.DENIED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) haptic(HapticFeedbackConstants.REJECT)
    }

    private fun boost() {
        Sounds.play(GameSounds.TAP)
        if (!AdsManager.isRewardedReady()) {
            Toast.makeText(this, R.string.no_ad, Toast.LENGTH_SHORT).show()
            return
        }
        AdsManager.showRewarded(
            this,
            onRewarded = {
                bakery.addBoost(System.currentTimeMillis())
                Sounds.play(GameSounds.BOOST)
                store.save(bakery, System.currentTimeMillis())
            },
            onFinished = { updateUi() },
        )
    }

    private fun showWelcomeBack(amount: Double) {
        var collected = false
        fun collect(multiplier: Int) {
            if (collected) return
            collected = true
            bakery.collectOffline(amount * multiplier)
            store.save(bakery, System.currentTimeMillis())
            Sounds.play(GameSounds.MILESTONE)
            moneyText.getLocationInWindow(to)
            coinLayer.launch(coinLayer.width / 2, coinLayer.height / 2, to[0] + moneyText.height / 2, to[1] + moneyText.height / 2, 12)
            updateUi()
        }
        val builder = MaterialAlertDialogBuilder(this)
            .setTitle(R.string.welcome_back)
            .setMessage(getString(R.string.welcome_back_message, Numbers.format(amount)))
            .setCancelable(false)
            .setPositiveButton(R.string.collect) { _, _ -> collect(1) }
        if (AdsManager.isRewardedReady()) {
            builder.setNeutralButton(R.string.collect_double) { _, _ ->
                var rewarded = false
                AdsManager.showRewarded(
                    this,
                    onRewarded = { rewarded = true },
                    onFinished = { collect(if (rewarded) 2 else 1) },
                )
            }
        }
        builder.show()
    }

    private fun franchise() {
        Sounds.play(GameSounds.TAP)
        val stars = bakery.starsAvailable()
        if (stars < 1) {
            val needed = Bakery.STAR_DIVISOR - bakery.earnedThisRun
            Toast.makeText(this, getString(R.string.franchise_locked, Numbers.format(max(0.0, needed))), Toast.LENGTH_LONG).show()
            return
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.franchise_title)
            .setMessage(getString(R.string.franchise_message, stars, (stars * Bakery.STAR_BONUS * 100).toInt()))
            .setPositiveButton(R.string.franchise_confirm) { _, _ ->
                bakery.franchise()
                store.save(bakery, System.currentTimeMillis())
                Sounds.play(GameSounds.BOOST)
                updateUi()
            }
            .setNegativeButton(R.string.not_yet, null)
            .show()
    }

    private fun renderToggles() {
        soundButton.setImageResource(if (settings.soundOn) R.drawable.ic_volume_on else R.drawable.ic_volume_off)
        soundButton.alpha = if (settings.soundOn) 1f else 0.5f
        vibrationButton.alpha = if (settings.vibrationOn) 1f else 0.35f
    }

    private fun haptic(type: Int) {
        if (settings.vibrationOn) moneyText.performHapticFeedback(type)
    }

    private companion object {
        const val MAX = -1
    }
}
