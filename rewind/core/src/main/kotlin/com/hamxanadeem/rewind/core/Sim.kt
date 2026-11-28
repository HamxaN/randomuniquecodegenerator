package com.hamxanadeem.rewind.core

import kotlin.math.atan2
import kotlin.math.max

class Enemy(
    val id: Int,
    val kind: EnemyKind,
    var dist: Double,
    var hp: Double,
    val maxHp: Double,
    var slowLeft: Double = 0.0,
    var slowFactor: Double = 1.0,
) {
    fun copy() = Enemy(id, kind, dist, hp, maxHp, slowLeft, slowFactor)
}

class Tower(
    val id: Int,
    val cell: Cell,
    val kind: TowerKind,
    var level: Int = 1,
    var cooldown: Double = 0.0,
    var spent: Int = kind.cost,
    /** Where the barrel points (radians), for drawing. */
    var aim: Double = -Math.PI / 2,
    var kills: Int = 0,
) {
    fun copy() = Tower(id, cell, kind, level, cooldown, spent, aim, kills)
}

class Shot(
    val id: Int,
    val towerId: Int,
    val kind: TowerKind,
    var x: Double,
    var y: Double,
    val targetId: Int,
    var tx: Double,
    var ty: Double,
    val damage: Double,
) {
    fun copy() = Shot(id, towerId, kind, x, y, targetId, tx, ty, damage)
}

/** Things that happened in a tick, for drawing and sound. Not part of the saved state. */
sealed class Event {
    data class Fired(val kind: TowerKind, val from: Pt, val to: Pt) : Event()
    data class Zap(val points: List<Pt>) : Event()
    data class Boom(val at: Pt, val radius: Double, val kind: TowerKind) : Event()
    data class Killed(val at: Pt, val kind: EnemyKind, val reward: Int) : Event()
    data class Leaked(val kind: EnemyKind, val lives: Int) : Event()
    data class WaveCleared(val wave: Int, val bonus: Int) : Event()
    data object Won : Event()
    data object Lost : Event()
}

/** Everything about a game in progress. Copied every tick so time can be rewound. */
class State(
    var tick: Int = 0,
    var gold: Int = 0,
    var lives: Int = 20,
    /** Index of the current (or next) wave. */
    var wave: Int = 0,
    var waveActive: Boolean = false,
    var waveTick: Int = 0,
    var spawnIndex: Int = 0,
    val enemies: MutableList<Enemy> = mutableListOf(),
    val towers: MutableList<Tower> = mutableListOf(),
    val shots: MutableList<Shot> = mutableListOf(),
    var nextId: Int = 1,
    var rngState: Long = 1L,
    var rewindsLeft: Int = 1,
    var won: Boolean = false,
    var lost: Boolean = false,
    var livesLost: Int = 0,
    var kills: Int = 0,
    /** Research bonus: damage multiplier (1.0 = none). */
    var damageBonus: Double = 1.0,
    /** Rewinds granted at the start of each wave. */
    var rewindsPerWave: Int = 1,
) {
    val over: Boolean get() = won || lost

    fun copy() = State(
        tick, gold, lives, wave, waveActive, waveTick, spawnIndex,
        enemies.mapTo(mutableListOf()) { it.copy() },
        towers.mapTo(mutableListOf()) { it.copy() },
        shots.mapTo(mutableListOf()) { it.copy() },
        nextId, rngState, rewindsLeft, won, lost, livesLost, kills, damageBonus, rewindsPerWave,
    )

    fun towerAt(cell: Cell): Tower? = towers.firstOrNull { it.cell == cell }

    /** A compact fingerprint of the state, for checking that replays are identical. */
    fun signature(): String = buildString {
        append("$tick|$gold|$lives|$wave|$waveActive|$spawnIndex|$nextId|$rngState|")
        enemies.forEach { append("e${it.id}:${it.kind.ordinal}:${"%.4f".format(java.util.Locale.ROOT, it.dist)}:${"%.3f".format(java.util.Locale.ROOT, it.hp)};") }
        towers.forEach { append("t${it.id}:${it.level}:${"%.3f".format(java.util.Locale.ROOT, it.cooldown)};") }
        shots.forEach { append("s${it.id}:${"%.3f".format(java.util.Locale.ROOT, it.x)},${"%.3f".format(java.util.Locale.ROOT, it.y)};") }
    }
}

/** The rules: one fixed step of the simulation at [TICKS_PER_SECOND]. */
object Sim {
    const val TICKS_PER_SECOND = 30
    const val DT = 1.0 / TICKS_PER_SECOND
    const val CHAIN_RANGE = 1.7
    const val SELL_BACK = 0.7

