package com.hamxanadeem.spendwise.ui

import android.app.DatePickerDialog
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.net.Uri
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.button.MaterialButton
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.chip.Chip
import com.google.android.material.chip.ChipGroup
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.core.Defaults
import com.hamxanadeem.spendwise.core.Every
import com.hamxanadeem.spendwise.core.Kind
import com.hamxanadeem.spendwise.core.Receipt
import com.hamxanadeem.spendwise.core.Txn
import com.hamxanadeem.spendwise.data.Store
import java.time.LocalDate

/** Adds or edits one transaction. The category is guessed from the note and learns from your choices. */
class EditActivity : BaseActivity() {

    companion object {
        private const val EXTRA_ID = "id"
        private const val EXTRA_NOTE = "note"
        private const val EXTRA_DATE = "date"
        private const val EXTRA_KIND = "kind"

        fun intent(context: Context, id: String? = null, note: String? = null, date: LocalDate? = null, kind: Kind? = null): Intent =
            Intent(context, EditActivity::class.java)
                .putExtra(EXTRA_ID, id)
                .putExtra(EXTRA_NOTE, note)
                .putExtra(EXTRA_DATE, date?.toString())
                .putExtra(EXTRA_KIND, kind?.name)
    }

    private var original: Txn? = null
    private var kind = Kind.EXPENSE
    private var date: LocalDate = LocalDate.now()
    private var categoryId: String? = null
    private var pickedByHand = false
    private var repeat: Every? = null
    private var repeatTouched = false
    private var settingChips = false
    private val chipCategory = mutableMapOf<Int, String>()

    private lateinit var amount: EditText
    private lateinit var note: EditText
    private lateinit var chips: ChipGroup
    private lateinit var suggestion: TextView
    private lateinit var dateButton: MaterialButton
    private lateinit var repeatButton: MaterialButton
    private var photo: Uri? = null

