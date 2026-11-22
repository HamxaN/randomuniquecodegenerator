package com.hamxanadeem.scamradar.core

/**
 * Scores a message for scam warning signs. Everything runs on the phone: a set of
 * weighted rules in English, Roman Urdu and Urdu, plus link checks. Each sign
 * explains itself so people learn what to look for.
 */
object Analyzer {
    const val SCAM_AT = 55
    const val SUSPICIOUS_AT = 25

    private val PRIZE = listOf("you have won", "you won", "winner", "lucky draw", "lucky winner",
        "jackpot", "prize", "lottery", "cash reward", "claim your", "claim now", "free iphone", "selected for",
        "inaam", "inam", "jeet", "jeeta", "jeeti", "qurandazi", "قرعہ اندازی", "انعام", "جیت")
    // Greetings like "Eid Mubarak" only count next to money, a link or a number.
    private val CONGRATS = listOf("congratulations", "congrats", "mubarak ho", "مبارک ہو")
    private val GOVT = listOf("bisp", "ehsaas", "benazir", "kafalat", "8171", "sasta", "nashonuma", "ramzan package", "relief package",
        "بینظیر", "احساس", "کفالت", "امدادی", "بی آئی ایس پی")
    private val MONEY_RELEASE = listOf("raqam", "rqm", "amount", "payment", "paisay", "paise", "funds", "released", "jari", "receive",
        "wusool", "رقم", "پیسے", "وصول", "جاری")
    private val URGENT = listOf("urgent", "urgently", "immediately", "within 24 hours", "within 24 hrs", "last chance", "expires today",
        "act now", "final notice", "final warning", "foran", "fori", "jaldi", "abhi", "aaj hi", "فوری", "فوراً", "جلدی", "آج ہی", "آخری موقع")
    private val CODE_WORDS = listOf("otp", "pin", "password", "passcode", "verification code", "security code", "6 digit", "6-digit",
        "cvv", "mpin", "tpin", "کوڈ", "پن", "پاس ورڈ")
    private val PLAIN_CODE = listOf("code")
    private val ASK_WORDS = listOf("share", "send", "tell", "forward", "provide", "give", "reply with", "bata", "batain", "bataen",
        "bhej", "bhejain", "bhejen", "send kar", "share kar", "batayen", "بتائیں", "بھیجیں", "بھیج", "شیئر")
    private val NEVER_SHARE = listOf("do not share", "don't share", "never share", "dont share", "do not disclose", "kisi ko na",
        "share na", "na batayen", "کسی کو نہ", "شیئر نہ", "نہ بتائیں")
    private val CNIC = listOf("cnic", "id card", "shanakhti", "شناختی کارڈ", "card number", "card no", "atm card", "debit card number")
    private val WRONG_TRANSFER = listOf("galti se", "ghalti se", "by mistake", "mistakenly", "wrong number", "wrong account", "wapas kar",
        "wapis kar", "return the money", "send it back", "return it", "galat number", "غلطی سے", "واپس کر", "غلط نمبر")
    private val FEE = listOf("processing fee", "registration fee", "service charges", "service charge", "advance payment", "pay first",
        "security deposit", "delivery charges", "customs fee", "tax fee", "fees jama", "fee jama", "fees deni", "fee deni",
        "fee send", "fee bhej", "فیس", "پیشگی")
    private val JOB = listOf("work from home", "online job", "part time job", "part-time job", "daily earning", "earn daily",
        "earn money", "like videos", "like and earn", "subscribe and earn", "per day", "rozana", "ghar baithe", "ghar bethe",
        "kamaen", "kamayen", "گھر بیٹھے", "روزانہ", "کمائیں")
    private val INVEST = listOf("double your money", "guaranteed profit", "guaranteed return", "daily profit", "investment plan",
        "invest now", "usdt", "crypto", "bitcoin", "trading signals", "forex", "binary option", "100% profit", "profit daily",
        "munafa", "منافع", "سرمایہ کاری")
    private val IMPERSONATE = listOf("pta", "fia", "cyber crime", "police", "your sim will be blocked", "sim will be blocked",
        "sim block", "sim band", "biometric verification", "account will be blocked", "account blocked", "account suspended",
        "account has been suspended", "account is suspended", "account is blocked", "dear customer", "kyc", "update your details", "verify your account", "army", "officer", "court",
        "account band", "sim band ho", "اکاؤنٹ بند", "سم بند", "تصدیق")
    private val FAMILY = listOf("new number", "naya number", "mera number", "lost my phone", "phone kho", "phone gum", "accident",
        "hospital", "emergency", "urgent money", "mama", "ammi", "abbu", "beta", "نیا نمبر", "ایکسیڈنٹ", "ہسپتال")
    private val SEND_MONEY = listOf("send money", "send me", "paise bhej", "paisay bhej", "pese bhej", "transfer", "easypaisa kar",
        "jazzcash kar", "load kar", "balance bhej", "paise chahiye", "پیسے بھیج", "پیسے چاہیے")
    private val DELIVERY = listOf("parcel", "package", "shipment", "courier", "delivery failed", "could not be delivered",
        "redelivery", "address incomplete", "pending delivery", "پارسل")
    private val CONTACT = listOf("whatsapp", "call", "contact", "rabta", "raabta", "click", "tap", "visit", "رابطہ", "کال")
    private val BANKS = listOf("bank", "hbl", "ubl", "mcb", "meezan", "alfalah", "allied", "jazzcash", "easypaisa", "bisp", "nadra",
        "بینک")
    private val PHONE = Regex("(?:\\+?92|0)3\\d{2}[- ]?\\d{7}")
    private val AMOUNT = Regex("(?i)(?:rs\\.?|pkr|روپے|\\$|usd)\\s?[\\d,]{3,}|[\\d,]{4,}\\s?(?:rs|rupees|روپے|pkr)")