    fun start(level: Level, startGoldBonus: Int = 0, damageBonus: Double = 1.0, rewindsPerWave: Int = 1): State =
        State(gold = level.startGold + startGoldBonus, lives = level.lives, rngState = 77L + level.index,
            damageBonus = damageBonus, rewindsPerWave = rewindsPerWave, rewindsLeft = rewindsPerWave)

    // ---- Commands ---------------------------------------------------------------

    fun canBuild(s: State, level: Level, cell: Cell, kind: TowerKind): Boolean =
        !s.over && level.buildable(cell) && s.towerAt(cell) == null && s.gold >= kind.cost

    fun build(s: State, level: Level, cell: Cell, kind: TowerKind): Tower? {
        if (!canBuild(s, level, cell, kind)) return null
        s.gold -= kind.cost
        val t = Tower(s.nextId++, cell, kind)
        s.towers += t
        return t
    }

    fun upgrade(s: State, towerId: Int): Boolean {
        val t = s.towers.firstOrNull { it.id == towerId } ?: return false
        if (s.over || t.level >= TowerKind.MAX_LEVEL) return false
        val cost = t.kind.upgradeCost(t.level)
        if (s.gold < cost) return false
        s.gold -= cost
        t.spent += cost
        t.level++
        return true
    }

    fun sellValue(t: Tower): Int = (t.spent * SELL_BACK).toInt()

    fun sell(s: State, towerId: Int): Boolean {
        val t = s.towers.firstOrNull { it.id == towerId } ?: return false
        if (s.over) return false
        s.gold += sellValue(t)
        s.towers.remove(t)
        return true
    }

    fun startWave(s: State, level: Level): Boolean {
        if (s.over || s.waveActive || s.wave >= level.waves.size) return false
        s.waveActive = true
        s.waveTick = 0
        s.spawnIndex = 0
        s.rewindsLeft = s.rewindsPerWave
        return true
    }

    // ---- The step ---------------------------------------------------------------

    fun step(s: State, level: Level, events: MutableList<Event>? = null) {
        if (s.over) return
        s.tick++
        val wave = level.waves.getOrNull(s.wave)
        if (s.waveActive && wave != null) {
            while (s.spawnIndex < wave.spawns.size && wave.spawns[s.spawnIndex].tick <= s.waveTick) {
                val k = wave.spawns[s.spawnIndex].kind
                // Bosses grow more gently than the crowd, or late ones become walls.
                val hp = k.hp * if (k == EnemyKind.BOSS) kotlin.math.sqrt(wave.hpScale) * 1.4 else wave.hpScale
                s.enemies += Enemy(s.nextId++, k, 0.0, hp, hp)
                s.spawnIndex++
            }
            s.waveTick++
        }
        moveEnemies(s, level, events)
        fireTowers(s, level, events)
        moveShots(s, level, events)
        removeDead(s, level, events)
        if (s.lives <= 0 && !s.lost) {
            s.lives = 0
            s.lost = true
            events?.add(Event.Lost)
            return
        }
        if (s.waveActive && wave != null && s.spawnIndex >= wave.spawns.size && s.enemies.isEmpty()) {
            s.waveActive = false
            s.shots.clear()
            val bonus = 20 + 4 * s.wave
            s.gold += bonus
            events?.add(Event.WaveCleared(s.wave, bonus))
            s.wave++
            if (s.wave >= level.waves.size) {
                s.won = true
                events?.add(Event.Won)
            }
        }
    }

    private fun moveEnemies(s: State, level: Level, events: MutableList<Event>?) {
        val it = s.enemies.iterator()
        while (it.hasNext()) {
            val e = it.next()
            if (e.slowLeft > 0) {
                e.slowLeft -= DT
                if (e.slowLeft <= 0) e.slowFactor = 1.0
            }
            if (e.kind.regen > 0) e.hp = minOf(e.maxHp, e.hp + e.kind.regen * DT)
            e.dist += e.kind.speed * e.slowFactor * DT
            if (e.dist >= level.length) {
                s.lives -= e.kind.livesCost
                s.livesLost += e.kind.livesCost
                events?.add(Event.Leaked(e.kind, e.kind.livesCost))
                it.remove()
            }
        }
    }

    private fun inRange(t: Tower, p: Pt): Boolean = t.cell.center.dist(p) <= t.kind.rangeAt(t.level)

