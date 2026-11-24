package com.hamxanadeem.clipcraft.ui

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.RadioGroup
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.appbar.MaterialToolbar
import com.hamxanadeem.clipcraft.R
import com.hamxanadeem.clipcraft.core.AdvisorException
import com.hamxanadeem.clipcraft.core.Transcript
import com.hamxanadeem.clipcraft.core.Word
import com.hamxanadeem.clipcraft.data.Settings
import com.hamxanadeem.clipcraft.work.Engine
import java.util.concurrent.Executors

/**
 * Each user picks how clips are found: Claude with their own key, Claude through a
 * ClipCraft server, or no Claude at all (everything stays on the phone).
 */
class AiActivity : AppCompatActivity() {

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private lateinit var mode: RadioGroup

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_ai)
        Ui.fitSystemBars(findViewById(R.id.root))
        findViewById<MaterialToolbar>(R.id.toolbar).setNavigationOnClickListener { finish() }
        findViewById<EditText>(R.id.api_key).setText(Settings.apiKey(this))
        findViewById<EditText>(R.id.server_url).setText(Settings.serverUrl(this))
        findViewById<EditText>(R.id.server_token).setText(Settings.serverToken(this))
        findViewById<EditText>(R.id.notes).setText(Settings.notes(this))
        mode = findViewById(R.id.mode)
        mode.check(when (Settings.aiMode(this)) {
            Settings.AI_KEY -> R.id.mode_key
            Settings.AI_SERVER -> R.id.mode_server
            else -> R.id.mode_off
        })
        mode.setOnCheckedChangeListener { _, _ ->
            findViewById<TextView>(R.id.test_result).text = ""
            show()
        }
        show()
        findViewById<Button>(R.id.test).setOnClickListener { test() }
    }

    override fun onPause() {
        super.onPause()
        save()
    }

    override fun onDestroy() {
        io.shutdownNow()
        super.onDestroy()
    }

    private fun selected(): String = when (mode.checkedRadioButtonId) {
        R.id.mode_key -> Settings.AI_KEY
        R.id.mode_server -> Settings.AI_SERVER
        else -> Settings.AI_OFF
    }

    private fun show() {
        val m = selected()
        findViewById<View>(R.id.key_box).visibility = if (m == Settings.AI_KEY) View.VISIBLE else View.GONE
        findViewById<View>(R.id.server_box).visibility = if (m == Settings.AI_SERVER) View.VISIBLE else View.GONE
        findViewById<View>(R.id.claude_box).visibility = if (m == Settings.AI_OFF) View.GONE else View.VISIBLE
        findViewById<TextView>(R.id.mode_info).setText(when (m) {
            Settings.AI_KEY -> R.string.mode_key_info
            Settings.AI_SERVER -> R.string.mode_server_info
            else -> R.string.mode_off_info
        })
    }

    private fun save() {
        Settings.setAiMode(this, selected())
        Settings.setApiKey(this, findViewById<EditText>(R.id.api_key).text.toString())
        Settings.setServerUrl(this, findViewById<EditText>(R.id.server_url).text.toString())
        Settings.setServerToken(this, findViewById<EditText>(R.id.server_token).text.toString())
        Settings.setNotes(this, findViewById<EditText>(R.id.notes).text.toString())
    }

    /** Asks Claude for one clip from a tiny made-up transcript, to prove the key or server works. */
    private fun test() {
        save()
        val result = findViewById<TextView>(R.id.test_result)
        val button = findViewById<Button>(R.id.test)
        val source = Engine.source(this) ?: run {
            result.setText(R.string.test_missing)
            return
        }
        button.isEnabled = false
        result.setText(R.string.test_running)
        val sample = "so here is the one thing nobody tells you about starting out you will fail a lot " +
            "and that is exactly how you get good keep going"
        val words = sample.split(" ").mapIndexed { i, w -> Word(w, 1.0 + i * 0.4, 1.3 + i * 0.4) }
        io.execute {
            val msg = try {
                source.suggest(Transcript(words), 1, "", FloatArray(0))
                getString(R.string.test_ok)
            } catch (e: AdvisorException) {
                getString(R.string.test_failed, e.message ?: "")
            } catch (e: Exception) {
                getString(R.string.test_failed, e.message ?: e.javaClass.simpleName)
            }
            main.post {
                if (isDestroyed) return@post
                button.isEnabled = true
                result.text = msg
            }
        }
    }
}
