package com.hamxanadeem.wigglewars.core

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

/** Things that happened, for the screen to animate and play sounds for. */
sealed interface GameEvent {
    data class TurnStarted(val team: Int, val worm: Int, val wind: Double) : GameEvent
    data class Fired(val worm: Int, val weapon: Weapon) : GameEvent
    data class Explosion(val x: Double, val y: Double, val radius: Double, val area: Area?) : GameEvent
    data class Damaged(val worm: Int, val amount: Int) : GameEvent
    data class Died(val worm: Int) : GameEvent
    data class Drowned(val worm: Int) : GameEvent
    data class Splash(val x: Double) : GameEvent
    data class Bounced(val x: Double, val y: Double) : GameEvent
    data class Jumped(val worm: Int) : GameEvent
    data class Teleported(val worm: Int) : GameEvent
    data class ShotgunBlast(val fromX: Double, val fromY: Double, val toX: Double, val toY: Double) : GameEvent
    data class BatSwing(val worm: Int, val hit: Boolean) : GameEvent
    data class CrateDropped(val crate: Crate) : GameEvent
    data class CrateCollected(val crate: Crate, val worm: Int) : GameEvent
    data object TimeUp : GameEvent
    data class GameOver(val winner: Int?) : GameEvent
}

enum class Phase {
    /** The active worm can move, aim and fire. */
    AIM,
    /** After firing: a few seconds to run for cover. */
    RETREAT,
    /** Waiting for everything to stop moving before the next turn. */
    SETTLE,
    GAME_OVER,
}

enum class Difficulty { EASY, NORMAL, HARD }

data class TeamSetup(val name: String, val cpu: Boolean)

data class MatchConfig(
    val teams: List<TeamSetup>,
    val wormsPerTeam: Int = 3,
    val seed: Long = 1,
    val difficulty: Difficulty = Difficulty.NORMAL,
    /** Extra Banana Bombs for human teams (a rewarded-ad bonus). */
    val bonusBananas: Int = 0,
) {
    init {
        require(teams.size in 2..4) { "2 to 4 teams" }
        require(wormsPerTeam in 1..5) { "1 to 5 worms per team" }
    }
}

enum class CrateKind { HEALTH, WEAPON }

class Crate(val id: Int, val kind: CrateKind, val weapon: Weapon?, var x: Double, var y: Double) {
    var landed = false
    var gone = false
}

class Projectile(
    val id: Int,
    var x: Double,
    var y: Double,
    var vx: Double,
    var vy: Double,
    val spec: ProjectileSpec,
    val owner: Int,
    val weapon: Weapon,
) {
    var fuse: Double? = spec.fuse
    var age = 0.0
    var resting = false
    var gone = false
}

/**
 * A whole match: terrain, teams, turns, physics and weapons. Everything runs in
 * fixed steps of [STEP] seconds, so results are the same on every device.
 */
class Match(val config: MatchConfig) {

    private val random = Random(config.seed)
    val terrain: Terrain = Terrain.generate(config.seed)
    val teams: List<Team>
    val worms: List<Worm>
    val projectiles = ArrayList<Projectile>()
    val crates = ArrayList<Crate>()

    var phase = Phase.AIM
        private set
    var currentTeam = 0
        private set
    var activeWormId = 0
        private set
    var wind = 0.0
        private set
    var turnTimeLeft = TURN_SECONDS
        private set
    var retreatLeft = 0.0
        private set
    var turnNumber = 0
        private set
    var winner: Int? = null
        private set
    var selected = Weapon.BAZOOKA
        private set
    /** Physics steps taken so far. Online play stamps every input with this. */
    var stepCount = 0L
        private set

    private val ammo: Array<IntArray>
    private val wormCursor: IntArray
    private var walkDir = 0
    private var settleTime = 0.0
    private var accumulator = 0.0
    private var nextId = 1
    private val events = ArrayList<GameEvent>()

    val activeWorm: Worm get() = worms[activeWormId]

