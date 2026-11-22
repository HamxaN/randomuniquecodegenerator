package com.hamxanadeem.scamradar.core

/** Short lessons about common scams, shown in the app's Learn section. */
data class Lesson(val type: ScamType, val exampleEn: String, val signEn: String, val signUr: String)

object Guide {
    val LESSONS = listOf(
        Lesson(ScamType.WRONG_TRANSFER, "\"I sent Rs 5,000 to you by mistake, please send it back\" + a fake \"received\" SMS.",
            "Check your real balance in the app. The money usually never arrived.",
            "ایپ میں اصل بیلنس دیکھیں۔ عام طور پر رقم کبھی آئی ہی نہیں ہوتی۔"),
        Lesson(ScamType.GOVT, "\"Your BISP Rs 25,000 is released, click the link / call this number / pay a fee.\"",
            "BISP only uses 8171 and never charges a fee or sends links.",
            "بی آئی ایس پی صرف 8171 استعمال کرتا ہے، کبھی فیس یا لنک نہیں بھیجتا۔"),
        Lesson(ScamType.OTP, "\"Our agent is verifying your account, tell us the code we just sent.\"",
            "A code is a key to your account. Nobody genuine ever asks for it.",
            "کوڈ آپ کے اکاؤنٹ کی چابی ہے۔ کوئی اصل ادارہ کبھی یہ نہیں مانگتا۔"),
        Lesson(ScamType.PRIZE, "\"Congratulations! You won an iPhone in the lucky draw, claim now.\"",
            "You can't win a draw you never entered.",
            "جس قرعہ اندازی میں حصہ نہیں لیا اس میں جیت نہیں سکتے۔"),
        Lesson(ScamType.IMPERSONATION, "\"PTA: your SIM will be blocked in 24 hours, call now for biometric verification.\"",
            "PTA, banks and police don't threaten you by SMS from mobile numbers.",
            "پی ٹی اے، بینک اور پولیس موبائل نمبر سے ایس ایم ایس پر دھمکیاں نہیں دیتے۔"),
        Lesson(ScamType.FAMILY, "\"Ammi, this is my new number, I'm in trouble, send 10,000 on Easypaisa.\"",
            "Call their old number or ask something only they would know.",
            "ان کے پرانے نمبر پر کال کریں یا کوئی ایسی بات پوچھیں جو صرف وہ جانتے ہوں۔"),
        Lesson(ScamType.JOB, "\"Earn Rs 5,000 daily from home by liking videos. Join on Telegram.\"",
            "Easy money tasks end with a \"deposit\" to unlock your earnings.",
            "آسان کمائی والے کام آخر میں \"ڈپازٹ\" مانگتے ہیں۔"),
        Lesson(ScamType.INVESTMENT, "\"Guaranteed 100% profit in 7 days with USDT trading.\"",
            "No real investment guarantees profit.",
            "کوئی اصل سرمایہ کاری منافع کی ضمانت نہیں دیتی۔"),
        Lesson(ScamType.DELIVERY, "\"Your parcel is on hold, pay Rs 150 at tcs-redeliver.top.\"",
            "Track parcels only in the courier's own app.",
            "پارسل صرف کوریئر کی اپنی ایپ میں ٹریک کریں۔"),
        Lesson(ScamType.PHISHING, "\"Your HBL account is blocked, verify at hbl-secure-login.com.\"",
            "Look at the website name: the real one is hbl.com, not something with \"hbl\" in it.",
            "ویب سائٹ کا نام دیکھیں: اصل hbl.com ہے، جس نام میں صرف \"hbl\" ہو وہ اصل نہیں۔"),
    )
}
