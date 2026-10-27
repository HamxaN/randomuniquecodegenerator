package com.hamxanadeem.wigglewars.ui

import android.os.Handler
import android.os.Looper
import com.hamxanadeem.wigglewars.core.Ai
import com.hamxanadeem.wigglewars.core.AiPlan
import com.hamxanadeem.wigglewars.core.Difficulty
import com.hamxanadeem.wigglewars.core.FireMode
import com.hamxanadeem.wigglewars.core.Match
import com.hamxanadeem.wigglewars.core.Phase
import com.hamxanadeem.wigglewars.core.Weapon
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.random.Random

/**
 * Plays the computer's turns like a person would: thinks (on a background thread),
 * turns, sweeps the aim, charges the power bar and fires.
 */
class AiDriver(private val difficulty: Difficulty) {

    private enum class Stage { IDLE, THINKING, AIMING, CHARGING, DONE }

    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val random = Random(System.nanoTime())
    private var stage = Stage.IDLE
    private var plan: AiPlan? = null
    private var timer = 0.0
    private var startAim = 0.0
    private var turn = -1

    /** While true the match must not be stepped: the planner is reading it. */
    val isThinking: Boolean get() = stage == Stage.THINKING

    /** Power bar value to show, or -1. */
    var charge = -1f
        private set

    fun update(match: Match, dt: Double) {
        if (!match.isCpuTurn || match.phase != Phase.AIM) {
            if (stage != Stage.THINKING) stage = Stage.IDLE
            charge = -1f
            return
        }
        if (turn != match.turnNumber && stage != Stage.THINKING) {
            turn = match.turnNumber
            stage = Stage.THINKING
            timer = 0.0
            val started = System.currentTimeMillis()
            executor.execute {
                val result = runCatching { Ai.plan(match, difficulty, random) }.getOrNull()
                // Think for at least a moment so the turn is readable.
                val wait = (900 - (System.currentTimeMillis() - started)).coerceAtLeast(0)
                main.postDelayed({
                    plan = result
                    stage = Stage.AIMING
                    timer = 0.0
                    startAim = match.activeWorm.aim
                    result?.let {
                        match.face(it.facing)
                        if (!match.select(it.weapon)) match.select(Weapon.BAZOOKA)
                    }
                }, wait)
            }
            return
        }
        val p = plan
        if (p == null) {
            if (stage == Stage.AIMING) {
                match.skipTurn()
                stage = Stage.DONE
            }
            return
        }
        timer += dt
        when (stage) {
            Stage.AIMING -> {
                val k = (timer / AIM_SECONDS).coerceAtMost(1.0)
                val eased = k * k * (3 - 2 * k)
                match.setAim(startAim + (p.aim - startAim) * eased)
                if (k >= 1.0) {
                    timer = 0.0
                    stage = when (p.weapon.mode) {
                        FireMode.POWER -> Stage.CHARGING
                        FireMode.TARGET -> {
                            match.fireAt(p.targetX, p.targetY)
                            Stage.DONE
                        }
                        else -> {
                            match.fire()
                            Stage.DONE
                        }
                    }
                }
            }
            Stage.CHARGING -> {
                charge = (timer / CHARGE_SECONDS).toFloat().coerceAtMost(1f)
                if (charge >= p.power || abs(charge - 1f) < 1e-3) {
                    match.fire(p.power)
                    charge = -1f
                    stage = Stage.DONE
                }
            }
            else -> Unit
        }
    }

    fun shutdown() = executor.shutdownNow()

    companion object {
        const val AIM_SECONDS = 0.9
        const val CHARGE_SECONDS = 1.4
    }
}
