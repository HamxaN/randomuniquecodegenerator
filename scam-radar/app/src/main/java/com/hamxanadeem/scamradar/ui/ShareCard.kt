package com.hamxanadeem.scamradar.ui

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.core.content.FileProvider
import com.hamxanadeem.scamradar.R
import com.hamxanadeem.scamradar.core.Result
import com.hamxanadeem.scamradar.core.ShareText
import com.hamxanadeem.scamradar.core.Verdict
import java.io.File

/** A warning picture for WhatsApp groups and status, plus matching text. */
object ShareCard {
    private const val W = 1080
    private const val H = 1350

    fun render(context: Context, r: Result, urdu: Boolean): Bitmap {
        val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val accent = Ui.color(context, r.verdict)
        c.drawColor(Color.parseColor("#10141B"))
        val band = Paint().apply { color = accent }
        c.drawRect(0f, 0f, W.toFloat(), 360f, band)
        val title = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 96f
            typeface = Typeface.DEFAULT_BOLD
        }
        val headline = when (r.verdict) {
            Verdict.SCAM -> if (urdu) "دھوکا ہے!" else "SCAM ALERT"
            Verdict.SUSPICIOUS -> if (urdu) "مشکوک پیغام" else "SUSPICIOUS"
            Verdict.SAFE -> if (urdu) "کوئی خطرہ نہیں ملا" else "LOOKS SAFE"
        }
        val align = if (urdu) Layout.Alignment.ALIGN_OPPOSITE else Layout.Alignment.ALIGN_NORMAL
        draw(c, headline, title, 80f, 90f, W - 160, align)
        val sub = TextPaint(title).apply { textSize = 48f; typeface = Typeface.DEFAULT }
        draw(c, if (urdu) r.type.ur else r.type.en, sub, 80f, 220f, W - 160, align)
        // The message, with links blanked out.
        val body = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#C9D1DB"); textSize = 40f }
        val quote = ShareText.warning(r, urdu).lines().getOrElse(1) { "" }
        val box = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#1C232E") }
        c.drawRoundRect(RectF(60f, 410f, W - 60f, 650f), 28f, 28f, box)
        draw(c, quote, body, 100f, 440f, W - 200, align, 4)
        // Top reasons.
        val reason = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; textSize = 44f }
        var y = 700f
        for (s in r.signals.take(3)) {
            val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent }
            c.drawCircle(if (urdu) W - 80f else 80f, y + 28f, 12f, dot)
            y += draw(c, if (urdu) s.ur else s.en, reason, if (urdu) 80f else 110f, y, W - 200, align, 3) + 30f
            if (y > H - 260f) break
        }
        // Footer.
        val foot = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = accent; textSize = 46f; typeface = Typeface.DEFAULT_BOLD }
        draw(c, context.getString(R.string.card_footer), foot, 80f, H - 190f, W - 160, Layout.Alignment.ALIGN_CENTER)
        val foot2 = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#8D9AAB"); textSize = 34f }
        draw(c, context.getString(R.string.card_footer_sub), foot2, 80f, H - 110f, W - 160, Layout.Alignment.ALIGN_CENTER)
        return bmp
    }

    /** Draws wrapped text and returns its height. */
    private fun draw(c: Canvas, text: String, paint: TextPaint, x: Float, y: Float, width: Int, align: Layout.Alignment, maxLines: Int = 2): Float {
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setAlignment(align)
            .setMaxLines(maxLines)
            .setEllipsize(android.text.TextUtils.TruncateAt.END)
            .build()
        c.save()
        c.translate(x, y)
        layout.draw(c)
        c.restore()
        return layout.height.toFloat()
    }

    fun share(context: Context, r: Result, urdu: Boolean) {
        val uri = runCatching { save(context, render(context, r, urdu)) }.getOrNull()
        val text = ShareText.warning(r, urdu)
        val send = Intent(Intent.ACTION_SEND).apply {
            if (uri != null) {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = ClipData.newRawUri("warning", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                type = "text/plain"
            }
            putExtra(Intent.EXTRA_TEXT, text)
        }
        context.startActivity(Intent.createChooser(send, context.getString(R.string.share_warning)))
    }

    private fun save(context: Context, bmp: Bitmap): Uri {
        val dir = File(context.cacheDir, "cards").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }
        val f = File(dir, "scam-radar-warning-${System.currentTimeMillis()}.png")
        f.outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bmp.recycle()
        return FileProvider.getUriForFile(context, "${context.packageName}.files", f)
    }
}