    init {
        var id = 0
        val names = WORM_NAMES.shuffled(random)
        val placed = ArrayList<Pair<Double, Double>>()
        teams = config.teams.mapIndexed { t, setup ->
            val list = List(config.wormsPerTeam) {
                val (x, y) = findSpawn(placed)
                placed += x to y
                Worm(id, t, names[id % names.size], x, y).also { w -> w.facing = if (x < terrain.width / 2) 1 else -1; id++ }
            }
            Team(t, setup.name, setup.cpu, list)
        }
        worms = teams.flatMap { it.worms }
        ammo = Array(teams.size) { t ->
            IntArray(Weapon.entries.size) { w ->
                val weapon = Weapon.entries[w]
                if (weapon == Weapon.BANANA && !teams[t].cpu) config.bonusBananas else weapon.startAmmo
            }
        }
        wormCursor = IntArray(teams.size) { -1 }
        currentTeam = random.nextInt(teams.size)
        startTurn(first = true)
    }

    private fun findSpawn(taken: List<Pair<Double, Double>>): Pair<Double, Double> {
        repeat(800) { attempt ->
            val x = terrain.width * (0.12 + random.nextDouble() * 0.76)
            val ground = terrain.groundBelow(x.toInt()) ?: return@repeat
            val y = ground - Worm.RADIUS - 1.0
            val minGap = if (attempt < 500) 90.0 else 30.0
            if (y > 30 && !collides(x, y) && taken.none { hypot(it.first - x, it.second - y) < minGap }) return x to y
        }
        return terrain.width / 2.0 to 20.0
    }

    // ---------------------------------------------------------------- queries

    fun ammo(weapon: Weapon, team: Int = currentTeam): Int = ammo[team][weapon.ordinal]

    fun hasAmmo(weapon: Weapon, team: Int = currentTeam): Boolean = ammo(weapon, team) != 0

    val isCpuTurn: Boolean get() = teams[currentTeam].cpu && phase != Phase.GAME_OVER

    val canAct: Boolean get() = phase == Phase.AIM && activeWorm.alive

    val canMove: Boolean get() = (phase == Phase.AIM || phase == Phase.RETREAT) && activeWorm.alive

    // ---------------------------------------------------------------- input

    fun walk(dir: Int) {
        walkDir = dir.coerceIn(-1, 1)
        if (walkDir != 0 && canMove) activeWorm.facing = walkDir
    }

    fun jump() = leap(forward = true)

    fun backflip() = leap(forward = false)

    private fun leap(forward: Boolean) {
        val w = activeWorm
        if (!canMove || !w.onGround) return
        w.onGround = false
        w.fallStartY = w.y
        if (forward) {
            w.vx = w.facing * JUMP_VX
            w.vy = -JUMP_VY
        } else {
            w.vx = -w.facing * BACKFLIP_VX
            w.vy = -BACKFLIP_VY
        }
        events += GameEvent.Jumped(w.id)
    }

    fun setAim(angle: Double) {
        if (canAct) activeWorm.aim = angle.coerceIn(-PI / 2, PI / 2)
    }

    fun face(dir: Int) {
        if (canAct && dir != 0) activeWorm.facing = if (dir > 0) 1 else -1
    }

    fun select(weapon: Weapon): Boolean {
        if (!canAct || !hasAmmo(weapon)) return false
        selected = weapon
        return true
    }

    /** Fires the selected weapon. [power] is 0..1 and only matters for [FireMode.POWER]. */
    fun fire(power: Double = 1.0): Boolean {
        val w = activeWorm
        val weapon = selected
        if (!canAct || !hasAmmo(weapon) || weapon.mode == FireMode.TARGET) return false
        useAmmo(weapon)
        events += GameEvent.Fired(w.id, weapon)
        when (weapon.mode) {
            FireMode.POWER -> {
                val p = power.coerceIn(MIN_POWER, 1.0)
                val sx = w.x + w.aimX * (Worm.RADIUS + 6)
                val sy = w.y + w.aimY * (Worm.RADIUS + 6)
                spawn(sx, sy, w.aimX * weapon.launchSpeed * p, w.aimY * weapon.launchSpeed * p, weapon.spec!!, w.id, weapon)
            }
            FireMode.DROP -> spawn(w.x + w.facing * 6, w.y, w.facing * 20.0, -40.0, weapon.spec!!, w.id, weapon)
            FireMode.INSTANT -> if (weapon == Weapon.SHOTGUN) shotgun(w) else bat(w)
            FireMode.TARGET -> Unit
        }
        startRetreat()
        return true
    }