    fun analyze(raw: String, sender: String = ""): Result {
        val norm = Normalize.text(raw)
        val words = Normalize.words(norm)
        val signals = mutableListOf<Signal>()
        fun add(s: Signal) {
            if (signals.none { it.id == s.id }) signals += s
        }
        val links = Links.extract(raw).map { Links.check(it) }
        val hasLink = links.isNotEmpty()
        val riskyLink = links.any { it.risky }
        val phones = PHONE.findAll(norm.replace(" ", "")).map { it.value }.toList()
        val hasPhone = phones.isNotEmpty()
        val hasAmount = AMOUNT.containsMatchIn(norm)
        val has = { list: List<String> -> Normalize.hasAny(norm, words, list) }

        // Links.
        for (l in links) {
            for (p in l.problems) {
                when {
                    p == "shortener" -> add(Signal("short", 22, ScamType.PHISHING, "Uses a link shortener (${l.host}) that hides where it really goes.",
                        "لنک کو چھوٹا کر کے اصل ویب سائٹ چھپائی گئی ہے (${l.host})۔"))
                    p == "ip" -> add(Signal("ip", 28, ScamType.PHISHING, "The link is a bare number address, not a real website name.",
                        "لنک کسی ویب سائٹ کا نام نہیں بلکہ صرف نمبروں والا پتہ ہے۔"))
                    p == "punycode" -> add(Signal("puny", 30, ScamType.PHISHING, "The link uses look-alike letters to copy a real website.",
                        "لنک میں ملتے جلتے حروف سے اصل ویب سائٹ کی نقل کی گئی ہے۔"))
                    p == "tld" -> add(Signal("tld", 18, ScamType.PHISHING, "The website ending (.${l.host.substringAfterLast('.')}) is cheap and often used by scammers.",
                        "ویب سائٹ کا اختتام (.${l.host.substringAfterLast('.')}) اکثر دھوکے باز استعمال کرتے ہیں۔"))
                    p == "at" -> add(Signal("at", 25, ScamType.PHISHING, "The link hides its real destination after an @ sign.",
                        "لنک @ کے نشان کے بعد اپنی اصل منزل چھپاتا ہے۔"))
                    p == "dashes" -> add(Signal("dashes", 10, ScamType.PHISHING, "The website name is long and full of dashes, a common fake pattern.",
                        "ویب سائٹ کا نام لمبا اور ڈیش سے بھرا ہے، جو جعلی سائٹوں کی عام نشانی ہے۔"))
                    p.startsWith("lookalike:") -> {
                        val brand = p.substringAfter(':').uppercase()
                        add(Signal("lookalike", 38, ScamType.PHISHING, "The link pretends to be $brand but is not $brand's real website (${l.host}).",
                            "لنک $brand ہونے کا دعویٰ کرتا ہے مگر یہ $brand کی اصل ویب سائٹ نہیں (${l.host})۔"))
                    }
                }
            }
        }

        // Words and patterns.
        val congratsBait = has(CONGRATS) && (hasLink || hasPhone || hasAmount)
        if (has(PRIZE) || congratsBait) add(Signal("prize", 26, ScamType.PRIZE, "Says you've won a prize or lottery you never entered.",
            "کہا گیا ہے کہ آپ نے انعام جیتا ہے، حالانکہ آپ نے کسی مقابلے میں حصہ نہیں لیا۔"))
        val govt = has(GOVT)
        if (govt && (hasLink || hasPhone || has(FEE) || (has(MONEY_RELEASE) && has(CONTACT)))) {
            add(Signal("govt", 34, ScamType.GOVT, "Promises a BISP / Ehsaas payment and asks you to click, call or pay. The real programme only uses 8171 and never asks for fees.",
                "بی آئی ایس پی / احساس کی رقم کا وعدہ کر کے لنک، کال یا فیس مانگی گئی ہے۔ اصل پروگرام صرف 8171 استعمال کرتا ہے اور کوئی فیس نہیں لیتا۔"))
        }
        val strongCode = has(CODE_WORDS)
        val codeAsked = (strongCode || has(PLAIN_CODE)) && has(ASK_WORDS) && !has(NEVER_SHARE)
        if (codeAsked) add(Signal("otp", if (strongCode) 58 else 30, ScamType.OTP, "Asks you to share a code, PIN or password. No bank or company ever asks for this.",
            "آپ سے کوڈ، پن یا پاس ورڈ مانگا گیا ہے۔ کوئی بینک یا کمپنی کبھی یہ نہیں مانگتی۔"))
        if (has(CNIC) && (has(ASK_WORDS) || hasLink)) add(Signal("cnic", 20, ScamType.IMPERSONATION, "Asks for your ID card or card number.",
            "آپ کا شناختی کارڈ یا کارڈ نمبر مانگا گیا ہے۔"))
        if (has(WRONG_TRANSFER)) add(Signal("wrong", 36, ScamType.WRONG_TRANSFER, "Claims money was sent to you by mistake and asks for it back. Check your real balance in your app first, as the \"received\" SMS is often fake.",
            "دعویٰ کیا گیا ہے کہ غلطی سے رقم آپ کو بھیجی گئی اور واپس مانگی گئی ہے۔ پہلے اپنی ایپ میں اصل بیلنس چیک کریں، \"وصولی\" کا ایس ایم ایس اکثر جعلی ہوتا ہے۔"))
        if (has(FEE)) add(Signal("fee", 26, ScamType.FEE, "Asks you to pay a fee first to receive something.",
            "کچھ حاصل کرنے کے لیے پہلے فیس ادا کرنے کو کہا گیا ہے۔"))
        val payPerDay = hasAmount && has(listOf("daily", "per day", "a day", "rozana", "روزانہ", "per hour"))
        if (has(JOB) && (hasAmount || hasPhone || hasLink || has(listOf("telegram", "whatsapp")))) add(Signal("job", if (payPerDay) 40 else 26, ScamType.JOB,
            "Offers easy money for little work, a classic trap that ends with you paying.",
            "تھوڑے کام کے بدلے آسان کمائی کی پیشکش، جو عام طور پر آپ سے پیسے لینے پر ختم ہوتی ہے۔"))
        val investHits = Normalize.count(norm, words, INVEST) + (if (Regex("\\d+\\s?%").containsMatchIn(norm)) 1 else 0)
        if (investHits > 0) add(Signal("invest", minOf(30 + (investHits - 1) * 10, 50), ScamType.INVESTMENT, "Promises guaranteed or fast profits. Real investments never guarantee returns.",
            "یقینی یا تیز منافع کا وعدہ کیا گیا ہے۔ اصل سرمایہ کاری میں کبھی منافع کی ضمانت نہیں ہوتی۔"))
        val threat = has(listOf("block", "blocked", "suspend", "suspended", "band", "بند", "deactivat", "expire"))
        if (has(IMPERSONATE) && (threat || hasLink || hasPhone || codeAsked)) add(Signal("imp",
            if (threat && (hasPhone || hasLink)) 32 else 22, ScamType.IMPERSONATION,
            "Pretends to be a bank, PTA, FIA or police and threatens to block you.",
            "بینک، پی ٹی اے، ایف آئی اے یا پولیس بن کر آپ کو بند کرنے کی دھمکی دی گئی ہے۔"))
        val newNumber = has(listOf("new number", "naya number", "lost my phone", "phone kho", "phone gum", "phone kharab", "نیا نمبر"))
        if (has(FAMILY) && has(SEND_MONEY)) add(Signal("family", if (newNumber) 46 else 32, ScamType.FAMILY,
            "Someone \"close to you\" on a new number needs money urgently. Call them on their old number first.",
            "کوئی \"قریبی\" نئے نمبر سے فوری پیسے مانگ رہا ہے۔ پہلے ان کے پرانے نمبر پر کال کر کے تصدیق کریں۔"))
        if (has(DELIVERY) && (hasLink || has(FEE))) add(Signal("delivery", 24, ScamType.DELIVERY,
            "A parcel \"needs action\" through a link or fee. Check on the courier's own app instead.",
            "پارسل کے لیے لنک یا فیس مانگی گئی ہے۔ اس کے بجائے کوریئر کی اپنی ایپ پر چیک کریں۔"))
        if (has(URGENT)) add(Signal("urgent", 12, ScamType.NONE, "Pushes you to act fast so you don't stop and think.",
            "جلدی کرنے پر زور دیا گیا ہے تاکہ آپ سوچنے کا وقت نہ لیں۔"))
        if (hasPhone && has(CONTACT) && signals.isNotEmpty()) add(Signal("phone", 12, ScamType.NONE,
            "Asks you to call or WhatsApp a personal mobile number (${phones.first()}). Real companies use official helplines.",
            "ذاتی موبائل نمبر (${phones.first()}) پر کال یا واٹس ایپ کرنے کو کہا گیا ہے۔ اصل ادارے سرکاری ہیلپ لائن استعمال کرتے ہیں۔"))
        // A bank message from a personal mobile number.
        val s = sender.replace(" ", "").replace("-", "")
        if (s.isNotEmpty() && PHONE.matches(s) && has(BANKS)) add(Signal("sender", 22, ScamType.IMPERSONATION,
            "Claims to be from a bank or wallet but came from an ordinary mobile number.",
            "بینک یا والٹ ہونے کا دعویٰ ہے مگر پیغام عام موبائل نمبر سے آیا ہے۔"))
        val shouting = raw.count { it == '!' } >= 4 || (raw.length > 30 && raw.count { it.isUpperCase() } > raw.count { it.isLowerCase() } * 1.5)
        if (shouting && signals.isNotEmpty()) add(Signal("shout", 5, ScamType.NONE, "Lots of capitals and exclamation marks to excite you.",
            "جوش دلانے کے لیے بہت زیادہ بڑے حروف اور فجائیہ نشان۔"))
        if (hasLink && !riskyLink && signals.any { it.weight >= 20 } && links.none { Links.official(it.host) }) add(Signal("link", 14, ScamType.PHISHING,
            "Asks you to open a link that isn't an official website.",
            "ایک ایسا لنک کھولنے کو کہا گیا ہے جو سرکاری ویب سائٹ نہیں ہے۔"))

        var score = signals.sumOf { it.weight }
        // "Sent by mistake" plus a number or an amount to send back.
        if (signals.any { it.id == "wrong" } && (hasPhone || hasAmount || Regex("\\d{3,}").containsMatchIn(norm))) score += 22
        // Combos that are almost always scams.
        if (riskyLink && signals.any { it.id in setOf("prize", "govt", "fee", "otp", "delivery", "imp") }) score += 12
        if (hasAmount && signals.any { it.id in setOf("prize", "govt", "wrong", "job", "invest") }) score += 6
        score = score.coerceIn(0, 100)
        val verdict = when {
            score >= SCAM_AT -> Verdict.SCAM
            score >= SUSPICIOUS_AT -> Verdict.SUSPICIOUS
            else -> Verdict.SAFE
        }
        val type = signals.filter { it.type != ScamType.NONE }.maxByOrNull { it.weight }?.type ?: ScamType.NONE
        return Result(raw, verdict, score, if (verdict == Verdict.SAFE) ScamType.NONE else type,
            signals.sortedByDescending { it.weight }, links)
    }
}
