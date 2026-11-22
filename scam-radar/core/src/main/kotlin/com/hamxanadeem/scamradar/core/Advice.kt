package com.hamxanadeem.scamradar.core

/** What to do next, by scam type. */
object Advice {
    private val GENERAL_EN = listOf(
        "Don't click links, call numbers or reply to this message.",
        "Never share a code, PIN, password or your CNIC with anyone.",
        "Check directly with the bank or company using the number on their official app or card.",
        "Warn your family: tap \"Share warning\".",
    )
    private val GENERAL_UR = listOf(
        "اس پیغام کے لنک نہ کھولیں، نمبر پر کال نہ کریں اور جواب نہ دیں۔",
        "کسی کو بھی کوڈ، پن، پاس ورڈ یا شناختی کارڈ نمبر نہ بتائیں۔",
        "بینک یا کمپنی سے ان کی سرکاری ایپ یا کارڈ پر لکھے نمبر سے خود رابطہ کریں۔",
        "اپنے گھر والوں کو خبردار کریں: \"وارننگ شیئر کریں\" دبائیں۔",
    )

    fun forResult(r: Result, urdu: Boolean): List<String> {
        if (r.verdict == Verdict.SAFE) {
            return if (urdu) listOf("کوئی واضح خطرہ نہیں ملا، مگر اگر کوئی پیسے، کوڈ یا ذاتی معلومات مانگے تو محتاط رہیں۔")
            else listOf("No clear warning signs, but stay careful if anyone asks for money, codes or personal details.")
        }
        val specific = when (r.type) {
            ScamType.WRONG_TRANSFER -> if (urdu) "رقم واپس بھیجنے سے پہلے اپنی جاز کیش / ایزی پیسہ ایپ میں اصل بیلنس دیکھیں۔ اگر واقعی رقم آئی ہے تو اپنی کمپنی کی ہیلپ لائن سے واپسی کروائیں۔"
                else "Before sending anything back, open your JazzCash / Easypaisa app and check your real balance. If money truly arrived, let the company's helpline reverse it."
            ScamType.GOVT -> if (urdu) "بی آئی ایس پی کی اصل معلومات کے لیے اپنا شناختی کارڈ نمبر صرف 8171 پر بھیجیں۔ کوئی فیس نہیں ہوتی۔"
                else "For real BISP information, send your CNIC number only to 8171. There is never a fee."
            ScamType.FAMILY -> if (urdu) "پیسے بھیجنے سے پہلے اس شخص کو ان کے پرانے نمبر پر کال کریں یا کوئی ذاتی سوال پوچھیں۔"
                else "Call the person on their old number, or ask a question only they would know, before sending anything."
            ScamType.OTP -> if (urdu) "اگر آپ پہلے ہی کوڈ بتا چکے ہیں تو فوراً اپنے بینک یا والٹ کی ہیلپ لائن پر کال کر کے اکاؤنٹ بند کروائیں۔"
                else "If you already shared a code, call your bank or wallet helpline now and ask them to block your account."
            ScamType.JOB, ScamType.INVESTMENT -> if (urdu) "جو کام یا سرمایہ کاری پہلے آپ سے پیسے مانگے وہ دھوکا ہے۔"
                else "Any job or investment that asks you to pay first is a scam."
            ScamType.DELIVERY -> if (urdu) "اپنا پارسل صرف کوریئر کی سرکاری ایپ یا ویب سائٹ پر ٹریکنگ نمبر سے چیک کریں۔"
                else "Track your parcel only in the courier's official app or website."
            else -> null
        }
        val base = if (urdu) GENERAL_UR else GENERAL_EN
        return listOfNotNull(specific) + base
    }
}