    /** Fires a [FireMode.TARGET] weapon at a point on the map. */
    fun fireAt(x: Double, y: Double): Boolean {
        val w = activeWorm
        val weapon = selected
        if (!canAct || !hasAmmo(weapon) || weapon.mode != FireMode.TARGET) return false
        when (weapon) {
            Weapon.TELEPORT -> {
                if (y < 0 || y > terrain.waterY - 20 || x < 0 || x > terrain.width || collides(x, y)) return false
                useAmmo(weapon)
                events += GameEvent.Fired(w.id, weapon)
                w.x = x
                w.y = y
                w.vx = 0.0
                w.vy = 0.0
                w.onGround = false
                w.fallStartY = y
                events += GameEvent.Teleported(w.id)
                endTurnNow()
            }
            Weapon.AIRSTRIKE -> {
                useAmmo(weapon)
                events += GameEvent.Fired(w.id, weapon)
                val n = Weapon.AIRSTRIKE_MISSILES
                for (i in 0 until n) {
                    val mx = x + (i - (n - 1) / 2.0) * Weapon.AIRSTRIKE_SPACING
                    spawn(mx, -40.0 - i * 12, 0.0, 260.0, weapon.spec!!, w.id, weapon)
                }
                startRetreat()
            }
            else -> return false
        }
        return true
    }

    fun skipTurn() {
        if (phase == Phase.AIM) endTurnNow()
    }

    private fun useAmmo(weapon: Weapon) {
        val a = ammo[currentTeam]
        if (a[weapon.ordinal] > 0) a[weapon.ordinal]--
        if (!hasAmmo(selected)) selected = Weapon.BAZOOKA
    }

    private fun startRetreat() {
        phase = Phase.RETREAT
        retreatLeft = RETREAT_SECONDS
    }

    private fun endTurnNow() {
        walkDir = 0
        phase = Phase.SETTLE
        settleTime = 0.0
    }

    // ---------------------------------------------------------------- simulation

    /** Advances real time. Returns everything that happened. */
    fun update(dt: Double): List<GameEvent> {
        accumulator += dt.coerceAtMost(0.25)
        while (accumulator >= STEP) {
            accumulator -= STEP
            step()
            if (phase == Phase.GAME_OVER) {
                accumulator = 0.0
                break
            }
        }
        val out = ArrayList(events)
        events.clear()
        return out
    }

    /** Runs exactly one physics step and returns what happened. */
    fun stepOnce(): List<GameEvent> {
        if (phase != Phase.GAME_OVER) step()
        val out = ArrayList(events)
        events.clear()
        return out
    }

    /** Events queued outside a step (for example by the constructor), without stepping. */
    fun drainEvents(): List<GameEvent> {
        val out = ArrayList(events)
        events.clear()
        return out
    }

    private fun step() {
        stepCount++
        when (phase) {
            Phase.AIM -> {
                turnTimeLeft -= STEP
                if (turnTimeLeft <= 0) {
                    turnTimeLeft = 0.0
                    events += GameEvent.TimeUp
                    endTurnNow()
                }
            }
            Phase.RETREAT -> {
                retreatLeft -= STEP
                if (retreatLeft <= 0) endTurnNow()
            }
            Phase.SETTLE, Phase.GAME_OVER -> Unit
        }

        val active = activeWorm
        if (canMove && walkDir != 0 && active.onGround) walkStep(active, walkDir)
        for (w in worms) if (w.alive) physics(w)
        stepProjectiles()
        stepCrates()

        if (phase == Phase.SETTLE) settle()
    }

