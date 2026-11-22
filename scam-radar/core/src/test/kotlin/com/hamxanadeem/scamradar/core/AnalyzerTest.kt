package com.hamxanadeem.scamradar.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class AnalyzerTest {

    private fun verdict(text: String, sender: String = "") = Analyzer.analyze(text, sender)

    // --- Scams that must be caught ------------------------------------------------

    private val scams = listOf(
        "Congratulations! You have won Rs 50,000 in the Jazz lucky draw. Claim now at http://jazz-prize.xyz/claim",
        "BISP: Aap ki 25000 raqam jari ho chuki hai. Wusool ke liye is link par click karein bit.ly/bisp25k",
        "مبارک ہو! بینظیر انکم سپورٹ پروگرام کی رقم 25000 روپے آپ کے نام جاری۔ رابطہ کریں 03001234567",
        "Assalam o alaikum, maine galti se aap ke JazzCash account mein 5000 bhej diye hain, please wapas kar dein 03211234567",
        "Dear customer your HBL account will be blocked today. Verify your account at hbl-secure-login.com",
        "Your 6 digit code has been sent. Please share the code with our agent to complete verification",
        "PTA: Aap ki SIM 24 ghante mein band ho jayegi. Biometric verification ke liye abhi call karein 03451234567",
        "Work from home job! Earn Rs 5000 daily by liking videos. Contact on WhatsApp 03121234567",
        "Invest 10,000 and get guaranteed profit of 100% in 7 days. USDT trading. Join now t.me/profitclub",
        "Ammi mera phone kho gaya hai, ye naya number hai. Urgent 10000 paise bhej do easypaisa par",
        "Your parcel could not be delivered due to incomplete address. Pay delivery charges Rs 150 at tcs-redeliver.top",
        "You are selected for Ehsaas program. Registration fee Rs 500 jama karwayen aur 12000 hasil karein",
        "Free iPhone 15 winner!!!! CLAIM YOUR PRIZE NOW!!! http://192.168.4.20/win",
        "Daraz mega sale gift card for you https://daraz-gift-card.online/free",
    )

    @Test
    fun `known scams are flagged`() {
        for (s in scams) {
            val r = verdict(s)
            assertTrue(r.verdict == Verdict.SCAM, "should be SCAM (${r.score}): $s\n${r.signals.map { it.id }}")
        }
    }

    @Test
    fun `each scam gets the right type`() {
        assertEquals(ScamType.WRONG_TRANSFER, verdict(scams[3]).type)
        assertEquals(ScamType.OTP, verdict(scams[5]).type)
        assertEquals(ScamType.FAMILY, verdict(scams[9]).type)
        assertEquals(ScamType.GOVT, verdict(scams[1]).type)
        assertEquals(ScamType.INVESTMENT, verdict(scams[8]).type)
    }

    // --- Normal messages that must not be ---------------------------------------

    private val safe = listOf(
        "Your OTP for login is 482913. Do not share it with anyone, including bank staff.",
        "HBL: Rs 5,000 has been debited from your account ending 1234 on 12-Nov.",
        "Meeting at 5pm tomorrow at the office, bring the files please",
        "Your Daraz order #12345 has been shipped. Track it at https://www.daraz.pk/orders",
        "Bhai kal cricket khelne chalein? Shaam 4 baje ground par milte hain",
        "Eid Mubarak to you and your family!",
        "Apna CNIC number 8171 par bhejein aur BISP ki ehliyat maloom karein.",
        "Happy birthday beta, ammi abbu ki taraf se dher saari duaen",
        "The quarterly report is attached. Let me know your thoughts.",
    )

    @Test
    fun `normal messages are not scams`() {
        for (s in safe) {
            val r = verdict(s)
            assertTrue(r.verdict == Verdict.SAFE, "should be SAFE (${r.score}): $s\n${r.signals.map { it.id }}")
        }
    }

    @Test
    fun `a bank message from a personal mobile number is suspicious`() {
        val r = verdict("Dear customer your bank account is suspended, call us now", "+923001234567")
        assertTrue(r.verdict != Verdict.SAFE)
        assertTrue(r.signals.any { it.id == "sender" })
    }

    @Test
    fun `urdu digits and hidden characters do not hide a scam`() {
        val r = verdict("آپ کا او ٹی پی کوڈ ہمیں بتائیں ورنہ اکاؤنٹ بند ہو جائے گا۔ OT​P share karein")
        assertTrue(r.signals.any { it.id == "otp" })
        assertEquals("0123456789", Normalize.text("۰۱۲۳۴۵۶۷۸۹"))
    }

    @Test
    fun `every signal is explained in both languages`() {
        for (s in scams) {
            for (sig in verdict(s).signals) {
                assertTrue(sig.en.isNotBlank() && sig.ur.isNotBlank(), sig.id)
            }
        }
    }

    @Test
    fun `scores stay in range`() {
        for (s in scams + safe) {
            val r = verdict(s)
            assertTrue(r.score in 0..100)
        }
    }
}

class LinksTest {
    @Test
    fun `finds links with and without a scheme`() {
        val found = Links.extract("Go to bit.ly/abc or https://example.com/x, also www.test.pk.")
        assertEquals(listOf("bit.ly/abc", "https://example.com/x", "www.test.pk"), found)
    }

    @Test
    fun `real brand sites are fine and copies are not`() {
        assertFalse(Links.check("https://www.jazzcash.com.pk/promo").risky)
        assertFalse(Links.check("https://secure.hbl.com/login").risky)
        assertTrue(Links.check("https://jazzcash-reward.com/claim").problems.any { it.startsWith("lookalike") })
        assertTrue(Links.check("http://easypaisa.com.pk.verify-user.info").risky)
        assertTrue(Links.check("https://xn--paypl-7ve.com").problems.contains("punycode"))
        assertTrue(Links.check("http://10.0.0.5/login").problems.contains("ip"))
        assertTrue(Links.check("https://tinyurl.com/abc").problems.contains("shortener"))
        assertTrue(Links.check("https://google.com@evil.example/x").problems.contains("at"))
    }

    @Test
    fun `host parsing`() {
        assertEquals("example.com", Links.host("https://www.example.com:443/path?q=1"))
        assertEquals("evil.example", Links.host("https://google.com@evil.example/x"))
    }
}

class AdviceShareHistoryTest {
    @Test
    fun `advice and share text in both languages`() {
        val r = Analyzer.analyze("Maine galti se aap ko 5000 bhej diye, wapas kar dein 03001234567")
        assertTrue(r.advice(false).first().contains("balance"))
        assertTrue(r.advice(true).isNotEmpty())
        val en = ShareText.warning(r, false)
        assertTrue(en.startsWith("⚠️ SCAM ALERT"))
        assertTrue(ShareText.warning(r, true).contains("دھوکے"))
        assertTrue(ShareText.warning(Analyzer.analyze("Click bit.ly/x to win a prize now"), false).contains("[link]"))
    }

    @Test
    fun `history round trip`() {
        val list = listOf(Check(1L, Verdict.SCAM, 88, ScamType.PRIZE, "line one\nline\ttwo \\ back"), Check(2L, Verdict.SAFE, 0, ScamType.NONE, "hi"))
        assertEquals(list, History.decode(History.encode(list)))
        assertEquals(emptyList<Check>(), History.decode("garbage"))
        val added = History.add(list, Check(3L, Verdict.SAFE, 0, ScamType.NONE, "hi"))
        assertEquals(2, added.size)
        assertEquals(3L, added.first().time)
    }
}
