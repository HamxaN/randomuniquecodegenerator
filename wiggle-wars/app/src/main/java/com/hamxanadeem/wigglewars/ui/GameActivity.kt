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
import android.graphics.drawable.BitmapDrawable
import android.widget.Button
import android.widget.ImageButton
import android.widget.TextView
import androidx.activity.addCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.hamxanadeem.wigglewars.R
import com.hamxanadeem.wigglewars.ads.AdsManager
import com.hamxanadeem.wigglewars.core.Arena
import com.hamxanadeem.wigglewars.core.Campaign
import com.hamxanadeem.wigglewars.core.Mission
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
import com.hamxanadeem.wigglewars.core.WeaponSet
import com.hamxanadeem.wigglewars.data.Progress
import com.hamxanadeem.wigglewars.data.Settings
import com.hamxanadeem.wigglewars.data.Stats
import com.hamxanadeem.wigglewars.fx.GameSounds
import com.hamxanadeem.wigglewars.fx.Sounds
import com.hamxanadeem.wigglewars.online.MoveLink

class GameActivity : AppCompatActivity(), Choreographer.FrameCallback, BattleView.Listener {

    private lateinit var settings: Settings
    private lateinit var stats: Stats
    private lateinit var progress: Progress
    private lateinit var coach: TextView
    private lateinit var ffButton: Button
    /** The campaign mission being played, or null. */
    private var mission: Mission? = null
    private var missionNumber = 0
    /** Tutorial step shown, or -1 when off. */
    private var tip = -1
    private var tipShownAt = 0L
    private lateinit var match: Match
    private lateinit var ai: AiDriver
    private lateinit var battle: BattleView
    private lateinit var weaponButton: Button
    private lateinit var fireButton: Button
    private lateinit var controls: View
    private lateinit var weaponPanel: View
    private lateinit var picker: WeaponPickerView
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
        Screen.immersive(this)
        settings = Settings(this)
        stats = Stats(this)
        progress = Progress(this)
        coach = findViewById(R.id.coachText)
        ffButton = findViewById(R.id.ffButton)
        missionNumber = intent.getIntExtra(EXTRA_MISSION, 0)
        GameSounds.init(this)
        Sounds.enabled = settings.soundOn

        battle = findViewById(R.id.battleView)
        weaponButton = findViewById(R.id.weaponButton)
        fireButton = findViewById(R.id.fireButton)
        controls = findViewById(R.id.controls)
        weaponPanel = findViewById(R.id.weaponPanel)
        picker = findViewById(R.id.weaponPicker)
        pauseOverlay = findViewById(R.id.pauseOverlay)
        overOverlay = findViewById(R.id.overOverlay)
        battle.listener = this