    private fun settle() {
        val calm = projectiles.isEmpty() && worms.all { !it.alive || it.onGround } && crates.all { it.gone || it.landed }
        if (!calm) {
            settleTime = 0.0
            return
        }
        settleTime += STEP
        if (settleTime < SETTLE_SECONDS) return
        // Worms with no health left blow up, one at a time; that may hurt others.
        val dying = worms.firstOrNull { it.alive && it.health <= 0 }
        if (dying != null) {
            dying.alive = false
            events += GameEvent.Died(dying.id)
            explode(dying.x, dying.y, DEATH_RADIUS, DEATH_DAMAGE, ownerTeam = -1)
            settleTime = 0.0
            return
        }
        val aliveTeams = teams.filter { it.alive }
        if (aliveTeams.size <= 1) {
            phase = Phase.GAME_OVER
            winner = aliveTeams.firstOrNull()?.id
            events += GameEvent.GameOver(winner)
            return
        }
        startTurn(first = false)
    }

    private fun startTurn(first: Boolean) {
        if (!first) {
            var t = currentTeam
            do t = (t + 1) % teams.size while (!teams[t].alive)
            currentTeam = t
        }
        val team = teams[currentTeam]
        var cursor = wormCursor[currentTeam]
        do cursor = (cursor + 1) % team.worms.size while (!team.worms[cursor].alive)
        wormCursor[currentTeam] = cursor
        activeWormId = team.worms[cursor].id
        turnNumber++
        wind = (random.nextDouble() * 2 - 1).let { it * abs(it) } // more calm days than storms
        turnTimeLeft = TURN_SECONDS
        phase = Phase.AIM
        walkDir = 0
        if (!hasAmmo(selected)) selected = Weapon.BAZOOKA
        events += GameEvent.TurnStarted(currentTeam, activeWormId, wind)
        if (!first && random.nextDouble() < CRATE_CHANCE) dropCrate()
    }

    private fun dropCrate() {
        val x = terrain.width * (0.15 + random.nextDouble() * 0.7)
        val kind = if (random.nextBoolean()) CrateKind.HEALTH else CrateKind.WEAPON
        val weapon = if (kind == CrateKind.WEAPON) listOf(Weapon.CLUSTER, Weapon.DYNAMITE, Weapon.AIRSTRIKE, Weapon.BANANA, Weapon.BAT).random(random) else null
        val crate = Crate(nextId++, kind, weapon, x, -30.0)
        crates += crate
        events += GameEvent.CrateDropped(crate)
    }

    // ---------------------------------------------------------------- worms

    private fun collides(x: Double, y: Double, r: Double = Worm.RADIUS): Boolean {
        if (terrain.isSolid(x, y)) return true
        for (i in 0 until SAMPLES) if (terrain.isSolid(x + COS[i] * r, y + SIN[i] * r)) return true
        return false
    }

    /** Points away from nearby ground, or null in open air. */
    private fun normalAt(x: Double, y: Double, r: Double): Pair<Double, Double>? {
        var nx = 0.0
        var ny = 0.0
        for (i in 0 until SAMPLES) {
            if (terrain.isSolid(x + COS[i] * r, y + SIN[i] * r)) {
                nx -= COS[i]
                ny -= SIN[i]
            }
        }
        val len = hypot(nx, ny)
        return if (len < 1e-6) null else nx / len to ny / len
    }

    private fun walkStep(w: Worm, dir: Int) {
        w.facing = dir
        val dx = dir * WALK_SPEED * STEP
        val nx = w.x + dx
        // Climb small steps; walls stop us.
        var moved = false
        for (up in 0..MAX_CLIMB) {
            if (!collides(nx, w.y - up)) {
                w.x = nx
                w.y -= up
                moved = true
                break
            }
        }
        if (!moved) return
        // Stick to slopes going down, or start falling off an edge.
        if (!collides(w.x, w.y + 1)) {
            var dropped = false
            for (down in 1..MAX_CLIMB) {
                if (collides(w.x, w.y + down)) {
                    w.y += down - 1
                    dropped = true
                    break
                }
            }
            if (!dropped) {
                w.onGround = false
                w.vx = dir * WALK_SPEED
                w.vy = 0.0
                w.fallStartY = w.y
            }
        }
    }

