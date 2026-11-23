package com.hamxanadeem.clipcraft.ui

import android.content.Context
import android.view.View
import android.widget.Toast
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding

object Ui {
    fun fitSystemBars(root: View) {
        ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            v.updatePadding(left = bars.left, top = bars.top, right = bars.right, bottom = maxOf(bars.bottom, ime.bottom))
            insets
        }
    }

    fun dp(c: Context, v: Int) = (v * c.resources.displayMetrics.density).toInt()

    fun toast(c: Context, text: String) = Toast.makeText(c, text, Toast.LENGTH_LONG).show()
}