    private fun target(s: State, level: Level, t: Tower): Enemy? {
        var best: Enemy? = null
        for (e in s.enemies) {
            if (e.hp <= 0) continue
            if (e.kind.flying && !t.kind.hitsFlying) continue
            if (!inRange(t, level.at(e.dist))) continue
            val b = best
            best = when {
                b == null -> e
                t.kind == TowerKind.SNIPER -> if (e.hp > b.hp) e else b
                t.kind == TowerKind.FROST -> if (e.slowLeft <= 0 && b.slowLeft > 0 || (e.slowLeft <= 0) == (b.slowLeft <= 0) && e.dist > b.dist) e else b
                else -> if (e.dist > b.dist) e else b
            }
        }
        return best
    }

    private fun hurt(s: State, e: Enemy, raw: Double) {
        e.hp -= max(1.0, raw * s.damageBonus - e.kind.armor)
    }

    private fun fireTowers(s: State, level: Level, events: MutableList<Event>?) {
        for (t in s.towers) {
            t.cooldown -= DT
            if (t.cooldown > 0) continue
            val e = target(s, level, t) ?: continue
            val from = t.cell.center
            val to = level.at(e.dist)
            t.aim = atan2(to.y - from.y, to.x - from.x)
            t.cooldown = t.kind.cooldownAt(t.level)
            val dmg = t.kind.damageAt(t.level)
            if (t.kind.shotSpeed <= 0) {
                // Lightning: instant, jumping to nearby enemies.
                val hit = mutableListOf(e)
                var last = e
                var d = dmg
                hurt(s, e, d)
                repeat(t.kind.chains + (t.level - 1)) {
                    val lp = level.at(last.dist)
                    val next = s.enemies.filter { it !in hit && it.hp > 0 && level.at(it.dist).dist(lp) <= CHAIN_RANGE }
                        .minByOrNull { level.at(it.dist).dist(lp) } ?: return@repeat
                    d *= 0.8
                    hurt(s, next, d)
                    hit += next
                    last = next
                }
                events?.add(Event.Zap(listOf(from) + hit.map { level.at(it.dist) }))
            } else {
                s.shots += Shot(s.nextId++, t.id, t.kind, from.x, from.y, e.id, to.x, to.y, dmg)
                events?.add(Event.Fired(t.kind, from, to))
            }
        }
    }

    private fun moveShots(s: State, level: Level, events: MutableList<Event>?) {
        val it = s.shots.iterator()
        while (it.hasNext()) {
            val sh = it.next()
            val target = s.enemies.firstOrNull { e -> e.id == sh.targetId && e.hp > 0 }
            if (target != null) {
                val p = level.at(target.dist)
                sh.tx = p.x
                sh.ty = p.y
            }
            val dx = sh.tx - sh.x
            val dy = sh.ty - sh.y
            val d = kotlin.math.hypot(dx, dy)
            val step = sh.kind.shotSpeed * DT
            if (d > step) {
                sh.x += dx / d * step
                sh.y += dy / d * step
                continue
            }
            it.remove()
            val at = Pt(sh.tx, sh.ty)
            if (sh.kind.splash > 0) {
                for (e in s.enemies) {
                    if (e.hp <= 0 || (e.kind.flying && !sh.kind.hitsFlying)) continue
                    if (level.at(e.dist).dist(at) <= sh.kind.splash) {
                        hurt(s, e, sh.damage)
                        slow(e, sh.kind)
                    }
                }
                events?.add(Event.Boom(at, sh.kind.splash, sh.kind))
            } else if (target != null) {
                hurt(s, target, sh.damage)
                slow(target, sh.kind)
            }
        }
    }

    private fun slow(e: Enemy, k: TowerKind) {
        if (k.slow <= 0) return
        // Bosses only slow a little.
        val f = if (e.kind == EnemyKind.BOSS) 0.8 else 1 - k.slow
        e.slowFactor = minOf(e.slowFactor, f)
        e.slowLeft = k.slowTime
    }

    private fun removeDead(s: State, level: Level, events: MutableList<Event>?) {
        val dead = s.enemies.filter { it.hp <= 0 }
        if (dead.isEmpty()) return
        s.enemies.removeAll(dead.toSet())
        val scale = level.waves.getOrNull(s.wave)?.hpScale ?: 1.0
        for (e in dead) {
            s.gold += e.kind.reward
            s.kills++
            events?.add(Event.Killed(level.at(e.dist), e.kind, e.kind.reward))
            if (e.kind == EnemyKind.SPLITTER) {
                for (k in -1..1) {
                    val hp = EnemyKind.SWARM.hp * scale
                    s.enemies += Enemy(s.nextId++, EnemyKind.SWARM, (e.dist + k * 0.25).coerceAtLeast(0.0), hp, hp)
                }
            }
        }
    }
}
