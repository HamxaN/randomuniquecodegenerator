package com.hamxanadeem.scamradar.ui

import android.content.Context
import android.view.View
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import com.hamxanadeem.scamradar.R
import com.hamxanadeem.scamradar.core.Verdict

object Ui {
    /** Keeps content clear of the status and navigation bars (the app draws edge to edge). */
    fun fitSystemBars(root: View) {
        ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            v.updatePadding(left = bars.left, top = bars.top, right = bars.right, bottom = maxOf(bars.bottom, ime.bottom))
            insets
        }
    }

    fun dp(context: Context, v: Int): Int = (v * context.resources.displayMetrics.density).toInt()

    fun toast(context: Context, text: String) = Toast.makeText(context, text, Toast.LENGTH_SHORT).show()

    fun color(context: Context, v: Verdict): Int = ContextCompat.getColor(context, when (v) {
        Verdict.SCAM -> R.color.scam
        Verdict.SUSPICIOUS -> R.color.suspicious
        Verdict.SAFE -> R.color.safe
    })

    fun verdictText(context: Context, v: Verdict, urdu: Boolean): String = context.getString(when (v) {
        Verdict.SCAM -> if (urdu) R.string.verdict_scam_ur else R.string.verdict_scam
        Verdict.SUSPICIOUS -> if (urdu) R.string.verdict_suspicious_ur else R.string.verdict_suspicious
        Verdict.SAFE -> if (urdu) R.string.verdict_safe_ur else R.string.verdict_safe
    })
}
