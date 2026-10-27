package com.hamxanadeem.wigglewars.ui

import android.annotation.SuppressLint
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.Choreographer
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.animation.OvershootInterpolator
import android.widget.Button
import android.widget.GridLayout
import android.widget.ImageButton
import android.widget.TextView
import androidx.activity.addCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatButton
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.hamxanadeem.wigglewars.R
import com.hamxanadeem.wigglewars.ads.AdsManager
import com.hamxanadeem.wigglewars.core.Command
import com.hamxanadeem.wigglewars.core.Difficulty
import com.hamxanadeem.wigglewars.core.FireMode
import com.hamxanadeem.wigglewars.core.GameEvent
import com.hamxanadeem.wigglewars.core.Lockstep
import com.hamxanadeem.wigglewars.core.Match
import com.hamxanadeem.wigglewars.core.MatchConfig
import com.hamxanadeem.wigglewars.core.Phase
import com.hamxanadeem.wigglewars.core.TeamSetup
import com.hamxanadeem.wigglewars.core.Weapon
import com.hamxanadeem.wigglewars.data.Settings
import com.hamxanadeem.wigglewars.data.Stats
import com.hamxanadeem.wigglewars.fx.GameSounds
import com.hamxanadeem.wigglewars.fx.Sounds
import com.hamxanadeem.wigglewars.online.MoveLink

class GameActivity : AppCompatActivity(), Choreographer.FrameCallback, BattleView.Listener {

    private lateinit var settings: Settings
    private lateinit var stats: Stats
    private lateinit var match: Match
    private lateinit var ai: AiDriver
    private lateinit var battle: BattleView
    private lateinit var weaponButton: Button
    private lateinit var fireButton: Button
    private lateinit var controls: View
    private lateinit var weaponPanel: View
    private lateinit var weaponGrid: GridLayout
    private lateinit var pauseOverlay: View
    private lateinit var overOverlay: View

    private var lastFrame = 0L
    private var paused = false
    private var chargeStart = -1L
    private var lastTick = -1
    private var lastBounceSound = 0L
    private var lastHumanTeam = -1

