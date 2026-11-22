package com.hamxanadeem.scamradar.data

import android.content.Context
import androidx.core.content.edit
import com.hamxanadeem.scamradar.core.Check
import com.hamxanadeem.scamradar.core.History
import com.hamxanadeem.scamradar.core.Result
import java.io.File

/** Check history and settings, kept only on this phone. */
object Store {
    private const val FILE = "history.txt"
    private const val PREFS = "scamradar"
    private var cache: List<Check>? = null

    fun history(context: Context): List<Check> {
        cache?.let { return it }
        val f = File(context.applicationContext.filesDir, FILE)
        val list = if (f.exists()) runCatching { History.decode(f.readText()) }.getOrDefault(emptyList()) else emptyList()
        cache = list
        return list
    }

    fun record(context: Context, r: Result) {
        if (r.text.isBlank()) return
        val list = History.add(history(context), Check(System.currentTimeMillis(), r.verdict, r.score, r.type, r.text))
        save(context, list)
    }

    fun clear(context: Context) = save(context, emptyList())

    private fun save(context: Context, list: List<Check>) {
        cache = list
        val dir = context.applicationContext.filesDir
        val tmp = File(dir, "$FILE.tmp")
        tmp.writeText(History.encode(list))
        if (!tmp.renameTo(File(dir, FILE))) {
            File(dir, FILE).writeText(History.encode(list))
            tmp.delete()
        }
    }

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun urdu(context: Context) = prefs(context).getBoolean("urdu", false)

    fun setUrdu(context: Context, on: Boolean) = prefs(context).edit { putBoolean("urdu", on) }

    fun checks(context: Context) = prefs(context).getInt("checks", 0)

    fun countCheck(context: Context) = prefs(context).edit { putInt("checks", checks(context) + 1) }
}
