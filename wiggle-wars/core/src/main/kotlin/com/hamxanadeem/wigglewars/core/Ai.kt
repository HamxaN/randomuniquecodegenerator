package com.hamxanadeem.wigglewars.core

import kotlin.math.PI
import kotlin.math.abs
import kotlin.random.Random

/** What the computer has decided to do this turn. */
data class AiPlan(
    val weapon: Weapon,
    val facing: Int,
    val aim: Double,
    val power: Double,
    /** For target weapons. */
    val targetX: Double = 0.0,
    val targetY: Double = 0.0,
    /** How far from the enemy the shot is expected to land (lower is better). */
    val expectedMiss: Double,
)

/**
 * Picks a shot by trying many angles and powers with the real physics and keeping
 * the one that lands closest to an enemy without hurting its own team. Difficulty
 * adds aiming error afterwards.
 */
object Ai {

    /** Nothing lands well: lob something towards the nearest enemy, or shoot a path through the ground. */
    private fun fallback(match: Match, me: Worm, enemy: Worm?): AiPlan {
        val weapon = match.fallbackWeapon()
        val facing = if (enemy == null) me.facing else if (enemy.x >= me.x) 1 else -1
        val aim = if (weapon.mode == FireMode.POWER || enemy == null) -PI / 4 else atan2(enemy.y - me.y, abs(enemy.x - me.x))
        return AiPlan(weapon, facing, aim.coerceIn(-PI / 2, PI / 2), 0.6, expectedMiss = 999.0)
    }

    fun plan(match: Match, difficulty: Difficulty, random: Random = Random.Default): AiPlan {
        val me = match.activeWorm
        val enemies = match.worms.filter { it.alive && it.team != me.team }.sortedBy { hypot(it.x - me.x, it.y - me.y) }.take(3)
        val friends = match.worms.filter { it.alive && it.team == me.team }
        var best: AiPlan? = null

        fun score(x: Double, y: Double, spec: ProjectileSpec, target: Worm): Double {
            val reach = spec.explosionRadius + Worm.RADIUS
            // Never hurt our own team (including ourselves).
            if (friends.any { hypot(it.x - x, it.y - y) < reach + 6 }) return Double.MAX_VALUE
            return hypot(target.x - x, target.y - y)
        }

        fun consider(plan: AiPlan) {
            if (best == null || plan.expectedMiss < best!!.expectedMiss) best = plan
        }

        // Each trajectory is simulated once and scored against every enemy.
        for (weapon in listOf(Weapon.BAZOOKA, Weapon.GRENADE, Weapon.HOMING, Weapon.DRILL, Weapon.CLUSTER, Weapon.BANANA, Weapon.MEGA_GRENADE, Weapon.NUKE)) {
            if (!match.hasAmmo(weapon) || enemies.isEmpty()) continue
            val spec = weapon.spec!!
            fun evaluate(facing: Int, aim: Double, power: Double): AiPlan? {
                val hit = match.predict(weapon, facing, aim, power, me) ?: return null
                val s = enemies.minOf { score(hit.first, hit.second, spec, it) }
                return AiPlan(weapon, facing, aim, power, expectedMiss = s)
            }
            var coarse: AiPlan? = null
            for (facing in intArrayOf(-1, 1)) {
                var a = -85.0
                while (a <= 60.0) {
                    var power = 0.3
                    while (power <= 1.0001) {
                        val plan = evaluate(facing, Math.toRadians(a), power)
                        if (plan != null && (coarse == null || plan.expectedMiss < coarse.expectedMiss)) coarse = plan
                        power += 0.1
                    }
                    a += 5.0
                }
            }
            val start = coarse ?: continue
            var refined: AiPlan = start
            var da = -5.0
            while (da <= 5.0) {
                var dp = -0.08
                while (dp <= 0.0801) {
                    val plan = evaluate(start.facing, start.aim + Math.toRadians(da), (start.power + dp).coerceIn(Match.MIN_POWER, 1.0))
                    if (plan != null && plan.expectedMiss < refined.expectedMiss) refined = plan
                    dp += 0.02
                }
                da += 1.0
            }
            // Special weapons only when they clearly beat the free ones.
            val penalty = if (match.ammo(weapon) >= 0) 6.0 else 0.0
            consider(refined.copy(expectedMiss = refined.expectedMiss + penalty))
        }

        for (target in enemies) {
            // Guns when there's a clear line: shotgun close up, uzi for a push, sniper from afar.
            val facingTo = if (target.x >= me.x) 1 else -1
            val aimTo = atan2(target.y - me.y, abs(target.x - me.x))
            fun gun(weapon: Weapon, range: Double, miss: Double) {
                if (!match.hasAmmo(weapon) || !match.lineOfSight(me, target, range)) return
                val penalty = if (match.ammo(weapon) >= 0) 6.0 else 0.0
                consider(AiPlan(weapon, facingTo, aimTo, 1.0, expectedMiss = miss + penalty))
            }
            gun(Weapon.SHOTGUN, Weapon.SHOTGUN_RANGE, 14.0)
            gun(Weapon.UZI, Weapon.UZI_RANGE, 13.0)
            gun(Weapon.SNIPER, Weapon.SNIPER_RANGE, 12.0)
            // Bat when right next to the enemy and they're near the edge or water.
            if (match.hasAmmo(Weapon.BAT) && hypot(target.x - me.x, target.y - me.y) < Weapon.BAT_RANGE + 8) {
                val facing = if (target.x >= me.x) 1 else -1
                consider(AiPlan(Weapon.BAT, facing, -PI / 4, 1.0, expectedMiss = 10.0))
            }
            // Air strike on an exposed enemy when nothing else lands close.
            if (match.hasAmmo(Weapon.AIRSTRIKE) && match.openSky(target) && (best?.expectedMiss ?: 999.0) > 40 &&
                friends.none { abs(it.x - target.x) < 90 }
            ) {
                consider(AiPlan(Weapon.AIRSTRIKE, me.facing, me.aim, 1.0, target.x, target.y, expectedMiss = 20.0))
            }
        }

        val chosen = best ?: fallback(match, me, enemies.firstOrNull())
        // Human-like error.
        val (angleError, powerError) = when (difficulty) {
            Difficulty.EASY -> 0.14 to 0.14
            Difficulty.NORMAL -> 0.05 to 0.05
            Difficulty.HARD -> 0.012 to 0.015
        }
        if (chosen.weapon.mode != FireMode.POWER) {
            if (chosen.weapon.mode != FireMode.INSTANT || difficulty == Difficulty.HARD) return chosen
            return chosen.copy(aim = (chosen.aim + (random.nextDouble() * 2 - 1) * angleError * 0.5).coerceIn(-PI / 2, PI / 2))
        }
        return chosen.copy(
            aim = (chosen.aim + (random.nextDouble() * 2 - 1) * angleError).coerceIn(-PI / 2, PI / 2),
            power = (chosen.power + (random.nextDouble() * 2 - 1) * powerError).coerceIn(Match.MIN_POWER, 1.0),
        )
    }
}
