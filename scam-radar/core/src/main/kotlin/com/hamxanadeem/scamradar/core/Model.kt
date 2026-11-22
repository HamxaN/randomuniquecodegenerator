package com.hamxanadeem.scamradar.core

enum class Verdict { SCAM, SUSPICIOUS, SAFE }

/** What kind of scam a message looks like. */
enum class ScamType(val en: String, val ur: String) {
    PRIZE("Fake prize or lottery", "جعلی انعام یا لاٹری"),
    GOVT("Fake government payment (BISP / Ehsaas)", "جعلی سرکاری رقم (بی آئی ایس پی / احساس)"),
    OTP("Code or PIN theft", "کوڈ یا پن کی چوری"),
    WRONG_TRANSFER("\"Sent by mistake\" money trick", "\"غلطی سے رقم بھیج دی\" کا دھوکا"),
    FEE("Advance fee", "پیشگی فیس کا دھوکا"),
    JOB("Fake job or easy money", "جعلی نوکری یا آسان کمائی"),
    INVESTMENT("Investment or crypto scam", "سرمایہ کاری یا کرپٹو فراڈ"),
    IMPERSONATION("Fake bank, PTA or police message", "جعلی بینک، پی ٹی اے یا پولیس پیغام"),
    FAMILY("\"New number, send money\" emergency", "\"نیا نمبر ہے، پیسے بھیجو\" کا دھوکا"),
    DELIVERY("Fake parcel delivery", "جعلی پارسل ڈیلیوری"),
    PHISHING("Dangerous link", "خطرناک لنک"),
    NONE("No warning signs", "کوئی خطرے کی علامت نہیں"),
}

/** One warning sign found in a message. */
data class Signal(val id: String, val weight: Int, val type: ScamType, val en: String, val ur: String)

/** A link found in a message and what is wrong with it. */
data class LinkCheck(val url: String, val host: String, val problems: List<String>) {
    val risky: Boolean get() = problems.isNotEmpty()
}

data class Result(
    val text: String,
    val verdict: Verdict,
    val score: Int,
    val type: ScamType,
    val signals: List<Signal>,
    val links: List<LinkCheck>,
) {
    fun advice(urdu: Boolean): List<String> = Advice.forResult(this, urdu)
}
