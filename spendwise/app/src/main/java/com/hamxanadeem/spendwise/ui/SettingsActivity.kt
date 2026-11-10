package com.hamxanadeem.spendwise.ui

import android.Manifest
import android.content.ClipData
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.EditText
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.materialswitch.MaterialSwitch
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.data.Store
import java.time.LocalDate
import java.util.Currency
import java.util.Locale

/** Currency, categories, repeating payments, app lock, alerts, export and backup. */
class SettingsActivity : BaseActivity() {

    private val saveBackup = registerForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri ->
        if (uri != null) Store.writeTo(this, uri, Store.backupText(this)) { ok ->
            Ui.toast(this, getString(if (ok) R.string.backup_done else R.string.backup_failed))
        }
    }
    private val openBackup = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) Store.readFrom(this, uri) { text -> confirmRestore(text) }
    }
    private val askNotifications = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (!granted) {
            Store.setAlertsEnabled(this, false)
            Ui.toast(this, getString(R.string.alerts_denied))
            refresh()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)
        Ui.fitSystemBars(findViewById(R.id.root))
        findViewById<MaterialToolbar>(R.id.toolbar).setNavigationOnClickListener { finish() }

        findViewById<View>(R.id.row_currency).setOnClickListener { pickCurrency() }
        findViewById<View>(R.id.row_categories).setOnClickListener { startActivity(Intent(this, CategoriesActivity::class.java)) }
        findViewById<View>(R.id.row_recurring).setOnClickListener { startActivity(Intent(this, RecurringActivity::class.java)) }
        findViewById<View>(R.id.row_export).setOnClickListener { exportCsv() }
        findViewById<View>(R.id.row_backup).setOnClickListener {
            Lock.leavingOnPurpose = true
            saveBackup.launch("spendwise-backup-${LocalDate.now()}.txt")
        }
        findViewById<View>(R.id.row_restore).setOnClickListener {
            Lock.leavingOnPurpose = true
            openBackup.launch(arrayOf("text/plain", "application/octet-stream"))
        }

        val lock = findViewById<MaterialSwitch>(R.id.lock)
        lock.setOnCheckedChangeListener { b, on ->
            if (!b.isPressed) return@setOnCheckedChangeListener
            if (on && !Lock.available(this)) {
                b.isChecked = false
                Ui.toast(this, getString(R.string.lock_unavailable))
                return@setOnCheckedChangeListener
            }
            Store.setLockEnabled(this, on)
            Lock.locked = false
            refresh()
        }
        val alerts = findViewById<MaterialSwitch>(R.id.alerts)
        alerts.setOnCheckedChangeListener { b, on ->
            if (!b.isPressed) return@setOnCheckedChangeListener
            Store.setAlertsEnabled(this, on)
            if (on && Build.VERSION.SDK_INT >= 33) askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
        findViewById<View>(R.id.row_lock).setOnClickListener { lock.isPressed = true; lock.toggle(); lock.isPressed = false }
        findViewById<View>(R.id.row_alerts).setOnClickListener { alerts.isPressed = true; alerts.toggle(); alerts.isPressed = false }
        findViewById<TextView>(R.id.version).text = getString(R.string.version_line,
            packageManager.getPackageInfo(packageName, 0).versionName ?: "")
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    private fun refresh() {
        val code = Store.currency(this)
        val cur = runCatching { Currency.getInstance(code) }.getOrNull()
        findViewById<TextView>(R.id.currency_value).text = if (cur != null) "${cur.getDisplayName(Locale.getDefault())} ($code)" else code
        findViewById<MaterialSwitch>(R.id.lock).isChecked = Store.lockEnabled(this)
        findViewById<MaterialSwitch>(R.id.alerts).isChecked = Store.alertsEnabled(this)
        val l = Store.ledger(this)
        findViewById<TextView>(R.id.categories_value).text = resources.getQuantityString(R.plurals.category_count, l.categories.size, l.categories.size)
        findViewById<TextView>(R.id.recurring_value).text = resources.getQuantityString(R.plurals.rule_count, l.recurring.size, l.recurring.size)
        findViewById<TextView>(R.id.export_value).text = resources.getQuantityString(R.plurals.txn_count, l.txns.size, l.txns.size)
    }

    private fun pickCurrency() {
        val common = listOf("USD", "EUR", "GBP", "PKR", "INR", "AED", "SAR", "CAD", "AUD", "JPY", "CNY", "BDT", "TRY", "NGN",
            "ZAR", "MYR", "IDR", "PHP", "SGD", "CHF", "SEK", "BRL", "MXN", "EGP", "KES")
        val local = runCatching { Currency.getInstance(Locale.getDefault()).currencyCode }.getOrNull()
        val codes = (listOfNotNull(local, Store.currency(this)) + common).distinct()
        val labels = codes.map { c -> runCatching { "$c · ${Currency.getInstance(c).getDisplayName(Locale.getDefault())}" }.getOrDefault(c) } +
            getString(R.string.currency_other)
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.currency)
            .setItems(labels.toTypedArray()) { _, which ->
                if (which < codes.size) setCurrency(codes[which]) else customCurrency()
            }
            .show()
    }

    private fun customCurrency() {
        val input = EditText(this).apply {
            hint = getString(R.string.currency_code_hint)
            setSingleLine()
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.currency_other)
            .setView(Ui.padded(this, input))
            .setPositiveButton(R.string.save) { _, _ ->
                val code = input.text.toString().trim().uppercase(Locale.ROOT)
                if (runCatching { Currency.getInstance(code) }.isSuccess) setCurrency(code)
                else Ui.toast(this, getString(R.string.currency_invalid))
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun setCurrency(code: String) {
        Store.setCurrency(this, code)
        refresh()
    }

    private fun exportCsv() {
        val uri = runCatching { Store.exportCsv(this) }.getOrElse {
            Ui.toast(this, getString(R.string.export_failed))
            return
        }
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/csv"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, getString(R.string.export_subject))
            clipData = ClipData.newRawUri("spendwise.csv", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        Lock.leavingOnPurpose = true
        startActivity(Intent.createChooser(send, getString(R.string.export_csv)))
    }

    private fun confirmRestore(text: String?) {
        if (text == null || !text.startsWith("spendwise ")) {
            Ui.toast(this, getString(R.string.restore_invalid))
            return
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.restore_title)
            .setMessage(R.string.restore_body)
            .setPositiveButton(R.string.restore) { _, _ ->
                Ui.toast(this, getString(if (Store.restore(this, text)) R.string.restore_done else R.string.restore_invalid))
                refresh()
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }
}