    private fun physics(w: Worm) {
        if (w.y > terrain.waterY) {
            drown(w)
            return
        }
        if (w.onGround) {
            if (!collides(w.x, w.y + 1.5)) {
                w.onGround = false
                w.fallStartY = w.y
            } else {
                return
            }
        }
        w.vy = min(w.vy + GRAVITY * STEP, MAX_FALL)
        val startX = w.x
        val startY = w.y
        val speed = hypot(w.vx, w.vy)
        val parts = max(1, ceil(speed * STEP / 2.0).toInt())
        val sx = w.vx * STEP / parts
        val sy = w.vy * STEP / parts
        for (part in 0 until parts) {
            val nx = w.x + sx
            val ny = w.y + sy
            if (!collides(nx, ny)) {
                w.x = nx
                w.y = ny
            } else if (w.vy < 0 && !collides(w.x, ny)) {
                // Rising into a slope: scrape up along it instead of stopping dead.
                w.y = ny
                w.vx *= 0.6
            } else if (w.vy < 0 && !collides(nx, w.y - 1)) {
                w.x = nx
                w.y -= 1
            } else {
                hitGround(w)
                break
            }
        }
        // Safety net: a worm that hasn't moved for a while in mid-air is resting on something.
        if (!w.onGround && abs(w.x - startX) < 0.01 && abs(w.y - startY) < 0.01) {
            if (++w.stuckSteps > STUCK_STEPS) {
                w.vx = 0.0
                w.vy = 0.0
                w.onGround = true
            }
        } else {
            w.stuckSteps = 0
        }
        if (w.x < -200 || w.x > terrain.width + 200) w.y = max(w.y, terrain.waterY + 1.0)
    }

    private fun hitGround(w: Worm) {
        val normal = normalAt(w.x, w.y, Worm.RADIUS + 1.5)
        val speed = hypot(w.vx, w.vy)
        if (normal != null && normal.second < -0.45 && speed < BOUNCE_SPEED) {
            // Landed on its feet.
            w.vx = 0.0
            w.vy = 0.0
            w.onGround = true
            var lift = 0
            while (collides(w.x, w.y) && lift < 10) {
                w.y -= 1
                lift++
            }
            val fall = w.y - w.fallStartY
            if (fall > FALL_SAFE) damage(w, min(FALL_MAX_DAMAGE, ((fall - FALL_SAFE) / 6).toInt() + 1))
            return
        }
        if (normal == null) {
            w.vx = 0.0
            w.vy = 0.0
            return
        }
        // Bounce off walls and steep slopes, losing energy.
        val dot = w.vx * normal.first + w.vy * normal.second
        if (dot < 0) {
            w.vx = (w.vx - 2 * dot * normal.first) * WORM_BOUNCE
            w.vy = (w.vy - 2 * dot * normal.second) * WORM_BOUNCE
        } else {
            // Wedged in a gap narrower than the worm: it can't move, so it rests here.
            w.vx = 0.0
            w.vy = 0.0
            w.onGround = true
            return
        }
        if (hypot(w.vx, w.vy) < 25) {
            w.vx = 0.0
            w.vy = 0.0
            if (normal.second < 0) w.onGround = true
        }
        w.fallStartY = w.y
    }

    private fun drown(w: Worm) {
        if (!w.alive) return
        w.alive = false
        w.health = 0
        events += GameEvent.Splash(w.x)
        events += GameEvent.Drowned(w.id)
        if (w.id == activeWormId && (phase == Phase.AIM || phase == Phase.RETREAT)) endTurnNow()
    }

    private fun damage(w: Worm, amount: Int) {
        if (!w.alive || amount <= 0) return
        w.health = max(0, w.health - amount)
        events += GameEvent.Damaged(w.id, amount)
        // Getting hurt on your own turn ends it.
        if (w.id == activeWormId && (phase == Phase.AIM || phase == Phase.RETREAT)) endTurnNow()
    }

