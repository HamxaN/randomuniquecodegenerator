package com.hamxanadeem.scamradar.core

/** The text that goes with a shared warning card, ready for WhatsApp groups. */
object ShareText {
    fun warning(r: Result, urdu: Boolean): String {
        val sb = StringBuilder()
        when (r.verdict) {
            Verdict.SCAM -> sb.append(if (urdu) "⚠️ دھوکے کا الرٹ: ${r.type.ur}\n" else "⚠️ SCAM ALERT: ${r.type.en}\n")
            Verdict.SUSPICIOUS -> sb.append(if (urdu) "⚠️ مشکوک پیغام: ${r.type.ur}\n" else "⚠️ Suspicious message: ${r.type.en}\n")
            Verdict.SAFE -> sb.append(if (urdu) "✅ اس پیغام میں خطرے کی کوئی واضح علامت نہیں ملی\n" else "✅ No clear warning signs in this message\n")
        }
        val excerpt = r.text.trim().replace(Regex("\\s+"), " ").let { if (it.length > 140) it.take(137) + "..." else it }
        // Never pass the scam link on.
        var safeExcerpt = excerpt
        for (l in Links.extract(excerpt).sortedByDescending { it.length }) safeExcerpt = safeExcerpt.replace(l, "[link]")
        sb.append("\"").append(safeExcerpt).append("\"\n\n")
        for (s in r.signals.take(3)) {
            sb.append("• ").append(if (urdu) s.ur else s.en).append('\n')
        }
        sb.append('\n')
        sb.append(if (urdu) "اسے آگے بھیجیں تاکہ کوئی اور دھوکا نہ کھائے۔ — Scam Radar سے چیک کیا گیا" else "Forward this so nobody else falls for it. Checked with Scam Radar.")
        return sb.toString()
    }
}
