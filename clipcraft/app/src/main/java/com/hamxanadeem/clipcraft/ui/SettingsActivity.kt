package com.hamxanadeem.clipcraft.ui

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.ArrayAdapter
import android.widget.AutoCompleteTextView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.materialswitch.MaterialSwitch
import com.google.android.material.slider.Slider
import com.hamxanadeem.clipcraft.R
import com.hamxanadeem.clipcraft.core.Script
import com.hamxanadeem.clipcraft.data.Languages
import com.hamxanadeem.clipcraft.data.Settings

/** AI (own key or a ClipCraft server), language, clips, caption look, YouTube privacy. */
class SettingsActivity : AppCompatActivity() {

    /** A dropdown backed by stored values and their labels. */
    private class Choice(val view: AutoCompleteTextView, val values: List<String>, val labels: List<String>) {
        fun show(value: String) = view.setText(labels[values.indexOf(value).coerceAtLeast(0)], false)
        fun value(): String? = labels.indexOf(view.text.toString()).takeIf { it >= 0 }?.let { values[it] }
    }

    private lateinit var privacy: Choice
    private lateinit var style: Choice
    private lateinit var position: Choice
    private lateinit var script: Choice

    private fun choice(id: Int, values: List<String>, labels: List<String>): Choice {
        val v = findViewById<AutoCompleteTextView>(id)
        v.setAdapter(ArrayAdapter(this, android.R.layout.simple_list_item_1, labels))
        return Choice(v, values, labels)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)
        Ui.fitSystemBars(findViewById(R.id.root))
        findViewById<MaterialToolbar>(R.id.toolbar).setNavigationOnClickListener { finish() }
        findViewById<Button>(R.id.open_ai).setOnClickListener { startActivity(Intent(this, AiActivity::class.java)) }

        val lang = findViewById<AutoCompleteTextView>(R.id.language)
        lang.setAdapter(ArrayAdapter(this, android.R.layout.simple_list_item_1, Languages.ALL.map { it.name }))
        lang.setText(Languages.get(Settings.language(this)).name, false)
        privacy = choice(R.id.privacy, listOf("private", "unlisted", "public"),
            listOf(R.string.privacy_private, R.string.privacy_unlisted, R.string.privacy_public).map { getString(it) })
        privacy.show(Settings.privacy(this))
        style = choice(R.id.caption_style, listOf("karaoke", "boxed", "clean"),
            listOf(R.string.style_karaoke, R.string.style_boxed, R.string.style_clean).map { getString(it) })
        style.show(Settings.captionStyle(this))
        position = choice(R.id.caption_position, listOf("low", "middle", "top"),
            listOf(R.string.position_low, R.string.position_middle, R.string.position_top).map { getString(it) })
        position.show(Settings.captionPosition(this))
        script = choice(R.id.script, Script.entries.map { it.name }, Script.entries.map { it.label })
        script.show(Settings.script(this))

        val count = findViewById<Slider>(R.id.count)
        count.value = Settings.clipCount(this).toFloat().coerceIn(1f, 10f)
        findViewById<MaterialSwitch>(R.id.captions).isChecked = Settings.captions(this)
        findViewById<MaterialSwitch>(R.id.hook).isChecked = Settings.hook(this)
        findViewById<MaterialSwitch>(R.id.reframe).isChecked = Settings.reframe(this)
        findViewById<MaterialSwitch>(R.id.platform_links).isChecked = Settings.allowPlatformLinks(this)
    }

    override fun onResume() {
        super.onResume()
        findViewById<Button>(R.id.open_ai).setText(when (Settings.aiMode(this)) {
            Settings.AI_KEY -> if (Settings.aiReady(this)) R.string.ai_row_key else R.string.ai_row_incomplete
            Settings.AI_SERVER -> if (Settings.aiReady(this)) R.string.ai_row_server else R.string.ai_row_incomplete
            else -> R.string.ai_row_off
        })
    }

    override fun onPause() {
        super.onPause()
        val langName = findViewById<AutoCompleteTextView>(R.id.language).text.toString()
        Languages.ALL.firstOrNull { it.name == langName }?.let { Settings.setLanguage(this, it.code) }
        privacy.value()?.let { Settings.setPrivacy(this, it) }
        style.value()?.let { Settings.setCaptionStyle(this, it) }
        position.value()?.let { Settings.setCaptionPosition(this, it) }
        script.value()?.let { Settings.setScript(this, it) }
        Settings.setClipCount(this, findViewById<Slider>(R.id.count).value.toInt())
        Settings.setCaptions(this, findViewById<MaterialSwitch>(R.id.captions).isChecked)
        Settings.setHook(this, findViewById<MaterialSwitch>(R.id.hook).isChecked)
        Settings.setReframe(this, findViewById<MaterialSwitch>(R.id.reframe).isChecked)
        Settings.setAllowPlatformLinks(this, findViewById<MaterialSwitch>(R.id.platform_links).isChecked)
    }
}