    // ---------------------------------------------------------------- weapons

    private fun spawn(x: Double, y: Double, vx: Double, vy: Double, spec: ProjectileSpec, owner: Int, weapon: Weapon) {
        projectiles += Projectile(nextId++, x, y, vx, vy, spec, owner, weapon)
    }

    private fun stepProjectiles() {
        if (projectiles.isEmpty()) return
        for (p in ArrayList(projectiles)) {
            when (advance(p, STEP, wind)) {
                Outcome.EXPLODE -> {
                    p.gone = true
                    explode(p.x, p.y, p.spec.explosionRadius, p.spec.damage, ownerTeam = worms[p.owner].team)
                    p.spec.childSpec?.let { child ->
                        val n = p.spec.children
                        for (i in 0 until n) {
                            val angle = -PI / 2 + (i - (n - 1) / 2.0) * 0.5
                            val speed = 150 + random.nextDouble() * 70
                            spawn(p.x, p.y - 4, cos(angle) * speed, sin(angle) * speed, child, p.owner, p.weapon)
                        }
                    }
                }
                Outcome.SPLASH -> {
                    p.gone = true
                    events += GameEvent.Splash(p.x)
                }
                Outcome.GONE -> p.gone = true
                Outcome.BOUNCE -> events += GameEvent.Bounced(p.x, p.y)
                Outcome.NONE -> Unit
            }
        }
        projectiles.removeAll { it.gone }
    }

    private enum class Outcome { NONE, BOUNCE, EXPLODE, SPLASH, GONE }

    /** Moves a projectile one step. Shared by the real game and the AI's predictions. */
    private fun advance(p: Projectile, dt: Double, wind: Double): Outcome {
        p.age += dt
        p.fuse?.let {
            val left = it - dt
            p.fuse = left
            if (left <= 0) return Outcome.EXPLODE
        }
        if (!p.resting) {
            p.vx += wind * WIND_ACCEL * p.spec.windFactor * dt
            p.vy += GRAVITY * dt
        }
        var outcome = Outcome.NONE
        val speed = hypot(p.vx, p.vy)
        val parts = max(1, ceil(speed * dt / 2.0).toInt())
        for (k in 0 until parts) {
            val nx = p.x + p.vx * dt / parts
            val ny = p.y + p.vy * dt / parts
            val impact = p.spec.bounce == 0.0
            if (impact && hitsWorm(p, nx, ny)) {
                p.x = nx
                p.y = ny
                return Outcome.EXPLODE
            }
            if (projectileCollides(nx, ny, p.spec.radius)) {
                if (impact) {
                    p.x = nx
                    p.y = ny
                    return Outcome.EXPLODE
                }
                val normal = normalAt(nx, ny, p.spec.radius + 1.5)
                if (normal != null) {
                    val dot = p.vx * normal.first + p.vy * normal.second
                    if (dot < 0) {
                        p.vx = (p.vx - 2 * dot * normal.first) * p.spec.bounce
                        p.vy = (p.vy - 2 * dot * normal.second) * p.spec.bounce
                    }
                    if (hypot(p.vx, p.vy) > 40) outcome = Outcome.BOUNCE
                } else {
                    p.vx = -p.vx * p.spec.bounce
                    p.vy = -p.vy * p.spec.bounce
                }
                if (hypot(p.vx, p.vy) < 18 && normal != null && normal.second < -0.3) {
                    p.vx = 0.0
                    p.vy = 0.0
                    p.resting = true
                }
                break
            } else {
                p.x = nx
                p.y = ny
            }
        }
        // A resting bomb starts falling again if the ground under it is blown away.
        if (p.resting && !projectileCollides(p.x, p.y + p.spec.radius + 1, 1.0)) p.resting = false
        if (p.y > terrain.waterY) return Outcome.SPLASH
        if (p.x < -400 || p.x > terrain.width + 400 || p.y > terrain.height) return Outcome.GONE
        return outcome
    }