        val overlay = findViewById<View>(R.id.overlayContent)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.root)) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            battle.topInset = bars.top
            battle.leftInset = bars.left
            battle.rightInset = bars.right
            battle.bottomInset = bars.bottom
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
        mission = if (missionNumber in 1..Campaign.missions.size) Campaign.mission(missionNumber) else null
        val difficulty = mission?.difficulty ?: Difficulty.entries[intent.getIntExtra(EXTRA_DIFFICULTY, 1)]
        val weaponSet = intent.getStringExtra(EXTRA_WEAPONS)?.let { name -> WeaponSet.entries.firstOrNull { it.name == name } } ?: WeaponSet.STANDARD
        // Offline with no arena chosen ("random"): a different one each rematch. Online, the room decides.
        val arena = intent.getStringExtra(EXTRA_ARENA)?.let { name -> Arena.entries.firstOrNull { it.name == name } }
            ?: if (room != null) Arena.HILLS else Arena.entries.random()
        val m = mission
        val config = if (m != null) {
            m.config(seed = System.nanoTime(), bonusAmmo = progress.bonusAmmo())
        } else if (room != null) {
            // Every phone builds the same match from the room's seed.
            val names = intent.getStringArrayExtra(EXTRA_NAMES) ?: arrayOf("Player 1", "Player 2")
            MatchConfig(
                teams = names.map { TeamSetup(it, false) },
                wormsPerTeam = intent.getIntExtra(EXTRA_WORMS, 3),
                seed = intent.getLongExtra(EXTRA_SEED, 1L),
                arena = arena,
                weaponSet = weaponSet,
            )
        } else {
            val cpu = intent.getBooleanArrayExtra(EXTRA_CPU) ?: booleanArrayOf(false, true)
            MatchConfig(
                teams = cpu.mapIndexed { i, isCpu -> TeamSetup(TeamColors.names[i], isCpu) },
                wormsPerTeam = intent.getIntExtra(EXTRA_WORMS, 3),
                seed = System.nanoTime(),
                difficulty = difficulty,
                bonusBananas = intent.getIntExtra(EXTRA_BANANAS, 0),
                arena = arena,
                weaponSet = weaponSet,
                bonusAmmo = progress.bonusAmmo(),
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
        if (m != null) battle.setIntro("MISSION ${m.number}: ${m.title.uppercase()}", m.brief)
        // First battle on this phone: walk through the controls.
        tip = if (!progress.tutorialDone && !online) 0 else -1
        renderCoach()
        ffButton.visibility = if (online) View.GONE else View.VISIBLE
        renderFastForward()
        handle(match.drainEvents())
        refreshControls()
    }

    // ---------------------------------------------------------------- loop

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) Screen.immersive(this)
    }

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
            // Fast forward everything except your own aiming and running.
            val humanMoving = !match.isCpuTurn && (match.phase == Phase.AIM || match.phase == Phase.RETREAT)
            val speed = if (progress.fastForward && !humanMoving) 3.0 else 1.0
            ai.update(match, dt * speed)
            if (!ai.isThinking) handle(match.update(dt * speed))
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
                is GameEvent.Fired -> when (e.weapon) {
                    Weapon.SHOTGUN -> Sounds.play(GameSounds.SHOTGUN)
                    Weapon.UZI -> Sounds.play(GameSounds.SHOTGUN, rate = 1.7f, volume = 0.8f)
                    Weapon.SNIPER -> Sounds.play(GameSounds.SHOTGUN, rate = 0.7f)
                    Weapon.BAT -> Sounds.play(GameSounds.WHACK)
                    Weapon.TELEPORT -> Sounds.play(GameSounds.TELEPORT)
                    Weapon.GIRDER -> Sounds.play(GameSounds.WHACK, rate = 1.5f)
                    Weapon.MINE, Weapon.SHEEP -> Sounds.play(GameSounds.JUMP)
                    else -> Sounds.play(GameSounds.LAUNCH)
                }
                is GameEvent.WaterRose -> if (e.first) waterNotice = true
                is GameEvent.Split -> Sounds.play(GameSounds.LAUNCH, rate = 1.4f)
                is GameEvent.Carved -> if (now - lastBounceSound > 120) {
                    lastBounceSound = now
                    Sounds.play(GameSounds.BOUNCE, rate = 0.5f, volume = 0.4f)
                }
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
        val sub = if (waterNotice) getString(R.string.sudden_death) else null
        waterNotice = false
        battle.showBanner(text, TeamColors.colors[e.team], sub)
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
        hold(R.id.leftButton, { if (humanCanMove()) { act(Command.Walk(-1)); tutorialStep(3) } }, { act(Command.Walk(0)) })
        hold(R.id.rightButton, { if (humanCanMove()) { act(Command.Walk(1)); tutorialStep(3) } }, { act(Command.Walk(0)) })
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
        findViewById<Button>(R.id.tipsButton).setOnClickListener {
            setPaused(false)
            tip = 0
            renderCoach()
        }
        ffButton.setOnClickListener {
            Sounds.play(GameSounds.TAP)
            progress.fastForward = !progress.fastForward
            renderFastForward()
        }
        coach.setOnClickListener { nextTip() }
        findViewById<Button>(R.id.nextButton).setOnClickListener {
            afterMatch {
                missionNumber += 1
                startMatch()
            }
        }
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
            FireMode.INSTANT, FireMode.DROP -> {
                act(Command.Fire(1.0))
                tutorialStep(1)
            }
            FireMode.TARGET -> battle.showBanner("Tap the map to choose a spot", 0xFFFFFFFF.toInt())
        }
    }

    private fun releaseFire() {
        if (chargeStart < 0) return
        val power = currentCharge().toDouble()
        chargeStart = -1L
        if (humanCanAct()) {
            battle.previewPower = power.toFloat()
            act(Command.Fire(power))
            tutorialStep(1)
        }
    }

    private fun currentCharge(): Float =
        if (chargeStart < 0) -1f else ((SystemClock.uptimeMillis() - chargeStart) / (AiDriver.CHARGE_SECONDS * 1000)).toFloat().coerceAtMost(1f)

    /** Fires automatically at full power, like the original games. */
    private fun updateCharge() {
        if (chargeStart >= 0 && SystemClock.uptimeMillis() - chargeStart > AiDriver.CHARGE_SECONDS * 1000 + 250) releaseFire()
        if (chargeStart >= 0 && !humanCanAct()) chargeStart = -1L
    }

    private var shownState = ""
    private var waterNotice = false

    private fun refreshControls() {
        val human = myTurn() && match.phase != Phase.GAME_OVER
        val state = "$human ${match.phase} ${match.selected} ${match.ammo(match.selected)}"
        if (state == shownState) return
        shownState = state
        controls.alpha = if (human && match.canMove) 1f else 0.35f
        val ammo = match.ammo(match.selected)
        weaponButton.text = if (ammo < 0) match.selected.displayName else getString(R.string.weapon_ammo, match.selected.displayName, ammo)
        val iconSize = (resources.displayMetrics.density * 30).toInt()
        val icon = BitmapDrawable(resources, WeaponIcons.bitmap(match.selected, iconSize))
        weaponButton.setCompoundDrawablesRelativeWithIntrinsicBounds(icon, null, null, null)
        fireButton.text = getString(if (match.selected.mode == FireMode.TARGET) R.string.target else R.string.fire)
    }

    private fun showWeapons() {
        picker.ammoOf = { match.ammo(it) }
        picker.listener = object : WeaponPickerView.Listener {
            override fun onEquip(weapon: Weapon) {
                Sounds.play(GameSounds.TAP)
                if (humanCanAct()) act(Command.Select(weapon))
                weaponPanel.visibility = View.GONE
                shownState = ""
            }

            override fun onClose() {
                Sounds.play(GameSounds.TAP)
                weaponPanel.visibility = View.GONE
            }
        }
        picker.open(match.selected)
        weaponPanel.visibility = View.VISIBLE
        tutorialStep(2)
    }

    // ---------------------------------------------------------------- BattleView.Listener

    override fun onAim(facing: Int, aim: Double) {
        if (!humanCanAct()) return
        // Online, only send aim changes that actually move the crosshair.
        val w = match.activeWorm
        if (online && w.facing == facing && kotlin.math.abs(w.aim - aim) < 0.004) return
        act(Command.Aim(facing, aim))
        tutorialStep(0)
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
        val statsText = findViewById<TextView>(R.id.overStats)
        statsText.text = getString(R.string.over_stats, match.turnNumber, stats.wins)
        val next = findViewById<Button>(R.id.nextButton)
        next.visibility = View.GONE
        findViewById<Button>(R.id.rematchButton).setText(R.string.rematch)
        val m = mission
        if (m != null) {
            // Stars and coins for the campaign.
            val won = winner == 0
            val lost = match.teams[0].worms.count { !it.alive }
            val stars = Campaign.stars(m, won, lost, match.turnNumber)
            val coins = Campaign.coins(stars, progress.stars(m.number))
            progress.setStars(m.number, stars)
            progress.coins += coins
            title.text = getString(if (won) R.string.mission_complete else R.string.mission_failed)
            title.setTextColor(if (won) Neon.LIME else Neon.RED)
            val starText = "★".repeat(stars) + "☆".repeat(3 - stars)
            statsText.text = getString(R.string.mission_result, starText, coins, match.turnNumber, m.parTurns)
            findViewById<Button>(R.id.rematchButton).setText(R.string.retry)
            if (won && m.number < Campaign.missions.size) next.visibility = View.VISIBLE
        } else if (!online && humans.size == 1) {
            val coins = if (humanWon) 40 else 10
            progress.coins += coins
            statsText.text = getString(R.string.battle_reward, coins, progress.coins)
        }
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

    // ---------------------------------------------------------------- tutorial and speed

    private fun renderFastForward() {
        ffButton.text = if (progress.fastForward) "3×" else "1×"
        ffButton.alpha = if (progress.fastForward) 1f else 0.7f
    }

    private fun renderCoach() {
        val text = TIPS.getOrNull(tip)
        if (text == null) {
            coach.visibility = View.GONE
            return
        }
        coach.text = getString(text)
        coach.visibility = View.VISIBLE
        coach.alpha = 0f
        coach.animate().alpha(1f).setDuration(250).start()
        tipShownAt = SystemClock.uptimeMillis()
    }

    private fun nextTip() {
        if (tip < 0) return
        Sounds.play(GameSounds.TAP)
        tip++
        if (tip >= TIPS.size) {
            tip = -1
            progress.tutorialDone = true
        }
        renderCoach()
    }

    /** Moves the tutorial on when the player does what the current tip asks. */
    private fun tutorialStep(done: Int) {
        if (tip == done && SystemClock.uptimeMillis() - tipShownAt > 600) nextTip()
    }

    companion object {
        private val TIPS = intArrayOf(R.string.tip_aim, R.string.tip_fire, R.string.tip_weapons, R.string.tip_move)
        const val EXTRA_MISSION = "mission"
        const val EXTRA_CPU = "cpu"
        const val EXTRA_WORMS = "worms"
        const val EXTRA_DIFFICULTY = "difficulty"
        const val EXTRA_BANANAS = "bananas"
        const val EXTRA_ROOM = "room"
        const val EXTRA_SLOT = "slot"
        const val EXTRA_NAMES = "names"
        const val EXTRA_SEED = "seed"
        const val EXTRA_ARENA = "arena"
        const val EXTRA_WEAPONS = "weapons"
    }
}
