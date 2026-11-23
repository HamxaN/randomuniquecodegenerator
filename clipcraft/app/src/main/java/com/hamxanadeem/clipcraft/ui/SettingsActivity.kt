package com.hamxanadeem.clipcraft.ui

import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.AutoCompleteTextView
import android.widget.EditText
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.materialswitch.MaterialSwitch
import com.google.android.material.slider.Slider
import com.hamxanadeem.clipcraft.R
import com.hamxanadeem.clipcraft.data.Languages
import com.hamxanadeem.clipcraft.data.Settings

/** API key, spoken language, number of clips, captions, YouTube privacy. */
class SettingsActivity : AppCompatActivity() {

    private val privacies = listOf("private", "unlisted", "public")
    private val privacyLabels = listOf(R.string.privacy_private, R.string.privacy_unlisted, R.string.privacy_public)

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)
        Ui.fitSystemBars(findViewById(R.id.root))
        findViewById<MaterialToolbar>(R.id.toolbar).setNavigationOnClickListener { finish() }
        findViewById<EditText>(R.id.api_key).setText(Settings.apiKey(this))
        findViewById<EditText>(R.id.notes).setText(Settings.notes(this))
        val lang = findViewById<AutoCompleteTextView>(R.id.language)
        lang.setAdapter(ArrayAdapter(this, android.R.layout.simple_list_item_1, Languages.ALL.map { it.name }))
        lang.setText(Languages.get(Settings.language(this)).name, false)
        val priv = findViewById<AutoCompleteTextView>(R.id.privacy)
        val privLabels = privacyLabels.map { getString(it) }
        priv.setAdapter(ArrayAdapter(this, android.R.layout.simple_list_item_1, privLabels))
        priv.setText(privLabels[privacies.indexOf(Settings.privacy(this)).coerceAtLeast(0)], false)
        val count = findViewById<Slider>(R.id.count)
        count.value = Settings.clipCount(this).toFloat().coerceIn(1f, 10f)
        findViewById<MaterialSwitch>(R.id.captions).isChecked = Settings.captions(this)
        findViewById<MaterialSwitch>(R.id.hook).isChecked = Settings.hook(this)
    }

    override fun onPause() {
        super.onPause()
        Settings.setApiKey(this, findViewById<EditText>(R.id.api_key).text.toString())
        Settings.setNotes(this, findViewById<EditText>(R.id.notes).text.toString())
        val langName = findViewById<AutoCompleteTextView>(R.id.language).text.toString()
        Languages.ALL.firstOrNull { it.name == langName }?.let { Settings.setLanguage(this, it.code) }
        val privText = findViewById<AutoCompleteTextView>(R.id.privacy).text.toString()
        val pi = privacyLabels.indexOfFirst { getString(it) == privText }
        if (pi >= 0) Settings.setPrivacy(this, privacies[pi])
        Settings.setClipCount(this, findViewById<Slider>(R.id.count).value.toInt())
        Settings.setCaptions(this, findViewById<MaterialSwitch>(R.id.captions).isChecked)
        Settings.setHook(this, findViewById<MaterialSwitch>(R.id.hook).isChecked)
    }
}
