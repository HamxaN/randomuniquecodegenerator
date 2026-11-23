package com.hamxanadeem.clipcraft.ui

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.IntentCompat
import com.google.android.material.appbar.MaterialToolbar
import android.widget.TextView
import com.hamxanadeem.clipcraft.R
import com.hamxanadeem.clipcraft.data.Settings

/** Pick a video (or share one to the app) to start. */
class MainActivity : AppCompatActivity() {

    private val pick = registerForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) open(uri)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        Ui.fitSystemBars(findViewById(R.id.root))
        findViewById<MaterialToolbar>(R.id.toolbar).setOnMenuItemClickListener {
            if (it.itemId == R.id.action_settings) startActivity(Intent(this, SettingsActivity::class.java))
            true
        }
        findViewById<View>(R.id.pick).setOnClickListener {
            pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly))
        }
        findViewById<View>(R.id.settings_hint).setOnClickListener { startActivity(Intent(this, SettingsActivity::class.java)) }
        if (savedInstanceState == null && intent?.action == Intent.ACTION_SEND) {
            IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)?.let { open(it) }
        }
    }

    override fun onResume() {
        super.onResume()
        val hasKey = Settings.apiKey(this).isNotBlank()
        findViewById<TextView>(R.id.settings_hint).setText(if (hasKey) R.string.ai_ready else R.string.ai_missing)
    }

    private fun open(uri: Uri) {
        startActivity(Intent(this, ProjectActivity::class.java).setData(uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
    }
}
