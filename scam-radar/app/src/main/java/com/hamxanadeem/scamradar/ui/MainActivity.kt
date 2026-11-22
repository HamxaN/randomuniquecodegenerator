package com.hamxanadeem.scamradar.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.content.IntentCompat
import androidx.core.widget.NestedScrollView
import com.google.android.material.appbar.MaterialToolbar
import com.hamxanadeem.scamradar.R
import com.hamxanadeem.scamradar.core.Analyzer
import com.hamxanadeem.scamradar.core.Result
import com.hamxanadeem.scamradar.core.ShareText
import com.hamxanadeem.scamradar.core.Verdict
import com.hamxanadeem.scamradar.data.Store

/** Paste, share or scan a message and see whether it's a scam, and why. */
class MainActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_CHECK = "check_text"
    }

    private lateinit var message: EditText
    private lateinit var sender: EditText
    private lateinit var resultBox: View
    private lateinit var scroll: NestedScrollView
    private lateinit var toolbar: MaterialToolbar
    private var last: Result? = null
    private var urdu = false

    private val pickImage = registerForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) readScreenshot(uri)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        Ui.fitSystemBars(findViewById(R.id.root))
        urdu = Store.urdu(this)
        toolbar = findViewById(R.id.toolbar)
        toolbar.setOnMenuItemClickListener {
            when (it.itemId) {
                R.id.action_history -> startActivity(Intent(this, HistoryActivity::class.java))
                R.id.action_learn -> startActivity(Intent(this, LearnActivity::class.java))
                R.id.action_lang -> {
                    urdu = !urdu
                    Store.setUrdu(this, urdu)
                    updateLangItem()
                    last?.let { r -> show(r) }
                }
            }
            true
        }
        updateLangItem()
        message = findViewById(R.id.message)
        sender = findViewById(R.id.sender)
        resultBox = findViewById(R.id.result)
        scroll = findViewById(R.id.scroll)
        findViewById<View>(R.id.paste).setOnClickListener { paste() }
        findViewById<View>(R.id.screenshot).setOnClickListener {
            pickImage.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        }
        findViewById<View>(R.id.check).setOnClickListener { check() }
        findViewById<View>(R.id.share_warning).setOnClickListener { last?.let { ShareCard.share(this, it, urdu) } }
        findViewById<View>(R.id.copy).setOnClickListener {
            last?.let { r ->
                val cm = getSystemService(ClipboardManager::class.java)
                cm?.setPrimaryClip(ClipData.newPlainText("warning", ShareText.warning(r, urdu)))
                Ui.toast(this, getString(R.string.copied))
            }
        }
        findViewById<View>(R.id.clear).setOnClickListener {
            message.setText("")
            sender.setText("")
            resultBox.visibility = View.GONE
            last = null
            message.requestFocus()
        }
        if (savedInstanceState == null) handle(intent)
        updateFooter()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun updateLangItem() {
        toolbar.menu.findItem(R.id.action_lang)?.title = getString(if (urdu) R.string.lang_english else R.string.lang_urdu)
    }

    /** Text or a screenshot shared from another app, or text picked from History. */
    private fun handle(intent: Intent?) {
        if (intent == null) return
        intent.getStringExtra(EXTRA_CHECK)?.let {
            message.setText(it)
            check()
            return
        }
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                val uri = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
                when {
                    !text.isNullOrBlank() -> {
                        message.setText(text)
                        check()
                    }
                    uri != null -> readScreenshot(uri)
                }
            }
            Intent.ACTION_PROCESS_TEXT -> {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
                if (!text.isNullOrBlank()) {
                    message.setText(text)
                    check()
                }
            }
        }
    }

    private fun paste() {
        val cm = getSystemService(ClipboardManager::class.java)
        val text = cm?.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(this)?.toString()
        if (text.isNullOrBlank()) {
            Ui.toast(this, getString(R.string.nothing_copied))
            return
        }
        message.setText(text)
        check()
    }

    private fun readScreenshot(uri: Uri) {
        Ui.toast(this, getString(R.string.reading_screenshot))
        Ocr.read(this, uri) { text ->
            if (isFinishing || isDestroyed) return@read
            if (text.isNullOrBlank()) {
                Ui.toast(this, getString(R.string.no_text_found))
            } else {
                message.setText(text)
                check()
            }
        }
    }

    private fun check() {
        val text = message.text.toString()
        if (text.isBlank()) {
            message.error = getString(R.string.paste_first)
            return
        }
        getSystemService(InputMethodManager::class.java)?.hideSoftInputFromWindow(message.windowToken, 0)
        val r = Analyzer.analyze(text, sender.text.toString())
        last = r
        Store.record(this, r)
        Store.countCheck(this)
        show(r)
        updateFooter()
        if (r.verdict == Verdict.SCAM) {
            resultBox.performHapticFeedback(android.view.HapticFeedbackConstants.LONG_PRESS)
        }
    }

    private fun show(r: Result) {
        resultBox.visibility = View.VISIBLE
        val color = Ui.color(this, r.verdict)
        val header = findViewById<View>(R.id.header)
        header.background = GradientDrawable().apply {
            setColor(color)
            cornerRadius = Ui.dp(this@MainActivity, 18).toFloat()
        }
        findViewById<TextView>(R.id.verdict_title).text = Ui.verdictText(this, r.verdict, urdu)
        findViewById<TextView>(R.id.verdict_type).text = if (urdu) r.type.ur else r.type.en
        findViewById<ScoreRing>(R.id.ring).set(r.score, color)
        val dir = if (urdu) View.TEXT_DIRECTION_RTL else View.TEXT_DIRECTION_LTR
        findViewById<TextView>(R.id.why_title).setText(if (urdu) R.string.why_ur else R.string.why)
        val reasons = findViewById<LinearLayout>(R.id.reasons)
        reasons.removeAllViews()
        if (r.signals.isEmpty()) {
            reasons.addView(line(getString(if (urdu) R.string.no_signs_ur else R.string.no_signs), dir, ContextCompat.getColor(this, R.color.ink_soft)))
        }
        for (s in r.signals) {
            reasons.addView(line("•  " + (if (urdu) s.ur else s.en), dir, ContextCompat.getColor(this, R.color.ink)))
        }
        val links = findViewById<LinearLayout>(R.id.links)
        links.removeAllViews()
        findViewById<View>(R.id.links_title).visibility = if (r.links.isEmpty()) View.GONE else View.VISIBLE
        for (l in r.links) {
            val bad = l.risky
            val t = line((if (bad) "⚠  " else "✓  ") + l.host, View.TEXT_DIRECTION_LTR,
                ContextCompat.getColor(this, if (bad) R.color.scam else R.color.safe))
            links.addView(t)
        }
        findViewById<TextView>(R.id.advice_title).setText(if (urdu) R.string.advice_ur else R.string.advice)
        val advice = findViewById<LinearLayout>(R.id.advice)
        advice.removeAllViews()
        for ((i, a) in r.advice(urdu).withIndex()) {
            advice.addView(line("${i + 1}.  $a", dir, ContextCompat.getColor(this, R.color.ink)))
        }
        findViewById<TextView>(R.id.share_warning).setText(if (urdu) R.string.share_warning_ur else R.string.share_warning)
        scroll.post { scroll.smoothScrollTo(0, resultBox.top - Ui.dp(this, 8)) }
    }

    private fun line(text: String, dir: Int, color: Int): TextView = TextView(this).apply {
        this.text = text
        textSize = 16f
        setTextColor(color)
        textDirection = dir
        gravity = if (dir == View.TEXT_DIRECTION_RTL) Gravity.END else Gravity.START
        setPadding(0, Ui.dp(this@MainActivity, 5), 0, Ui.dp(this@MainActivity, 5))
        setLineSpacing(0f, 1.15f)
    }

    private fun updateFooter() {
        val n = Store.checks(this)
        findViewById<TextView>(R.id.footer).text = resources.getQuantityString(R.plurals.checked_count, n, n)
    }
}
