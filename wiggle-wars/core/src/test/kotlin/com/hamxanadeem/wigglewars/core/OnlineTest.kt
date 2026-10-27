package com.hamxanadeem.wigglewars.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.random.Random

class OnlineTest {

    private fun config(players: Int, seed: Long) =
        MatchConfig(List(players) { TeamSetup("P$it", false) }, wormsPerTeam = 2, seed = seed)

    @Test
    fun `commands survive the trip exactly`() {
        val commands = listOf(
            Command.Walk(-1), Command.Jump, Command.Backflip, Command.Aim(-1, -0.123456789012345),
            Command.Select(Weapon.CLUSTER), Command.Fire(0.7777777777), Command.FireAt(1234.5678, 99.000001),
            Command.Skip, Command.Heartbeat,
        )
        for (c in commands) assertEquals(c, Command.decode(c.encode()))
        val move = Move(2, 98765, Command.Aim(1, 0.5))
        assertEquals(move, Move.decode(2, move.encode()))
        assertNull(Command.decode("Z?"))
        assertNull(Move.decode(0, "nonsense"))
    }

    /**
     * Simulates a whole online match between [players] phones over a "network" that
     * delivers each player's messages in order but with random delays, and checks
     * every phone ends with exactly the same match.
     */
    private fun playOnline(players: Int, seed: Long) {
        val phones = List(players) { Lockstep(Match(config(players, seed)), it) }
        phones.forEach { it.match.drainEvents() }
        val random = Random(seed)
        // Per sender, per receiver: messages in flight with a delivery time.
        val inFlight = ArrayList<Triple<Double, Int, Move>>()
        var time = 0.0
        val planned = HashSet<Pair<Int, Int>>()
        var guard = 0
        while (phones.any { it.match.phase != Phase.GAME_OVER } && guard++ < 200_000) {
            time += 1.0 / 60
            for (phone in phones) {
                // The driver plays like a simple bot: think, aim, fire.
                if (phone.isMyTurn && phone.match.phase == Phase.AIM && planned.add(phone.me to phone.match.turnNumber)) {
                    val plan = Ai.plan(phone.match, Difficulty.NORMAL, random)
                    phone.input(Command.Select(plan.weapon))
                    phone.input(Command.Aim(plan.facing, plan.aim))
                    if (random.nextInt(4) == 0) {
                        phone.input(Command.Walk(if (random.nextBoolean()) 1 else -1))
                    }
                    if (plan.weapon.mode == FireMode.TARGET) phone.input(Command.FireAt(plan.targetX, plan.targetY))
                    else phone.input(Command.Fire(plan.power))
                    phone.input(Command.Walk(0))
                }
                phone.update(1.0 / 60)
                for (move in phone.takeOutbox()) {
                    // Same sender to same receiver keeps order: delay never decreases.
                    for (other in phones.indices) if (other != phone.me) {
                        val last = inFlight.filter { it.second == other && it.third.player == phone.me }.maxOfOrNull { it.first } ?: 0.0
                        inFlight += Triple(maxOf(last, time + 0.03 + random.nextDouble() * 0.3), other, move)
                    }
                }
            }
            val due = inFlight.filter { it.first <= time }
            inFlight.removeAll(due.toSet())
            for ((_, to, move) in due.sortedBy { it.first }) phones[to].receive(move)
        }
        assertTrue(phones.all { it.match.phase == Phase.GAME_OVER }, "match did not finish")
        val reference = phones[0]
        for (phone in phones) {
            assertFalse(phone.desynced, "phone ${phone.me} saw an input from the past")
            assertEquals(reference.match.winner, phone.match.winner)
            assertEquals(reference.match.stepCount, phone.match.stepCount)
            assertEquals(reference.checksum(), phone.checksum(), "phone ${phone.me} drifted")
            assertEquals(reference.match.terrain.solidCount(), phone.match.terrain.solidCount())
        }
    }

    @Test
    fun `two friends stay perfectly in sync`() = playOnline(2, 21)

    @Test
    fun `four friends stay perfectly in sync`() = playOnline(4, 22)

    @Test
    fun `you can only act on your own turn`() {
        val a = Lockstep(Match(config(2, 5)), 0)
        val b = Lockstep(Match(config(2, 5)), 1)
        val mine = if (a.isMyTurn) a else b
        val theirs = if (a.isMyTurn) b else a
        assertTrue(mine.input(Command.Jump))
        assertFalse(theirs.input(Command.Jump))
        // The waiting phone doesn't move until it hears from the driver.
        val before = theirs.match.stepCount
        theirs.update(1.0)
        assertEquals(before, theirs.match.stepCount)
        assertTrue(theirs.stalledFor > 0)
    }
}