    private fun projectileCollides(x: Double, y: Double, r: Double): Boolean =
        terrain.isSolid(x, y) || terrain.isSolid(x + r, y) || terrain.isSolid(x - r, y) || terrain.isSolid(x, y + r) || terrain.isSolid(x, y - r)

    private fun hitsWorm(p: Projectile, x: Double, y: Double): Boolean = worms.any { w ->
        w.alive && (w.id != p.owner || p.age > 0.25) && hypot(w.x - x, w.y - y) < Worm.RADIUS + p.spec.radius
    }

    private fun explode(x: Double, y: Double, radius: Double, damageAmount: Int, ownerTeam: Int) {
        val area = terrain.carve(x, y, radius)
        events += GameEvent.Explosion(x, y, radius, area)
        val reach = radius + Worm.RADIUS
        for (w in worms) {
            if (!w.alive) continue
            val d = hypot(w.x - x, w.y - y)
            if (d >= reach) continue
            val k = 1 - d / reach
            damage(w, ceil(damageAmount * k).toInt())
            val dx = if (d < 1e-6) 0.0 else (w.x - x) / d
            val dy = if (d < 1e-6) -1.0 else (w.y - y) / d
            val push = KNOCKBACK * damageAmount * k
            w.vx = dx * push
            w.vy = dy * push - 80 * k
            w.onGround = false
            w.fallStartY = w.y
        }
        for (c in crates) if (!c.gone && hypot(c.x - x, c.y - y) < reach) c.gone = true
        for (p in projectiles) if (p.resting) p.resting = false
    }

    private fun shotgun(w: Worm) {
        var x = w.x + w.aimX * (Worm.RADIUS + 2)
        var y = w.y + w.aimY * (Worm.RADIUS + 2)
        val sx = x
        val sy = y
        var travelled = 0.0
        while (travelled < Weapon.SHOTGUN_RANGE) {
            x += w.aimX * 2
            y += w.aimY * 2
            travelled += 2
            val target = worms.firstOrNull { it.alive && it.id != w.id && hypot(it.x - x, it.y - y) < Worm.RADIUS + 1 }
            if (target != null) {
                events += GameEvent.ShotgunBlast(sx, sy, x, y)
                damage(target, Weapon.SHOTGUN_DAMAGE)
                target.vx = w.aimX * 160
                target.vy = w.aimY * 160 - 60
                target.onGround = false
                target.fallStartY = target.y
                return
            }
            if (terrain.isSolid(x, y)) {
                events += GameEvent.ShotgunBlast(sx, sy, x, y)
                explode(x, y, 12.0, 8, w.team)
                return
            }
        }
        events += GameEvent.ShotgunBlast(sx, sy, x, y)
    }

    private fun bat(w: Worm) {
        val hx = w.x + w.aimX * 12
        val hy = w.y + w.aimY * 12
        val targets = worms.filter { it.alive && it.id != w.id && hypot(it.x - hx, it.y - hy) < Weapon.BAT_RANGE }
        events += GameEvent.BatSwing(w.id, targets.isNotEmpty())
        for (t in targets) {
            damage(t, Weapon.BAT_DAMAGE)
            t.vx = w.aimX * Weapon.BAT_SPEED
            t.vy = w.aimY * Weapon.BAT_SPEED - 120
            t.onGround = false
            t.fallStartY = t.y
        }
    }

    // ---------------------------------------------------------------- crates

    private fun stepCrates() {
        for (c in crates) {
            if (c.gone) continue
            if (!c.landed) {
                c.y += CRATE_FALL * STEP
                if (projectileCollides(c.x, c.y + CRATE_HALF, 2.0)) c.landed = true
                if (c.y > terrain.waterY) {
                    c.gone = true
                    events += GameEvent.Splash(c.x)
                    continue
                }
            } else if (!projectileCollides(c.x, c.y + CRATE_HALF + 1, 2.0)) {
                c.landed = false
            }
            val taker = worms.firstOrNull { it.alive && hypot(it.x - c.x, it.y - c.y) < Worm.RADIUS + CRATE_HALF + 2 }
            if (taker != null) {
                c.gone = true
                when (c.kind) {
                    CrateKind.HEALTH -> taker.health += CRATE_HEALTH
                    CrateKind.WEAPON -> {
                        val a = ammo[taker.team]
                        val i = c.weapon!!.ordinal
                        if (a[i] >= 0) a[i]++
                    }
                }
                events += GameEvent.CrateCollected(c, taker.id)
            }
        }
        crates.removeAll { it.gone }
    }

