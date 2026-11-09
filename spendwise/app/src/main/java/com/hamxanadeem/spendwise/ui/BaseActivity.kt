package com.hamxanadeem.spendwise.ui

import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import com.google.android.material.button.MaterialButton
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.data.Store

/** Every screen: edge to edge, and covered by the app lock until unlocked. */
abstract class BaseActivity : AppCompatActivity() {

    private var cover: View? = null
    private var prompting = false

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun onStart() {
        super.onStart()
        Lock.started++
    }

    override fun onResume() {
        super.onResume()
        Lock.leavingOnPurpose = false
        val lockOn = Store.lockEnabled(this)
        // Keep money off the recent-apps preview and screenshots while the lock is on.
        if (lockOn) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        if (lockOn && Lock.locked && Lock.available(this)) {
            showCover()
            ask()
        } else {
            Lock.locked = false
            hideCover()
        }
    }

    override fun onStop() {
        super.onStop()
        Lock.started--
        if (Lock.started <= 0 && !isChangingConfigurations && !Lock.leavingOnPurpose) Lock.locked = true
    }

    private fun showCover() {
        if (cover != null) return
        val root = findViewById<ViewGroup>(android.R.id.content)
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(ContextCompat.getColor(this@BaseActivity, R.color.surface))
            isClickable = true
            addView(TextView(this@BaseActivity).apply {
                text = getString(R.string.locked)
                textSize = 20f
                gravity = Gravity.CENTER
                setTextColor(ContextCompat.getColor(this@BaseActivity, R.color.ink))
            })
            addView(MaterialButton(this@BaseActivity).apply {
                text = getString(R.string.unlock)
                setOnClickListener { ask() }
            }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = Ui.dp(this@BaseActivity, 16)
            })
        }
        root.addView(box, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        cover = box
    }

    private fun hideCover() {
        cover?.let { (it.parent as? ViewGroup)?.removeView(it) }
        cover = null
    }

    private fun ask() {
        if (prompting) return
        prompting = true
        val prompt = BiometricPrompt(this, ContextCompat.getMainExecutor(this), object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                prompting = false
                Lock.locked = false
                hideCover()
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                prompting = false
            }
        })
        prompt.authenticate(
            BiometricPrompt.PromptInfo.Builder()
                .setTitle(getString(R.string.unlock_title))
                .setSubtitle(getString(R.string.unlock_subtitle))
                .setAllowedAuthenticators(Lock.AUTHENTICATORS)
                .build()
        )
    }
}
