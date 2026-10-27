package com.hamxanadeem.wigglewars.ui

import android.content.Context
import android.util.AttributeSet
import android.util.TypedValue
import androidx.appcompat.widget.AppCompatButton
import androidx.core.widget.TextViewCompat
import com.hamxanadeem.wigglewars.R

/** A button in the neon style: cut corners, glowing edge, Orbitron caps. Colour via app:neonColor. */
class NeonButton @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = androidx.appcompat.R.attr.buttonStyle,
) : AppCompatButton(context, attrs, defStyleAttr) {

    init {
        val a = context.obtainStyledAttributes(attrs, R.styleable.NeonButton)
        val accent = a.getColor(R.styleable.NeonButton_neonColor, Neon.CYAN)
        a.recycle()
        val dp = resources.displayMetrics.density
        background = NeonDrawable(accent, dp)
        typeface = Neon.bold(context)
        isAllCaps = true
        letterSpacing = 0.06f
        setTextColor(0xFFFFFFFF.toInt())
        setShadowLayer(8 * dp, 0f, 0f, accent)
        stateListAnimator = null
        // Orbitron is wide: shrink long labels to fit instead of cutting them off.
        val min = (9 * dp).toInt()
        TextViewCompat.setAutoSizeTextTypeUniformWithConfiguration(this, min, textSize.toInt().coerceAtLeast(min + 1), 1, TypedValue.COMPLEX_UNIT_PX)
    }
}