    // ---------------------------------------------------------------- AI support

    /**
     * Predicts where a shot would explode, without changing anything. Returns null if
     * it would fall in the sea or fly off the map.
     */
    fun predict(weapon: Weapon, facing: Int, aim: Double, power: Double, from: Worm = activeWorm): Pair<Double, Double>? {
        val spec = weapon.spec ?: return null
        val ax = cos(aim) * facing
        val ay = sin(aim)
        val p = Projectile(-1, from.x + ax * (Worm.RADIUS + 6), from.y + ay * (Worm.RADIUS + 6),
            ax * weapon.launchSpeed * power, ay * weapon.launchSpeed * power, spec, from.id, weapon)
        var t = 0.0
        while (t < 8.0) {
            when (advance(p, STEP, wind)) {
                Outcome.EXPLODE -> return p.x to p.y
                Outcome.SPLASH, Outcome.GONE -> return null
                else -> Unit
            }
            t += STEP
        }
        return null
    }

    /** Clear line from [from] to [to], for the shotgun. */
    fun lineOfSight(from: Worm, to: Worm): Boolean {
        val d = hypot(to.x - from.x, to.y - from.y)
        if (d > Weapon.SHOTGUN_RANGE) return false
        val steps = (d / 2).toInt()
        for (i in 2 until steps - 2) {
            val k = i.toDouble() / steps
            if (terrain.isSolid(from.x + (to.x - from.x) * k, from.y + (to.y - from.y) * k)) return false
        }
        return true
    }

    /** Nothing solid between the sky and [worm], for air strikes. */
    fun openSky(worm: Worm): Boolean {
        var y = 0
        while (y < worm.y - Worm.RADIUS - 2) {
            if (terrain.isSolid(worm.x.toInt(), y)) return false
            y += 3
        }
        return true
    }

    companion object {
        const val STEP = 1.0 / 120.0
        const val GRAVITY = 300.0
        const val MAX_FALL = 700.0
        const val WIND_ACCEL = 160.0
        const val WALK_SPEED = 42.0
        const val MAX_CLIMB = 4
        const val JUMP_VX = 85.0
        const val JUMP_VY = 120.0
        const val BACKFLIP_VX = 30.0
        const val BACKFLIP_VY = 200.0
        const val BOUNCE_SPEED = 170.0
        const val WORM_BOUNCE = 0.35
        const val KNOCKBACK = 6.0
        const val FALL_SAFE = 110.0
        const val FALL_MAX_DAMAGE = 30
        const val TURN_SECONDS = 45.0
        const val RETREAT_SECONDS = 3.0
        const val SETTLE_SECONDS = 0.5
        const val MIN_POWER = 0.15
        const val DEATH_RADIUS = 22.0
        const val DEATH_DAMAGE = 12
        const val CRATE_CHANCE = 0.3
        const val CRATE_FALL = 90.0
        const val CRATE_HALF = 8.0
        const val CRATE_HEALTH = 25
        const val STUCK_STEPS = 24

        private const val SAMPLES = 12
        private val COS = DoubleArray(SAMPLES) { cos(it * 2 * PI / SAMPLES) }
        private val SIN = DoubleArray(SAMPLES) { sin(it * 2 * PI / SAMPLES) }

        val WORM_NAMES = listOf(
            "Noodle", "Squiggle", "Dirt Dan", "Wigglesworth", "Slimy Sam", "Captain Goo", "Mud Pie", "Twisty",
            "Boomer", "Lil' Wiggle", "Grub", "Sir Slither", "Gummy", "Spud", "Professor Wriggle", "Mudsy",
            "Squirmy", "Bubbles", "Tank", "Ziggy",
        )
    }
}
