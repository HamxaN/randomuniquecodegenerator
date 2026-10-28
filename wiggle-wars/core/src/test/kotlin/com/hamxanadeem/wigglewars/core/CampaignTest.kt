package com.hamxanadeem.wigglewars.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class CampaignTest {

    @Test
    fun `missions are numbered in order and every one builds a valid match`() {
        for ((i, m) in Campaign.missions.withIndex()) {
            assertEquals(i + 1, m.number)
            val match = Match(m.config(seed = 3))
            assertEquals(m.enemyWorms.size + 1, match.teams.size)
            assertEquals(m.myWorms, match.teams[0].worms.size)
            assertTrue(match.teams.drop(1).all { it.cpu })
            assertTrue(match.teams.drop(1).flatMap { it.worms }.all { it.health == m.enemyHealth })
        }
        assertTrue(Campaign.missions.map { it.arena }.toSet().size == Arena.entries.size, "every arena appears")
    }

    @Test
    fun `stars and coins`() {
        val m = Campaign.mission(1)
        assertEquals(0, Campaign.stars(m, won = false, wormsLost = 0, turns = 1))
        assertEquals(1, Campaign.stars(m, won = true, wormsLost = 2, turns = 99))
        assertEquals(3, Campaign.stars(m, won = true, wormsLost = 0, turns = m.parTurns))
        assertTrue(Campaign.coins(3, previousBest = 0) > Campaign.coins(3, previousBest = 3))
        assertTrue(Campaign.coins(0, 0) > 0, "something for trying")
    }

    @Test
    fun `upgrades add starting ammo for the player only`() {
        val config = Campaign.mission(5).config(seed = 1, bonusAmmo = mapOf(Weapon.NUKE to 2, Weapon.HOMING to 1))
        val match = Match(config)
        assertEquals(Weapon.NUKE.startAmmo + 2, match.ammo(Weapon.NUKE, 0))
        assertEquals(Weapon.HOMING.startAmmo + 1, match.ammo(Weapon.HOMING, 0))
        assertEquals(Weapon.NUKE.startAmmo, match.ammo(Weapon.NUKE, 1))
    }

    @Test
    fun `the aiming preview ends where the shot explodes`() {
        val m = Match(MatchConfig(listOf(TeamSetup("A", false), TeamSetup("B", false)), seed = 5))
        repeat(40) { m.update(0.05) }
        val w = m.activeWorm
        val path = m.trajectory(Weapon.BAZOOKA, w.facing, -0.6, 0.7)
        val hit = m.predict(Weapon.BAZOOKA, w.facing, -0.6, 0.7)
        assertTrue(path.size >= 4)
        if (hit != null) {
            assertEquals(hit.first, path[path.size - 2].toDouble(), 0.01)
            assertEquals(hit.second, path[path.size - 1].toDouble(), 0.01)
        }
    }
}
