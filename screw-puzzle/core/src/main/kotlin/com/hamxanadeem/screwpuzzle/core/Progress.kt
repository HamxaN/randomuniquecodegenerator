package com.hamxanadeem.screwpuzzle.core

/** Saved progress: the next level and coins. */
data class Progress(val level: Int = 1, val coins: Int = 0) {

    fun completeLevel(puzzle: Puzzle): Progress = copy(
        level = maxOf(level, puzzle.level.number + 1),
        coins = coins + reward(puzzle.level.number),
    )

    fun addCoins(amount: Int): Progress {
        require(amount >= 0) { "Amount must not be negative" }
        return copy(coins = coins + amount)
    }

    companion object {
        fun reward(level: Int) = 10 + level * 2
    }
}
