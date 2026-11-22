package com.hamxanadeem.scamradar.core

import java.util.Locale

/** Finds links in a message and checks them for the usual tricks. */
object Links {
    private val URL = Regex(
        "(?i)\\b((?:https?://|www\\.)[^\\s<>\"']+|(?:[a-z0-9-]+\\.)+(?:com|pk|net|org|info|xyz|top|click|icu|live|online|site|buzz|loan|win|link|ly|gl|me|io|co|cc|tk|ml|ga|cf|gq|shop|store|app|vip|club|in|ru|cn)(?:/[^\\s<>\"']*)?)"
    )

    val SHORTENERS = setOf("bit.ly", "tinyurl.com", "cutt.ly", "rb.gy", "t.ly", "is.gd", "shorturl.at", "goo.gl", "tiny.cc",
        "ow.ly", "s.id", "rebrand.ly", "t.co", "bit.do", "shorte.st", "v.gd", "urlz.fr", "lnkd.in", "qr.ae")

    val RISKY_TLDS = setOf("xyz", "top", "click", "icu", "live", "online", "site", "buzz", "loan", "win", "tk", "ml", "ga",
        "cf", "gq", "vip", "club", "shop", "store", "info", "ru", "cn", "cc", "rest", "cyou", "sbs", "mom")

    /** Brands scammers copy, with their real domains. */
    val BRANDS: Map<String, List<String>> = mapOf(
        "jazzcash" to listOf("jazzcash.com.pk"),
        "easypaisa" to listOf("easypaisa.com.pk"),
        "bisp" to listOf("bisp.gov.pk"),
        "ehsaas" to listOf("pass.gov.pk", "bisp.gov.pk"),
        "benazir" to listOf("bisp.gov.pk"),
        "nadra" to listOf("nadra.gov.pk"),
        "meezan" to listOf("meezanbank.com"),
        "hbl" to listOf("hbl.com"),
        "ubl" to listOf("ubldigital.com", "ubl.com.pk"),
        "mcb" to listOf("mcb.com.pk"),
        "alfalah" to listOf("bankalfalah.com"),
        "daraz" to listOf("daraz.pk"),
        "paypal" to listOf("paypal.com"),
        "amazon" to listOf("amazon.com", "amazon.ae"),
        "netflix" to listOf("netflix.com"),
        "whatsapp" to listOf("whatsapp.com", "whatsapp.net", "wa.me"),
        "facebook" to listOf("facebook.com", "fb.com"),
        "instagram" to listOf("instagram.com"),
        "apple" to listOf("apple.com"),
        "icloud" to listOf("icloud.com"),
        "google" to listOf("google.com", "google.com.pk"),
        "dhl" to listOf("dhl.com"),
        "fedex" to listOf("fedex.com"),
        "tcs" to listOf("tcsexpress.com"),
        "leopards" to listOf("leopardscourier.com"),
        "pta" to listOf("pta.gov.pk"),
        "fbr" to listOf("fbr.gov.pk"),
        "telenor" to listOf("telenor.com.pk"),
        "zong" to listOf("zong.com.pk"),
        "ufone" to listOf("ufone.com"),
        "binance" to listOf("binance.com"),
    )

    fun extract(text: String): List<String> =
        URL.findAll(text).map { it.value.trimEnd('.', ',', ')', '!', '?', ';', ':') }
            .filter { it.contains('.') }
            .distinct().toList()

    fun host(url: String): String {
        var u = url.lowercase(Locale.ROOT)
        u = u.substringAfter("://")
        u = u.substringBefore('/').substringBefore('?').substringBefore('#')
        u = u.substringAfterLast('@').substringBefore(':')
        return u.removePrefix("www.")
    }

    private fun isIp(host: String) = Regex("^\\d{1,3}(\\.\\d{1,3}){3}$").matches(host)

    private fun belongsTo(host: String, domain: String) = host == domain || host.endsWith(".$domain")

    fun check(url: String): LinkCheck {
        val h = host(url)
        val problems = mutableListOf<String>()
        if (SHORTENERS.contains(h)) problems += "shortener"
        if (isIp(h)) problems += "ip"
        if (h.startsWith("xn--") || h.contains(".xn--")) problems += "punycode"
        val tld = h.substringAfterLast('.')
        if (tld in RISKY_TLDS) problems += "tld"
        if (url.substringAfter("://", "").substringBefore('/').contains('@')) problems += "at"
        for ((brand, real) in BRANDS) {
            val label = h.split('.', '-').any { it == brand } || h.replace("-", "").contains(brand)
            if (label && real.none { belongsTo(h, it) }) {
                problems += "lookalike:$brand"
                break
            }
        }
        if (h.count { it == '-' } >= 3) problems += "dashes"
        return LinkCheck(url, h, problems)
    }

    /** True if the link goes to a brand's real site. */
    fun official(host: String): Boolean = BRANDS.values.flatten().any { belongsTo(host, it) }
}
