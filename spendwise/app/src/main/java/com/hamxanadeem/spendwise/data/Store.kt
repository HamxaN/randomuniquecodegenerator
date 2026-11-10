package com.hamxanadeem.spendwise.data

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import androidx.core.content.edit
import com.hamxanadeem.spendwise.core.BudgetStatus
import com.hamxanadeem.spendwise.core.Budgets
import com.hamxanadeem.spendwise.core.Categorizer
import com.hamxanadeem.spendwise.core.Category
import com.hamxanadeem.spendwise.core.Csv
import com.hamxanadeem.spendwise.core.Every
import com.hamxanadeem.spendwise.core.Kind
import com.hamxanadeem.spendwise.core.Ledger
import com.hamxanadeem.spendwise.core.Recurring
import com.hamxanadeem.spendwise.core.Txn
import java.io.File
import java.time.LocalDate
import java.time.YearMonth
import java.util.Currency
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors

/**
 * The one ledger, kept in memory and saved to the app's private storage after
 * every change (on a background thread, written to a temp file then renamed so
 * a crash can never leave half a file). Screens listen for changes.
 */
object Store {

    private const val FILE = "ledger.txt"
    private const val PREFS = "spendwise"
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var ledger: Ledger? = null
    private var version = 0
    private var categorizer: Categorizer? = null
    private var categorizerVersion = -1
    private val listeners = mutableSetOf<() -> Unit>()

    fun ledger(context: Context): Ledger {
        ledger?.let { return it }
        val f = File(context.applicationContext.filesDir, FILE)
        val loaded = if (f.exists()) runCatching { Ledger.decode(f.readText()) }.getOrNull() else null
        val l = loaded ?: Ledger(currency = defaultCurrency())
        ledger = l
        return l
    }

    private fun defaultCurrency(): String =
        runCatching { Currency.getInstance(Locale.getDefault()).currencyCode }.getOrNull() ?: "USD"

    /** The learning categoriser, rebuilt only when the ledger has changed. */
    fun categorizer(context: Context): Categorizer {
        val c = categorizer
        if (c != null && categorizerVersion == version) return c
        return Categorizer(ledger(context)).also {
            categorizer = it
            categorizerVersion = version
        }
    }

    fun addListener(l: () -> Unit) {
        listeners += l
    }

    fun removeListener(l: () -> Unit) {
        listeners -= l
    }

    fun changed(context: Context) {
        version++
        val app = context.applicationContext
        val text = ledger(app).encode()
        io.execute {
            val f = File(app.filesDir, FILE)
            val tmp = File(app.filesDir, "$FILE.tmp")
            tmp.writeText(text)
            if (!tmp.renameTo(f)) {
                f.writeText(text)
                tmp.delete()
            }
        }
        main.post { listeners.toList().forEach { it() } }
    }

    fun newId(): String = UUID.randomUUID().toString().replace("-", "").take(16)

    fun currency(context: Context): String = ledger(context).currency

    fun setCurrency(context: Context, code: String) {
        ledger(context).currency = code
        changed(context)
    }

    /** Adds every repeating transaction that has fallen due. Returns how many were added. */
    fun postDue(context: Context): Int {
        val added = ledger(context).postDue(LocalDate.now(), System.currentTimeMillis(), ::newId)
        if (added.isNotEmpty()) changed(context)
        return added.size
    }

    /**
     * Saves a transaction. With [repeat], it also becomes (or updates) a repeating
     * rule starting on its date. Returns budget states before and after, for alerts.
     */
    fun saveTxn(context: Context, txn: Txn, repeat: Every?): Pair<BudgetStatus?, BudgetStatus?> {
        val l = ledger(context)
        val month = YearMonth.from(txn.date)
        val cat = l.category(txn.categoryId)
        val watch = cat != null && cat.kind == Kind.EXPENSE && cat.budget > 0 && month == YearMonth.now()
        val before = if (watch) Budgets.status(l, cat!!, month) else null
        var t = txn
        if (repeat != null) {
            val ruleId = txn.recurringId ?: newId()
            l.upsertRecurring(Recurring(ruleId, txn.amount, txn.kind, txn.categoryId, txn.note, txn.date, repeat, txn.date))
            t = txn.copy(recurringId = ruleId)
        }
        l.upsertTxn(t)
        val after = if (watch) Budgets.status(l, cat!!, month) else null
        changed(context)
        return before to after
    }

    fun deleteTxn(context: Context, id: String): Txn? {
        val l = ledger(context)
        val t = l.txn(id) ?: return null
        l.removeTxn(id)
        changed(context)
        return t
    }

    fun restoreTxn(context: Context, t: Txn) {
        ledger(context).upsertTxn(t)
        changed(context)
    }

    fun saveCategory(context: Context, c: Category) {
        ledger(context).upsertCategory(c)
        changed(context)
    }

    fun deleteCategory(context: Context, id: String, moveTo: String): Boolean {
        val ok = ledger(context).removeCategory(id, moveTo)
        if (ok) changed(context)
        return ok
    }

    fun deleteRecurring(context: Context, id: String) {
        val l = ledger(context)
        l.removeRecurring(id)
        // Past transactions stay; they just stop being linked to the rule.
        l.txns.replaceAll { if (it.recurringId == id) it.copy(recurringId = null) else it }
        changed(context)
    }

    fun backupText(context: Context): String = ledger(context).encode()

    /** Replaces everything with a backup. Returns false (and changes nothing) if it isn't one. */
    fun restore(context: Context, text: String): Boolean {
        val l = Ledger.decode(text) ?: return false
        ledger = l
        changed(context)
        return true
    }

    fun writeTo(context: Context, uri: Uri, text: String, done: (Boolean) -> Unit) {
        val app = context.applicationContext
        io.execute {
            val ok = runCatching {
                app.contentResolver.openOutputStream(uri, "wt")?.bufferedWriter()?.use { it.write(text) }
                    ?: error("Can't write")
            }.isSuccess
            main.post { done(ok) }
        }
    }

    fun readFrom(context: Context, uri: Uri, done: (String?) -> Unit) {
        val app = context.applicationContext
        io.execute {
            val text = runCatching {
                app.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
            }.getOrNull()
            main.post { done(text) }
        }
    }

    /** Writes a CSV of every transaction to the share cache and returns a content URI. */
    fun exportCsv(context: Context): Uri {
        val app = context.applicationContext
        val dir = File(app.cacheDir, "exports").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }
        val file = File(dir, "spendwise-${LocalDate.now()}.csv")
        file.writeText(Csv.export(ledger(app)))
        return FileProvider.getUriForFile(app, "${app.packageName}.files", file)
    }

    /** A fresh file for the camera to write a receipt photo into. */
    fun receiptUri(context: Context): Uri {
        val app = context.applicationContext
        val dir = File(app.cacheDir, "receipts").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }
        val file = File(dir, "receipt-${System.currentTimeMillis()}.jpg")
        return FileProvider.getUriForFile(app, "${app.packageName}.files", file)
    }

    // Settings.

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun lockEnabled(context: Context) = prefs(context).getBoolean("lock", false)

    fun setLockEnabled(context: Context, on: Boolean) = prefs(context).edit { putBoolean("lock", on) }

    fun alertsEnabled(context: Context) = prefs(context).getBoolean("alerts", true)

    fun setAlertsEnabled(context: Context, on: Boolean) = prefs(context).edit { putBoolean("alerts", on) }

    fun onboarded(context: Context) = prefs(context).getBoolean("onboarded", false)

    fun setOnboarded(context: Context) = prefs(context).edit { putBoolean("onboarded", true) }
}
