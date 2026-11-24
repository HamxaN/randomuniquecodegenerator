package com.hamxanadeem.clipcraft.core

import java.time.Instant
import java.time.temporal.ChronoUnit

/** Spacing out scheduled posts. YouTube wants RFC 3339 times in UTC. */
object Schedule {
    fun times(firstEpochMs: Long, everyHours: Int, count: Int): List<String> =
        (0 until count).map { i ->
            Instant.ofEpochMilli(firstEpochMs).plus(i.toLong() * everyHours, ChronoUnit.HOURS)
                .truncatedTo(ChronoUnit.SECONDS).toString()
        }
}
