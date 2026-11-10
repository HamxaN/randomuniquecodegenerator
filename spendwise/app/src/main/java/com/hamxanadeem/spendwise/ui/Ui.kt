package com.hamxanadeem.spendwise.ui

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.core.Category
import com.hamxanadeem.spendwise.core.Kind
import com.hamxanadeem.spendwise.core.Money
import com.hamxanadeem.spendwise.core.Txn
import com.hamxanadeem.spendwise.data.Store
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.util.Locale

/** Small helpers shared by the screens. */
object Ui {

    /** Keeps content clear of the status and navigation bars (the app draws edge to edge). */
    fun fitSystemBars(root: View, bottom: Boolean = true) {
        ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
            v.updatePadding(left = bars.left, top = bars.top, right = bars.right,
                bottom = if (bottom) maxOf(bars.bottom, ime.bottom) else 0)
            insets
        }
    }

    fun dp(context: Context, v: Int): Int = (v * context.resources.displayMetrics.density).toInt()

    fun money(context: Context, minor: Long): String = Money.format(minor, Store.currency(context))

    fun short(context: Context, minor: Long): String = Money.short(minor, Store.currency(context))

    /** "−$4.50" for spending, "+$2,000.00" for income. */
    fun signed(context: Context, t: Txn): String = (if (t.kind == Kind.INCOME) "+" else "−") + money(context, t.amount)

    /** Amount as typed back into an edit box ("4.50", "1250"). */
    fun plain(context: Context, minor: Long): String = Money.toDecimal(minor, Store.currency(context)).toPlainString()

    private val ICONS = mapOf(
        "food" to "🍔", "cart" to "🛒", "car" to "🚗", "bolt" to "⚡", "bag" to "🛍️", "repeat" to "🔁",
        "heart" to "💊", "star" to "🎬", "plane" to "✈️", "book" to "📚", "home" to "🏠", "dots" to "📦",
        "wallet" to "💼", "briefcase" to "💻", "gift" to "🎁", "plus" to "💰",
    )

    /** Emoji choices offered when making a category. */
    val EMOJI = listOf("🍔", "☕", "🛒", "🚗", "⛽", "⚡", "🏠", "🛍️", "🔁", "💊", "🎬", "✈️", "📚", "🐶", "👶",
        "🎮", "🏋️", "💇", "🍺", "🎁", "📱", "🧾", "💼", "💻", "💰", "📈", "🏦", "📦")

    /** Colours offered when making a category. */
    val COLORS = listOf(0xFFEF6C00, 0xFF2E7D32, 0xFF1565C0, 0xFF6A1B9A, 0xFFC2185B, 0xFF00838F, 0xFFD32F2F,
        0xFFF9A825, 0xFF0277BD, 0xFF4E342E, 0xFF558B2F, 0xFF757575)

    fun emoji(icon: String): String = ICONS[icon] ?: icon.ifBlank { "•" }

    /** Draws a category's emoji in a soft circle of its colour. */
    fun badge(view: TextView, c: Category?) {
        view.text = emoji(c?.icon ?: "dots")
        val color = (c?.color ?: 0xFF757575).toInt()
        view.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor((color and 0x00FFFFFF) or 0x33000000)
        }
    }

    private val dayFormat = DateTimeFormatter.ofPattern("EEE, d MMM", Locale.getDefault())
    private val dayYearFormat = DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)

    fun day(context: Context, d: LocalDate, today: LocalDate = LocalDate.now()): String = when (d) {
        today -> context.getString(R.string.today)
        today.minusDays(1) -> context.getString(R.string.yesterday)
        else -> if (d.year == today.year) d.format(dayFormat) else d.format(dayYearFormat)
    }

    fun month(m: YearMonth): String =
        m.month.getDisplayName(TextStyle.FULL_STANDALONE, Locale.getDefault()) +
            if (m.year != YearMonth.now().year) " ${m.year}" else ""

    fun toast(context: Context, text: String) = Toast.makeText(context, text, Toast.LENGTH_SHORT).show()

    /** Wraps an edit box with dialog-style padding. */
    fun padded(context: Context, child: View): View = FrameLayout(context).apply {
        setPadding(dp(context, 24), dp(context, 8), dp(context, 24), 0)
        addView(child, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
    }

    fun amountOf(context: Context, box: EditText): Long? =
        Money.parse(box.text.toString(), Store.currency(context))?.takeIf { it > 0 }
}