    private val takePhoto = registerForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val uri = photo
        if (ok && uri != null) readReceipt(uri)
    }
    private val pickImage = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) readReceipt(uri)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_edit)
        Ui.fitSystemBars(findViewById(R.id.root))
        val l = Store.ledger(this)
        original = intent.getStringExtra(EXTRA_ID)?.let { l.txn(it) }
        val o = original

        val toolbar = findViewById<MaterialToolbar>(R.id.toolbar)
        toolbar.setTitle(if (o == null) R.string.add_title else R.string.edit_title)
        toolbar.setNavigationOnClickListener { finish() }
        toolbar.menu.findItem(R.id.action_delete).isVisible = o != null
        toolbar.setOnMenuItemClickListener {
            when (it.itemId) {
                R.id.action_delete -> confirmDelete()
                R.id.action_scan -> scan()
            }
            true
        }

        amount = findViewById(R.id.amount)
        note = findViewById(R.id.note)
        chips = findViewById(R.id.categories)
        suggestion = findViewById(R.id.suggestion)
        dateButton = findViewById(R.id.date)
        repeatButton = findViewById(R.id.repeat)
        findViewById<TextView>(R.id.currency).text = Store.currency(this).let { code ->
            runCatching { java.util.Currency.getInstance(code).symbol }.getOrDefault(code)
        }

        if (o != null) {
            kind = o.kind
            date = o.date
            categoryId = o.categoryId
            pickedByHand = true
            amount.setText(Ui.plain(this, o.amount))
            note.setText(o.note)
            repeat = o.recurringId?.let { id -> l.recurring.firstOrNull { it.id == id }?.every }
        } else {
            intent.getStringExtra(EXTRA_KIND)?.let { kind = Kind.valueOf(it) }
            intent.getStringExtra(EXTRA_DATE)?.let { date = LocalDate.parse(it) }
            intent.getStringExtra(EXTRA_NOTE)?.let { note.setText(it) }
        }
        if (savedInstanceState != null) {
            kind = Kind.valueOf(savedInstanceState.getString("kind", kind.name))
            date = LocalDate.parse(savedInstanceState.getString("date", date.toString()))
            categoryId = savedInstanceState.getString("category") ?: categoryId
            pickedByHand = savedInstanceState.getBoolean("picked", pickedByHand)
            repeat = savedInstanceState.getString("repeat")?.let { Every.valueOf(it) }
            repeatTouched = savedInstanceState.getBoolean("repeatTouched", false)
            photo = savedInstanceState.getString("photo")?.let { Uri.parse(it) }
        }

        val toggle = findViewById<MaterialButtonToggleGroup>(R.id.type)
        toggle.check(if (kind == Kind.INCOME) R.id.type_income else R.id.type_expense)
        toggle.addOnButtonCheckedListener { _, id, checked ->
            if (!checked) return@addOnButtonCheckedListener
            val k = if (id == R.id.type_income) Kind.INCOME else Kind.EXPENSE
            if (k != kind) {
                kind = k
                categoryId = null
                pickedByHand = false
                buildChips()
                suggest()
            }
        }
        note.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) = suggest()
        })
        dateButton.setOnClickListener {
            DatePickerDialog(this, { _, y, m, d ->
                date = LocalDate.of(y, m + 1, d)
                showDate()
            }, date.year, date.monthValue - 1, date.dayOfMonth).apply {
                datePicker.maxDate = System.currentTimeMillis()
            }.show()
        }
        repeatButton.setOnClickListener { pickRepeat() }
        findViewById<View>(R.id.scan).setOnClickListener { scan() }
        findViewById<View>(R.id.save).setOnClickListener { save() }

        buildChips()
        suggest()
        showDate()
        showRepeat()
        if (o == null && savedInstanceState == null) {
            amount.requestFocus()
            amount.post { getSystemService(InputMethodManager::class.java)?.showSoftInput(amount, InputMethodManager.SHOW_IMPLICIT) }
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString("kind", kind.name)
        outState.putString("date", date.toString())
        outState.putString("category", categoryId)
        outState.putBoolean("picked", pickedByHand)
        outState.putString("repeat", repeat?.name)
        outState.putBoolean("repeatTouched", repeatTouched)
        outState.putString("photo", photo?.toString())
    }

    private fun buildChips() {
        settingChips = true
        chips.removeAllViews()
        chipCategory.clear()
        for (c in Store.ledger(this).categoriesOf(kind)) {
            val chip = Chip(this).apply {
                id = View.generateViewId()
                text = getString(R.string.chip_label, Ui.emoji(c.icon), c.name)
                isCheckable = true
                isCheckedIconVisible = false
                chipStrokeWidth = Ui.dp(this@EditActivity, 1).toFloat()
                chipStrokeColor = ColorStateList.valueOf(c.color.toInt())
            }
            chipCategory[chip.id] = c.id
            chips.addView(chip)
            if (c.id == categoryId) chip.isChecked = true
        }
        settingChips = false
        chips.setOnCheckedStateChangeListener { _, ids ->
            if (settingChips) return@setOnCheckedStateChangeListener
            categoryId = ids.firstOrNull()?.let { chipCategory[it] }
            pickedByHand = categoryId != null
            suggestion.visibility = View.GONE
        }
    }

    private fun check(id: String?) {
        settingChips = true
        val chipId = chipCategory.entries.firstOrNull { it.value == id }?.key
        if (chipId != null) chips.check(chipId) else chips.clearCheck()
        settingChips = false
    }

    /** Guesses the category from the note, unless one was picked by hand. */
    private fun suggest() {
        if (pickedByHand) {
            suggestion.visibility = View.GONE
            return
        }
        val text = note.text.toString()
        val best = if (text.isBlank()) null else Store.categorizer(this).best(text, kind)
        categoryId = best
        check(best)
        val cat = best?.let { Store.ledger(this).category(it) }
        if (cat != null) {
            suggestion.text = getString(R.string.suggested, cat.name)
            suggestion.visibility = View.VISIBLE
        } else suggestion.visibility = View.GONE
    }

    private fun showDate() {
        dateButton.text = Ui.day(this, date)
    }

    private fun showRepeat() {
        repeatButton.text = getString(repeat?.let { InsightsPage.everyLabel(it) } ?: R.string.repeat_never)
    }

    private fun pickRepeat() {
        val options = arrayOf(getString(R.string.repeat_never), getString(R.string.weekly), getString(R.string.monthly), getString(R.string.yearly))
        val current = when (repeat) {
            null -> 0
            Every.WEEKLY -> 1
            Every.MONTHLY -> 2
            Every.YEARLY -> 3
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.repeat_title)
            .setSingleChoiceItems(options, current) { d, which ->
                repeat = when (which) {
                    1 -> Every.WEEKLY
                    2 -> Every.MONTHLY
                    3 -> Every.YEARLY
                    else -> null
                }
                repeatTouched = true
                showRepeat()
                d.dismiss()
            }
            .show()
    }

    private fun scan() {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.scan_title)
            .setItems(arrayOf(getString(R.string.scan_camera), getString(R.string.scan_gallery))) { _, which ->
                Lock.leavingOnPurpose = true
                if (which == 0) {
                    val uri = Store.receiptUri(this)
                    photo = uri
                    runCatching { takePhoto.launch(uri) }.onFailure { Ui.toast(this, getString(R.string.no_camera)) }
                } else {
                    runCatching { pickImage.launch("image/*") }.onFailure { Ui.toast(this, getString(R.string.no_gallery)) }
                }
            }
            .show()
    }

    /** Reads the receipt on the phone and fills in the total, date and shop. */
    private fun readReceipt(uri: Uri) {
        Ui.toast(this, getString(R.string.reading_receipt))
        val image = runCatching { InputImage.fromFilePath(this, uri) }.getOrElse {
            Ui.toast(this, getString(R.string.receipt_failed))
            return
        }
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(image)
            .addOnSuccessListener { result ->
                val lines = result.textBlocks.flatMap { b -> b.lines.map { it.text } }
                val guess = Receipt.read(lines, LocalDate.now(), Store.currency(this))
                if (guess.amount == null && guess.date == null && guess.merchant == null) {
                    Ui.toast(this, getString(R.string.receipt_nothing))
                    return@addOnSuccessListener
                }
                if (kind != Kind.EXPENSE) findViewById<MaterialButtonToggleGroup>(R.id.type).check(R.id.type_expense)
                guess.amount?.let { amount.setText(Ui.plain(this, it)) }
                guess.date?.let {
                    date = it
                    showDate()
                }
                if (guess.merchant != null && note.text.isBlank()) note.setText(guess.merchant)
                Ui.toast(this, getString(R.string.receipt_read))
            }
            .addOnFailureListener { Ui.toast(this, getString(R.string.receipt_failed)) }
            .addOnCompleteListener { recognizer.close() }
    }

    private fun save() {
        val value = Ui.amountOf(this, amount)
        if (value == null) {
            amount.error = getString(R.string.amount_needed)
            amount.requestFocus()
            return
        }
        val cat = categoryId ?: if (kind == Kind.INCOME) Defaults.FALLBACK_INCOME else Defaults.FALLBACK_EXPENSE
        val o = original
        var t = Txn(o?.id ?: Store.newId(), value, kind, cat, note.text.toString().trim(), date, o?.recurringId,
            o?.createdAt ?: System.currentTimeMillis())
        if (repeatTouched && repeat == null && t.recurringId != null) {
            Store.deleteRecurring(this, t.recurringId!!)
            t = t.copy(recurringId = null)
        }
        val alert = Saving.save(this, t, if (repeatTouched) repeat else null)
        if (alert != null) Ui.toast(this, alert)
        finish()
    }

    private fun confirmDelete() {
        val o = original ?: return
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.delete_title)
            .setMessage(if (o.recurringId != null) R.string.delete_body_repeating else R.string.delete_body)
            .setPositiveButton(R.string.delete) { _, _ ->
                Store.deleteTxn(this, o.id)
                finish()
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }
}
