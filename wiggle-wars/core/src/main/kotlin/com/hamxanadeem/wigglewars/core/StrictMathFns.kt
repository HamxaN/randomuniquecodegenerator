package com.hamxanadeem.wigglewars.core

// The simulation uses StrictMath so every phone computes exactly the same numbers.
// That is what lets online matches stay in sync by sharing only button presses.

internal fun sin(x: Double): Double = StrictMath.sin(x)
internal fun cos(x: Double): Double = StrictMath.cos(x)
internal fun atan2(y: Double, x: Double): Double = StrictMath.atan2(y, x)
internal fun hypot(x: Double, y: Double): Double = StrictMath.sqrt(x * x + y * y)
