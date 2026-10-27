package com.hamxanadeem.neonrunner.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class AdPolicyAndSynthTest {

    private val policy = AdPolicy(gamesBetweenInterstitials = 2, minMillisBetweenInterstitials = 60_000, graceGames = 2)

    @Test
    fun `interstitials wait for the grace period, the round gap and the time gap`() {
        assertFalse(policy.shouldShowInterstitial(1, 5, 1_000_000, null))
        assertFalse(policy.shouldShowInterstitial(5, 1, 1_000_000, null))
        assertTrue(policy.shouldShowInterstitial(5, 2, 1_000_000, null))
        assertFalse(policy.shouldShowInterstitial(5, 2, 100_000, 50_000))
        assertTrue(policy.shouldShowInterstitial(5, 2, 120_000, 50_000))
    }

    @Test
    fun `synthesised sounds are valid wav files`() {
        val wav = ToneSynth.wav(listOf(ToneSynth.Note(440.0, 100), ToneSynth.Note(660.0, 100)))
        assertEquals("RIFF", String(wav, 0, 4))
        assertEquals("WAVE", String(wav, 8, 4))
        assertEquals("data", String(wav, 36, 4))
        val dataSize = (wav[40].toInt() and 0xFF) or ((wav[41].toInt() and 0xFF) shl 8) or
            ((wav[42].toInt() and 0xFF) shl 16) or ((wav[43].toInt() and 0xFF) shl 24)
        assertEquals(wav.size - 44, dataSize)
        assertEquals(ToneSynth.SAMPLE_RATE * 2 / 5, dataSize) // 200 ms of 16-bit mono
    }
}
