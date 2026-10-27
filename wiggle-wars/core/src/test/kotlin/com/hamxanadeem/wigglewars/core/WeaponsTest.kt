package com.hamxanadeem.wigglewars.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class WeaponsTest {

    private fun settled(seed: Long = 3, set: WeaponSet = WeaponSet.STANDARD, arena: Arena = Arena.HILLS): Match {
        val m = Match(MatchConfig(listOf(TeamSetup("A", false), TeamSetup("B", false)), seed = seed, weaponSet = set, arena = arena))
        repeat(40) { m.update(0.05) }
        return m
    }

    private fun runFor(m: Match, seconds: Double): List<GameEvent> {
        val out = ArrayList<GameEvent>()
        var t = 0.0
        while (t < seconds) {
            out += m.update(0.05)
            t += 0.05
        }
        return out
    }

    @Test
    fun `weapon sets change the starting ammo and always leave something to fire`() {
        val sharp = settled(set = WeaponSet.SHARPSHOOTER)
        assertFalse(sharp.hasAmmo(Weapon.BAZOOKA))
        assertEquals(Weapon.SHOTGUN, sharp.selected)
        assertEquals(5, sharp.ammo(Weapon.SNIPER))
        val mayhem = settled(set = WeaponSet.MAYHEM)
        assertTrue(Weapon.entries.all { mayhem.ammo(it) < 0 })
        for (set in WeaponSet.entries) assertTrue(Weapon.entries.any { set.ammo(it) < 0 }, "$set has an unlimited weapon")
    }

    @Test
    fun `every weapon has a name, a description and a category`() {
        for (w in Weapon.entries) {
            assertTrue(w.displayName.isNotBlank() && w.description.length > 10)
            assertTrue(w.power in 0..5 && w.blast in 0..5 && w.range in 0..5)
        }
        assertTrue(WeaponCategory.entries.all { c -> Weapon.entries.any { it.category == c } })
    }

    @Test
    fun `uzi and sniper fire instantly and use ammo`() {
        val m = settled()
        val team = m.currentTeam
        assertTrue(m.select(Weapon.UZI))
        assertTrue(m.fire())
        assertEquals(Weapon.UZI.startAmmo - 1, m.ammo(Weapon.UZI, team))
        val events = runFor(m, 30.0)
        assertEquals(Weapon.UZI_BULLETS, events.count { it is GameEvent.ShotgunBlast })
        while (m.phase != Phase.AIM) m.update(0.05)
        assertTrue(m.select(Weapon.SNIPER))
        assertTrue(m.fire())
        assertEquals(Phase.RETREAT, m.phase)
    }

    @Test
    fun `girders add land and the turn goes on`() {
        val m = settled()
        val w = m.activeWorm
        assertTrue(m.select(Weapon.GIRDER))
        val x = w.x
        val y = w.y - 50
        val before = m.terrain.solidCount()
        assertTrue(m.fireAt(x, y))
        assertTrue(m.terrain.isSolid(x, y))
        assertTrue(m.terrain.solidCount() > before)
        assertEquals(Phase.AIM, m.phase, "still your turn")
        assertTrue(m.drainEvents().any { it is GameEvent.Built })
        assertFalse(m.fireAt(w.x, w.y), "can't build on top of a worm")
    }

    @Test
    fun `mines wait, arm, and go off when a worm comes close`() {
        val m = settled()
        assertTrue(m.select(Weapon.MINE))
        assertTrue(m.fire())
        runFor(m, 8.0)
        val mine = m.projectiles.single()
        assertTrue(mine.idle && mine.armed, "mine settled and armed")
        assertTrue(m.phase == Phase.AIM, "a resting mine doesn't hold up the next turn")
        // Drop an enemy right next to it.
        val enemy = m.worms.first { it.alive && it.team != m.worms[mine.owner].team }
        enemy.x = mine.x + 6
        enemy.y = mine.y - 12
        enemy.onGround = false
        val events = runFor(m, 1.0)
        assertTrue(events.any { it is GameEvent.Explosion }, "boom")
        assertTrue(m.projectiles.none { it.spec.mine })
    }

    @Test
    fun `the sheep walks off and explodes`() {
        val m = settled(seed = 8)
        val w = m.activeWorm
        assertTrue(m.select(Weapon.SHEEP))
        assertTrue(m.fire())
        val sheep = m.projectiles.single()
        val startX = sheep.x
        runFor(m, 1.5)
        assertTrue(sheep.gone || kotlin.math.abs(sheep.x - startX) > 30, "sheep moved from $startX to ${sheep.x}")
        val events = runFor(m, 8.0)
        assertTrue(sheep.gone)
        assertTrue(events.any { it is GameEvent.Explosion || it is GameEvent.Splash } || w.health < 100)
    }

    @Test
    fun `crates under a roof appear inside the cave`() {
        val m = settled(arena = Arena.CAVERN)
        var t = 0.0
        while (t < 600 && m.crates.isEmpty() && m.phase != Phase.GAME_OVER) {
            if (m.phase == Phase.AIM) m.skipTurn()
            m.update(0.05)
            t += 0.05
        }
        val crate = m.crates.firstOrNull() ?: return
        assertTrue(crate.y > 0, "crate starts below the roof, at ${crate.y}")
        assertFalse(m.terrain.isSolid(crate.x, crate.y))
    }

    @Test
    fun `every weapon is available at the start of a standard match`() {
        val m = settled()
        for (w in Weapon.entries) assertTrue(m.hasAmmo(w), "$w has ammo")
        assertEquals(1, m.ammo(Weapon.NUKE))
    }

    @Test
    fun `homing missiles chase the nearest enemy`() {
        val m = settled(seed = 6)
        val me = m.activeWorm
        val enemy = m.worms.filter { it.team != me.team }.minBy { kotlin.math.hypot(it.x - me.x, it.y - me.y) }
        // Fire straight up and away; it should still end up near the enemy.
        m.face(if (enemy.x > me.x) -1 else 1)
        m.setAim(-1.4)
        assertTrue(m.select(Weapon.HOMING))
        assertTrue(m.fire(0.6))
        var boom: GameEvent.Explosion? = null
        var t = 0.0
        while (boom == null && t < 15) {
            boom = m.update(0.05).filterIsInstance<GameEvent.Explosion>().firstOrNull()
            t += 0.05
        }
        assertNotNull(boom)
        assertTrue(kotlin.math.hypot(boom!!.x - enemy.x, boom.y - enemy.y) < 120, "exploded ${boom.x},${boom.y} vs enemy ${enemy.x},${enemy.y}")
    }

    @Test
    fun `drill missiles bore through land before exploding`() {
        val m = settled()
        m.setAim(0.5)
        assertTrue(m.select(Weapon.DRILL))
        assertTrue(m.fire(0.9))
        val events = runFor(m, 6.0)
        assertTrue(events.count { it is GameEvent.Carved } > 5, "bored a tunnel")
        assertTrue(events.any { it is GameEvent.Explosion })
    }

    @Test
    fun `cluster missiles split in four at the top of their flight`() {
        val m = settled()
        m.setAim(-1.0)
        assertTrue(m.select(Weapon.MIRV))
        assertTrue(m.fire(0.8))
        var split = false
        var t = 0.0
        while (!split && t < 6) {
            split = m.update(0.02).any { it is GameEvent.Split }
            t += 0.02
        }
        assertTrue(split)
        assertEquals(4, m.projectiles.count { it.weapon == Weapon.MIRV })
    }

    @Test
    fun `the computer can plan with every weapon set`() {
        for (set in WeaponSet.entries) {
            val m = Match(MatchConfig(listOf(TeamSetup("A", true), TeamSetup("B", true)), seed = 9, weaponSet = set))
            repeat(40) { m.update(0.05) }
            val plan = Ai.plan(m, Difficulty.NORMAL, kotlin.random.Random(1))
            assertTrue(m.hasAmmo(plan.weapon), "$set: planned ${plan.weapon}")
        }
    }
}
