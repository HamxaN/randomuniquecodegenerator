package com.hamxanadeem.screwpuzzle.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertSame
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class PuzzleTest {

    /** Plays by always tapping a free screw whose colour has an open box; else any free screw. */
    private fun playSmart(puzzle: Puzzle): Boolean {
        var guard = 0
        while (!puzzle.isWon && !puzzle.isStuck && guard++ < 1000) {
            val free = puzzle.level.screws.filter { puzzle.isFree(it) }
            val fits = free.firstOrNull { s -> (0 until Puzzle.ACTIVE_BOXES).any { puzzle.activeBox(it)?.let { b -> b.color == s.color && b.filled < Puzzle.BOX_SIZE } == true } }
            val pick = fits ?: free.first()
            puzzle.tap(pick.id)
        }
        return puzzle.isWon
    }

    @Test
    fun `levels are the same every time`() {
        assertEquals(LevelGenerator.generate(12), LevelGenerator.generate(12))
    }

    @Test
    fun `every level has whole boxes and every plate is held`() {
        for (n in 1..120) {
            val level = LevelGenerator.generate(n)
            assertEquals(0, level.screws.size % Puzzle.BOX_SIZE, "level $n")
            assertEquals(level.screws.size / Puzzle.BOX_SIZE, level.boxes.size)
            for (color in 0 until level.colors) {
                assertEquals(level.boxes.count { it == color } * 3, level.screws.count { it.color == color })
            }
            assertTrue(level.plates.all { p -> level.screws.any { it.plateId == p.id } })
            assertTrue(level.screws.all { s -> level.plates.first { it.id == s.plateId }.shape.contains(s.x, s.y) })
        }
    }

    @Test
    fun `levels get bigger`() {
        assertTrue(LevelGenerator.generate(30).screws.size > LevelGenerator.generate(1).screws.size)
        assertTrue(LevelGenerator.generate(30).colors > LevelGenerator.generate(1).colors)
    }

    @Test
    fun `every level is solvable without touching the tray`() {
        for (n in 1..200) {
            val puzzle = Puzzle(LevelGenerator.generate(n))
            for (id in puzzle.level.solution) {
                val result = puzzle.tap(id)
                assertTrue(result is TapResult.Moved, "level $n: screw $id was $result")
                val moved = (result as TapResult.Moved).events.first() as PuzzleEvent.ScrewMoved
                assertTrue(moved.to is Spot.InBox, "level $n: screw $id went to the tray")
            }
            assertTrue(puzzle.isWon, "level $n")
        }
    }

    @Test
    fun `a sensible greedy player wins almost every level`() {
        val wins = (1..150).count { playSmart(Puzzle(LevelGenerator.generate(it))) }
        assertTrue(wins >= 140, "only $wins of 150")
    }

    @Test
    fun `covered screws cannot be taken`() {
        // Find a level with a covered screw.
        val puzzle = (1..50).map { Puzzle(LevelGenerator.generate(it)) }
            .first { p -> p.level.screws.any { p.blockers(it).isNotEmpty() } }
        val covered = puzzle.level.screws.first { puzzle.blockers(it).isNotEmpty() }
        val result = puzzle.tap(covered.id)
        assertTrue(result is TapResult.Blocked)
        assertEquals(Spot.Board, puzzle.spotOf(covered.id))
    }

    @Test
    fun `matching screws go to their box, others to the tray`() {
        val puzzle = Puzzle(LevelGenerator.generate(20))
        val colors = (0 until Puzzle.ACTIVE_BOXES).mapNotNull { puzzle.activeBox(it)?.color }.toSet()
        val matching = puzzle.level.screws.firstOrNull { puzzle.isFree(it) && it.color in colors }
        if (matching != null) {
            val result = puzzle.tap(matching.id) as TapResult.Moved
            assertTrue((result.events.first() as PuzzleEvent.ScrewMoved).to is Spot.InBox)
        }
        val other = puzzle.level.screws.firstOrNull { puzzle.isFree(it) && it.color !in colors }
        if (other != null) {
            val result = puzzle.tap(other.id) as TapResult.Moved
            assertEquals(Spot.InTray(0), (result.events.first() as PuzzleEvent.ScrewMoved).to)
        }
        assertSame(TapResult.Ignored, puzzle.tap(-1))
    }

    @Test
    fun `plates fall when their last screw is removed and boxes rotate`() {
        val puzzle = Puzzle(LevelGenerator.generate(8))
        val events = ArrayList<PuzzleEvent>()
        while (!puzzle.isWon && !puzzle.isStuck) {
            val free = puzzle.level.screws.filter { puzzle.isFree(it) }
            val pick = free.firstOrNull { s -> (0..1).any { puzzle.activeBox(it)?.let { b -> b.color == s.color && b.filled < 3 } == true } } ?: free.first()
            events += (puzzle.tap(pick.id) as TapResult.Moved).events
        }
        assertEquals(puzzle.level.plates.size, events.count { it is PuzzleEvent.PlateFreed })
        assertEquals(puzzle.level.boxes.size, events.count { it is PuzzleEvent.BoxCompleted })
        assertTrue(events.last() is PuzzleEvent.Won)
        assertEquals(0, puzzle.boxesLeft)
    }

    @Test
    fun `a full tray refuses screws until the extra slot is added`() {
        for (n in 10..120) {
            val puzzle = Puzzle(LevelGenerator.generate(n))
            val colors = (0..1).mapNotNull { puzzle.activeBox(it)?.color }
            val misfits = puzzle.level.screws.filter { puzzle.isFree(it) && it.color !in colors }
            if (misfits.size < Puzzle.TRAY_SIZE + 2) continue
            misfits.take(Puzzle.TRAY_SIZE).forEach { assertTrue(puzzle.tap(it.id) is TapResult.Moved) }
            val next = misfits[Puzzle.TRAY_SIZE]
            assertSame(TapResult.NoRoom, puzzle.tap(next.id))
            assertTrue(puzzle.addTraySlot())
            assertEquals(Puzzle.TRAY_SIZE + 1, puzzle.trayCapacity)
            assertTrue(puzzle.tap(next.id) is TapResult.Moved)
            assertFalse(puzzle.addTraySlot())
            // Now full again: stuck unless some free screw matches a box.
            val canStillMove = puzzle.level.screws.any { s -> puzzle.isFree(s) && (0..1).any { puzzle.activeBox(it)?.let { b -> b.color == s.color && b.filled < 3 } == true } }
            assertEquals(!canStillMove, puzzle.isStuck)
            return
        }
        throw AssertionError("no level had enough misfit screws")
    }

    @Test
    fun `tray screws jump into a matching new box`() {
        for (n in 5..60) {
            val puzzle = Puzzle(LevelGenerator.generate(n))
            val events = ArrayList<PuzzleEvent>()
            var guard = 0
            while (!puzzle.isWon && !puzzle.isStuck && guard++ < 500) {
                val free = puzzle.level.screws.filter { puzzle.isFree(it) }
                events += (puzzle.tap(free.first().id) as? TapResult.Moved)?.events ?: break
            }
            val fromTray = events.filterIsInstance<PuzzleEvent.ScrewMoved>().filter { it.from is Spot.InTray }
            if (fromTray.isNotEmpty()) {
                assertTrue(fromTray.all { it.to is Spot.InBox })
                return
            }
        }
        throw AssertionError("no level moved a screw from the tray")
    }

    @Test
    fun `completing a level pays coins and unlocks the next`() {
        val puzzle = Puzzle(LevelGenerator.generate(3))
        val progress = Progress(level = 3).completeLevel(puzzle)
        assertEquals(4, progress.level)
        assertEquals(Progress.reward(3), progress.coins)
        assertEquals(9, Progress(level = 9).completeLevel(puzzle).level)
    }
}
