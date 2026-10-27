package com.hamxanadeem.wigglewars.core

/**
 * A player input. Online, these are the only things sent between phones: because
 * the simulation is deterministic, replaying the same inputs at the same steps
 * gives the same match everywhere.
 */
sealed interface Command {
    data class Walk(val dir: Int) : Command
    data object Jump : Command
    data object Backflip : Command
    data class Aim(val facing: Int, val angle: Double) : Command
    data class Select(val weapon: Weapon) : Command
    data class Fire(val power: Double) : Command
    data class FireAt(val x: Double, val y: Double) : Command
    data object Skip : Command
    /** "I have simulated up to here": lets other phones keep up while nothing is pressed. */
    data object Heartbeat : Command

    fun applyTo(match: Match) {
        when (this) {
            is Walk -> match.walk(dir)
            Jump -> match.jump()
            Backflip -> match.backflip()
            is Aim -> {
                match.face(facing)
                match.setAim(angle)
            }
            is Select -> match.select(weapon)
            is Fire -> match.fire(power)
            is FireAt -> match.fireAt(x, y)
            Skip -> match.skipTurn()
            Heartbeat -> Unit
        }
    }

    /** Text form. Doubles are sent as raw bits so they arrive exactly. */
    fun encode(): String = when (this) {
        is Walk -> "W$dir"
        Jump -> "J"
        Backflip -> "B"
        is Aim -> "A$facing:${bits(angle)}"
        is Select -> "S${weapon.name}"
        is Fire -> "F${bits(power)}"
        is FireAt -> "T${bits(x)}:${bits(y)}"
        Skip -> "K"
        Heartbeat -> "H"
    }

    companion object {
        private fun bits(d: Double) = java.lang.Long.toHexString(java.lang.Double.doubleToRawLongBits(d))
        private fun unbits(s: String) = java.lang.Double.longBitsToDouble(java.lang.Long.parseUnsignedLong(s, 16))

        fun decode(text: String): Command? = runCatching {
            val body = text.substring(1)
            when (text[0]) {
                'W' -> Walk(body.toInt())
                'J' -> Jump
                'B' -> Backflip
                'A' -> body.split(':').let { Aim(it[0].toInt(), unbits(it[1])) }
                'S' -> Select(Weapon.valueOf(body))
                'F' -> Fire(unbits(body))
                'T' -> body.split(':').let { FireAt(unbits(it[0]), unbits(it[1])) }
                'K' -> Skip
                'H' -> Heartbeat
                else -> null
            }
        }.getOrNull()
    }
}

/** A command stamped with the step at which it was applied, as sent over the network. */
data class Move(val player: Int, val step: Long, val command: Command) {
    fun encode() = "$step|${command.encode()}"

    companion object {
        fun decode(player: Int, text: String): Move? {
            val bar = text.indexOf('|')
            if (bar < 1) return null
            val step = text.substring(0, bar).toLongOrNull() ?: return null
            val command = Command.decode(text.substring(bar + 1)) ?: return null
            return Move(player, step, command)
        }
    }
}

/**
 * Keeps one phone's copy of an online match in step with everyone else's.
 *
 * Exactly one player drives at a time: the owner of the team whose turn it is
 * (team i belongs to player i). The driver runs the clock and sends its inputs and
 * regular heartbeats. Everyone else only moves forward when the driver has told
 * them it got further, and applies each input at exactly the step it was made.
 * Each player's messages arrive in the order they sent them, which is all this needs.
 */
class Lockstep(val match: Match, val me: Int) {

    private val queues = HashMap<Int, ArrayDeque<Move>>()
    private val outbox = ArrayList<Move>()
    private var accumulator = 0.0
    private var sinceHeartbeat = 0.0
    var desynced = false
        private set

    /** Seconds since the driver last let us move forward, for "waiting for player" messages. */
    var stalledFor = 0.0
        private set

    val driver: Int get() = match.currentTeam
    val isMyTurn: Boolean get() = driver == me && match.phase != Phase.GAME_OVER

    /** A local input. Applied now if it's our turn, and queued to send. */
    fun input(command: Command): Boolean {
        if (!isMyTurn) return false
        command.applyTo(match)
        outbox += Move(me, match.stepCount, command)
        return true
    }

    /** A message from another player. */
    fun receive(move: Move) {
        if (move.player == me) return
        queues.getOrPut(move.player) { ArrayDeque() }.addLast(move)
    }

    /** Messages to send since the last call. */
    fun takeOutbox(): List<Move> {
        val out = ArrayList(outbox)
        outbox.clear()
        return out
    }

    fun update(dt: Double): List<GameEvent> {
        val events = ArrayList<GameEvent>()
        if (match.phase == Phase.GAME_OVER) return events
        if (isMyTurn) {
            stalledFor = 0.0
            accumulator += dt.coerceAtMost(0.25)
            sinceHeartbeat += dt
            while (accumulator >= Match.STEP) {
                accumulator -= Match.STEP
                events += match.stepOnce()
                if (!isMyTurn) {
                    // Our turn just ended: hand over exactly here.
                    accumulator = 0.0
                    break
                }
            }
            if (sinceHeartbeat >= HEARTBEAT_SECONDS || !isMyTurn) {
                sinceHeartbeat = 0.0
                outbox += Move(me, match.stepCount, Command.Heartbeat)
            }
            return events
        }
        accumulator = 0.0
        var progressed = false
        var guard = 0
        while (guard++ < MAX_CATCH_UP_STEPS && !isMyTurn && match.phase != Phase.GAME_OVER) {
            val queue = queues[driver]
            val next = queue?.firstOrNull() ?: break
            when {
                next.step < match.stepCount -> {
                    queue.removeFirst()
                    // An old heartbeat from before a hand-over is harmless; an old input is not.
                    if (next.command != Command.Heartbeat) desynced = true
                }
                next.step == match.stepCount -> {
                    queue.removeFirst()
                    next.command.applyTo(match)
                }
                else -> {
                    events += match.stepOnce()
                    progressed = true
                }
            }
        }
        stalledFor = if (progressed) 0.0 else stalledFor + dt
        return events
    }

    /** A short fingerprint of the match, to compare between phones. */
    fun checksum(): Long {
        var h = match.stepCount
        for (w in match.worms) {
            h = h * 31 + w.health
            h = h * 31 + java.lang.Double.doubleToLongBits(w.x)
            h = h * 31 + java.lang.Double.doubleToLongBits(w.y)
        }
        return h
    }

    companion object {
        const val HEARTBEAT_SECONDS = 0.1
        /** How many steps a phone may run in one frame to catch up. */
        const val MAX_CATCH_UP_STEPS = 600
    }
}
