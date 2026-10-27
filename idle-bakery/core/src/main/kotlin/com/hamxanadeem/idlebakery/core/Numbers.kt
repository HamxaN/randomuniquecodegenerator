package com.hamxanadeem.idlebakery.core

import java.util.Locale
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.pow

/** Short money labels: 999, 1.23K, 45.6M, 7.89B, ... then aa, ab, ... */
object Numbers {

    private val names = listOf("", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc")

    fun format(value: Double): String {
        if (!value.isFinite()) return "∞"
        if (value < 0) return "-" + format(-value)
        if (value < 1000) return if (value < 10 && value % 1.0 != 0.0) String.format(Locale.US, "%.1f", floor(value * 10) / 10) else floor(value).toLong().toString()
        val group = floor(log10(value) / 3).toInt()
        val scaled = value / 10.0.pow(group * 3)
        val suffix = if (group < names.size) names[group] else letters(group - names.size)
        val text = when {
            scaled >= 100 -> floor(scaled).toLong().toString()
            scaled >= 10 -> String.format(Locale.US, "%.1f", floor(scaled * 10) / 10)
            else -> String.format(Locale.US, "%.2f", floor(scaled * 100) / 100)
        }
        return text + suffix
    }

    private fun letters(index: Int): String {
        val first = 'a' + (index / 26) % 26
        val second = 'a' + index % 26
        return "$first$second"
    }

    fun duration(seconds: Double): String {
        val s = seconds.toLong().coerceAtLeast(0)
        return when {
            seconds < 1 -> String.format(Locale.US, "%.1fs", seconds.coerceAtLeast(0.0))
            s < 60 -> "${s}s"
            s < 3600 -> "%d:%02d".format(s / 60, s % 60)
            else -> "%d:%02d:%02d".format(s / 3600, s / 60 % 60, s % 60)
        }
    }
}