    // Online play: null for games on this phone only.
    private var lockstep: Lockstep? = null
    private var link: MoveLink? = null
    private var lastWaitBanner = 0L
    private var warnedDesync = false
    private val online: Boolean get() = lockstep != null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_game)
        settings = Settings(this)
        stats = Stats(this)
        GameSounds.init(this)
        Sounds.enabled = settings.soundOn

        battle = findViewById(R.id.battleView)
        weaponButton = findViewById(R.id.weaponButton)
        fireButton = findViewById(R.id.fireButton)
        controls = findViewById(R.id.controls)
        weaponPanel = findViewById(R.id.weaponPanel)
        weaponGrid = findViewById(R.id.weaponGrid)
        pauseOverlay = findViewById(R.id.pauseOverlay)
        overOverlay = findViewById(R.id.overOverlay)
        battle.listener = this

        val overlay = findViewById<View>(R.id.overlayContent)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.root)) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            battle.topInset = bars.top
            overlay.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }

        bindControls()
        startMatch()
        onBackPressedDispatcher.addCallback(this) {
            when {
                weaponPanel.visibility == View.VISIBLE -> weaponPanel.visibility = View.GONE
                overOverlay.visibility == View.VISIBLE -> finish()
                else -> setPaused(!paused)
            }
        }
    }

    private fun startMatch() {
        val room = intent.getStringExtra(EXTRA_ROOM)
        val difficulty = Difficulty.entries[intent.getIntExtra(EXTRA_DIFFICULTY, 1)]
        val config = if (room != null) {
            // Every phone builds the same match from the room's seed.
            val names = intent.getStringArrayExtra(EXTRA_NAMES) ?: arrayOf("Player 1", "Player 2")
            MatchConfig(
                teams = names.map { TeamSetup(it, false) },
                wormsPerTeam = intent.getIntExtra(EXTRA_WORMS, 3),
                seed = intent.getLongExtra(EXTRA_SEED, 1L),
            )
        } else {
            val cpu = intent.getBooleanArrayExtra(EXTRA_CPU) ?: booleanArrayOf(false, true)
            MatchConfig(
                teams = cpu.mapIndexed { i, isCpu -> TeamSetup(TeamColors.names[i], isCpu) },
                wormsPerTeam = intent.getIntExtra(EXTRA_WORMS, 3),
                seed = System.nanoTime(),
                difficulty = difficulty,
                bonusBananas = intent.getIntExtra(EXTRA_BANANAS, 0),
            )
        }
        if (::ai.isInitialized) ai.shutdown()
        ai = AiDriver(difficulty)
        match = Match(config)
        link?.close()
        if (room != null) {
            val steps = Lockstep(match, intent.getIntExtra(EXTRA_SLOT, 0))
            lockstep = steps
            link = MoveLink(this, room, steps.me) { steps.receive(it) }
            findViewById<View>(R.id.pauseButton).visibility = View.GONE
            findViewById<View>(R.id.rematchButton).visibility = View.GONE
        }
        lastHumanTeam = -1
        overOverlay.visibility = View.GONE
        battle.start(match)
        handle(match.drainEvents())
        refreshControls()
    }

    // ---------------------------------------------------------------- loop

    override fun onResume() {
        super.onResume()
        lastFrame = 0L
        Choreographer.getInstance().postFrameCallback(this)
    }

    override fun onPause() {
        super.onPause()
        Choreographer.getInstance().removeFrameCallback(this)
        act(Command.Walk(0))
        if (!online && match.phase != Phase.GAME_OVER && overOverlay.visibility != View.VISIBLE) setPaused(true)
    }

    override fun onDestroy() {
        super.onDestroy()
        ai.shutdown()
        link?.close()
    }

    override fun doFrame(frameTimeNanos: Long) {
        val dt = if (lastFrame == 0L) 0.0 else ((frameTimeNanos - lastFrame) / 1e9).coerceAtMost(0.1)
        lastFrame = frameTimeNanos
        val steps = lockstep
        if (steps != null) {
            handle(steps.update(dt))
            link?.send(steps.takeOutbox())
            updateCharge()
            battle.charge = currentCharge()
            battle.humanTurn = steps.isMyTurn
            refreshControls()
            tickSound()
            onlineStatus(steps)
        } else if (!paused) {
            ai.update(match, dt)
            if (!ai.isThinking) handle(match.update(dt))
            updateCharge()
            battle.charge = if (match.isCpuTurn) ai.charge else currentCharge()
            battle.humanTurn = !match.isCpuTurn
            refreshControls()
            tickSound()
        }
        Choreographer.getInstance().postFrameCallback(this)
    }

    private fun onlineStatus(steps: Lockstep) {
        val now = SystemClock.uptimeMillis()
        if (steps.stalledFor > 2.5 && now - lastWaitBanner > 2000) {
            lastWaitBanner = now
            battle.showBanner(getString(R.string.waiting_for, match.teams[steps.driver].name), 0xFFFFFFFF.toInt())
        }
        if (steps.desynced && !warnedDesync) {
            warnedDesync = true
            android.widget.Toast.makeText(this, R.string.out_of_sync, android.widget.Toast.LENGTH_LONG).show()
        }
    }

    /** Sends an input through the online sync, or straight to the match offline. */
    private fun act(command: Command) {
        val steps = lockstep
        if (steps != null) steps.input(command) else command.applyTo(match)
    }

    private fun handle(events: List<GameEvent>) {
        if (events.isEmpty()) return
        battle.onEvents(events)
        val now = SystemClock.uptimeMillis()
        for (e in events) {
            when (e) {
                is GameEvent.Explosion -> {
                    Sounds.play(if (e.radius >= 40) GameSounds.BIG_BOOM else GameSounds.BOOM, rate = 0.9f + (e.radius % 7).toFloat() * 0.03f)
                    haptic(HapticFeedbackConstants.LONG_PRESS)
                }
                is GameEvent.Fired -> Sounds.play(
                    when (e.weapon) {
                        Weapon.SHOTGUN -> GameSounds.SHOTGUN
                        Weapon.BAT -> GameSounds.WHACK
                        Weapon.TELEPORT -> GameSounds.TELEPORT
                        else -> GameSounds.LAUNCH
                    },
                )
                is GameEvent.Damaged -> Sounds.play(GameSounds.OUCH, rate = 0.85f + (e.worm % 4) * 0.1f, volume = 0.8f)
                is GameEvent.Jumped -> Sounds.play(GameSounds.JUMP, volume = 0.7f)
                is GameEvent.Splash -> Sounds.play(GameSounds.SPLASH)
                is GameEvent.Bounced -> if (now - lastBounceSound > 90) {
                    lastBounceSound = now
                    Sounds.play(GameSounds.BOUNCE, volume = 0.6f)
                }
                is GameEvent.CrateCollected -> Sounds.play(GameSounds.CRATE)
                is GameEvent.TurnStarted -> onTurnStarted(e)
                is GameEvent.GameOver -> onGameOver(e.winner)
                else -> Unit
            }
        }
    }

    private fun onTurnStarted(e: GameEvent.TurnStarted) {
        Sounds.play(GameSounds.TURN)
        lastTick = -1
        val team = match.teams[e.team]
        val worm = match.worms[e.worm]
        val humans = match.teams.count { !it.cpu }
        val steps = lockstep
        val text = when {
            steps != null && steps.isMyTurn -> getString(R.string.online_your_turn, worm.name)
            steps != null -> "${team.name}: ${worm.name}"
            team.cpu -> "${team.name}: ${worm.name}"
            humans > 1 -> "${team.name}, your turn! (${worm.name})"
            else -> "Your turn: ${worm.name}"
        }
        battle.showBanner(text, TeamColors.colors[e.team])
        if (!team.cpu && humans > 1 && lastHumanTeam != e.team) haptic(HapticFeedbackConstants.VIRTUAL_KEY)
        if (!team.cpu) lastHumanTeam = e.team
        weaponPanel.visibility = View.GONE
    }

    private fun tickSound() {
        if (match.phase != Phase.AIM || match.isCpuTurn) return
        val left = kotlin.math.ceil(match.turnTimeLeft).toInt()
        if (left <= 5 && left != lastTick) {
            lastTick = left
            Sounds.play(GameSounds.TICK)
        }
    }

    private fun haptic(type: Int) {
        if (settings.vibrationOn) battle.performHapticFeedback(type)
    }

    // ---------------------------------------------------------------- controls

    @SuppressLint("ClickableViewAccessibility")
    private fun bindControls() {
        fun hold(id: Int, onDown: () -> Unit, onUp: () -> Unit) {
            findViewById<View>(id).setOnTouchListener { v, ev ->
                when (ev.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        v.isPressed = true
                        onDown()
                    }
                    MotionEvent.ACTION_UP -> {
                        v.isPressed = false
                        v.performClick()
                        onUp()
                    }
                    MotionEvent.ACTION_CANCEL -> {
                        v.isPressed = false
                        onUp()
                    }
                }
                true
            }
        }
        hold(R.id.leftButton, { if (humanCanMove()) act(Command.Walk(-1)) }, { act(Command.Walk(0)) })
        hold(R.id.rightButton, { if (humanCanMove()) act(Command.Walk(1)) }, { act(Command.Walk(0)) })
        findViewById<View>(R.id.jumpButton).setOnClickListener { if (humanCanMove()) act(Command.Jump) }
        findViewById<View>(R.id.backflipButton).setOnClickListener { if (humanCanMove()) act(Command.Backflip) }
        findViewById<View>(R.id.skipButton).setOnClickListener {
            if (humanCanAct()) {
                Sounds.play(GameSounds.TAP)
                act(Command.Skip)
            }
        }
        weaponButton.setOnClickListener {
            if (!humanCanAct()) return@setOnClickListener
            Sounds.play(GameSounds.TAP)
            if (weaponPanel.visibility == View.VISIBLE) weaponPanel.visibility = View.GONE else showWeapons()
        }
        hold(R.id.fireButton, { pressFire() }, { releaseFire() })
        findViewById<ImageButton>(R.id.pauseButton).setOnClickListener { setPaused(true) }
        findViewById<Button>(R.id.resumeButton).setOnClickListener { setPaused(false) }
        findViewById<Button>(R.id.quitButton).setOnClickListener { finish() }
        findViewById<Button>(R.id.rematchButton).setOnClickListener { afterMatch { startMatch() } }
        findViewById<Button>(R.id.menuButton).setOnClickListener { afterMatch { finish() } }
        pauseOverlay.setOnClickListener { }
        overOverlay.setOnClickListener { }
        weaponPanel.setOnClickListener { weaponPanel.visibility = View.GONE }
    }

    private fun myTurn() = lockstep?.isMyTurn ?: !match.isCpuTurn
    private fun humanCanMove() = myTurn() && match.canMove && !paused
    private fun humanCanAct() = myTurn() && match.canAct && !paused

    private fun pressFire() {
        if (!humanCanAct()) return
        weaponPanel.visibility = View.GONE
        when (match.selected.mode) {
            FireMode.POWER -> chargeStart = SystemClock.uptimeMillis()
            FireMode.INSTANT, FireMode.DROP -> act(Command.Fire(1.0))
            FireMode.TARGET -> battle.showBanner("Tap the map to choose a spot", 0xFFFFFFFF.toInt())
        }
    }

    private fun releaseFire() {
        if (chargeStart < 0) return
        val power = currentCharge().toDouble()
        chargeStart = -1L
        if (humanCanAct()) act(Command.Fire(power))
    }

    private fun currentCharge(): Float =
        if (chargeStart < 0) -1f else ((SystemClock.uptimeMillis() - chargeStart) / (AiDriver.CHARGE_SECONDS * 1000)).toFloat().coerceAtMost(1f)

    /** Fires automatically at full power, like the original games. */
    private fun updateCharge() {
        if (chargeStart >= 0 && SystemClock.uptimeMillis() - chargeStart > AiDriver.CHARGE_SECONDS * 1000 + 250) releaseFire()
        if (chargeStart >= 0 && !humanCanAct()) chargeStart = -1L
    }

    private var shownState = ""

    private fun refreshControls() {
        val human = myTurn() && match.phase != Phase.GAME_OVER
        val state = "$human ${match.phase} ${match.selected} ${match.ammo(match.selected)}"
        if (state == shownState) return
        shownState = state
        controls.alpha = if (human && match.canMove) 1f else 0.35f
        val ammo = match.ammo(match.selected)
        weaponButton.text = if (ammo < 0) match.selected.displayName else getString(R.string.weapon_ammo, match.selected.displayName, ammo)
        fireButton.text = getString(if (match.selected.mode == FireMode.TARGET) R.string.target else R.string.fire)
    }

    private fun showWeapons() {
        weaponGrid.removeAllViews()
        for (weapon in Weapon.entries) {
            val ammo = match.ammo(weapon)
            val button = AppCompatButton(this).apply {
                text = if (ammo < 0) getString(R.string.weapon_unlimited, weapon.displayName) else getString(R.string.weapon_count, weapon.displayName, ammo)
                isEnabled = ammo != 0
                alpha = if (ammo != 0) 1f else 0.4f
                setBackgroundResource(if (weapon == match.selected) R.drawable.bg_button_play else R.drawable.bg_button_secondary)
                setTextColor(0xFFFFFFFF.toInt())
                textSize = 13f
                isAllCaps = false
                stateListAnimator = null
                setOnClickListener {
                    Sounds.play(GameSounds.TAP)
                    act(Command.Select(weapon))
                    weaponPanel.visibility = View.GONE
                    shownState = ""
                }
            }
            val size = (resources.displayMetrics.density * 54).toInt()
            weaponGrid.addView(button, GridLayout.LayoutParams().apply {
                width = (resources.displayMetrics.density * 128).toInt()
                height = size
                setMargins(6, 6, 6, 6)
            })
        }
        weaponPanel.visibility = View.VISIBLE
    }

    // ---------------------------------------------------------------- BattleView.Listener

    override fun onAim(facing: Int, aim: Double) {
        if (!humanCanAct()) return
        // Online, only send aim changes that actually move the crosshair.
        val w = match.activeWorm
        if (online && w.facing == facing && kotlin.math.abs(w.aim - aim) < 0.004) return
        act(Command.Aim(facing, aim))
    }

    override fun onTarget(x: Double, y: Double) {
        if (!humanCanAct()) return
        val before = match.ammo(match.selected)
        act(Command.FireAt(x, y))
        if (match.ammo(match.selected) == before && match.phase == Phase.AIM) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) haptic(HapticFeedbackConstants.REJECT)
            battle.showBanner(getString(R.string.cant_go_there), 0xFFFF8A80.toInt())
        }
    }

    // ---------------------------------------------------------------- pause / game over

    private fun setPaused(value: Boolean) {
        if (online) return
        paused = value
        pauseOverlay.visibility = if (value) View.VISIBLE else View.GONE
        if (!value) lastFrame = 0L
        act(Command.Walk(0))
        chargeStart = -1L
    }

    private fun onGameOver(winner: Int?) {
        stats.matches += 1
        val humans = match.teams.filter { !it.cpu }
        val humanWon = winner != null && !match.teams[winner].cpu
        if (humanWon && humans.size == 1) stats.wins += 1
        if (online && winner == lockstep?.me) stats.wins += 1
        settings.roundsPlayed += 1
        settings.roundsSinceInterstitial += 1
        Sounds.play(GameSounds.VICTORY)
        val title = findViewById<TextView>(R.id.overTitle)
        title.text = when {
            winner == null -> getString(R.string.draw)
            online && winner == lockstep?.me -> getString(R.string.you_win)
            online -> getString(R.string.team_wins, match.teams[winner].name)
            humans.size == 1 && humanWon -> getString(R.string.you_win)
            humans.size == 1 -> getString(R.string.you_lose)
            else -> getString(R.string.team_wins, match.teams[winner].name)
        }
        title.setTextColor(if (winner != null) TeamColors.colors[winner] else 0xFFFFFFFF.toInt())
        findViewById<TextView>(R.id.overStats).text = getString(R.string.over_stats, match.turnNumber, stats.wins)
        battle.postDelayed({
            if (isFinishing) return@postDelayed
            overOverlay.visibility = View.VISIBLE
            overOverlay.alpha = 0f
            overOverlay.animate().alpha(1f).setDuration(300).start()
            val card = findViewById<View>(R.id.overCard)
            card.scaleX = 0.7f
            card.scaleY = 0.7f
            card.animate().scaleX(1f).scaleY(1f).setDuration(400).setInterpolator(OvershootInterpolator(2f)).start()
        }, 1200)
    }

    private fun afterMatch(then: () -> Unit) {
        Sounds.play(GameSounds.TAP)
        AdsManager.maybeShowInterstitial(this, settings.roundsPlayed, settings.roundsSinceInterstitial) { shown ->
            if (shown) settings.roundsSinceInterstitial = 0
            then()
        }
    }

    companion object {
        const val EXTRA_CPU = "cpu"
        const val EXTRA_WORMS = "worms"
        const val EXTRA_DIFFICULTY = "difficulty"
        const val EXTRA_BANANAS = "bananas"
        const val EXTRA_ROOM = "room"
        const val EXTRA_SLOT = "slot"
        const val EXTRA_NAMES = "names"
        const val EXTRA_SEED = "seed"
    }
}
