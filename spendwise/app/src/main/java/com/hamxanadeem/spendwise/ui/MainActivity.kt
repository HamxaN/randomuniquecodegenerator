package com.hamxanadeem.spendwise.ui

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.floatingactionbutton.FloatingActionButton
import com.google.android.material.snackbar.Snackbar
import com.hamxanadeem.spendwise.R
import com.hamxanadeem.spendwise.data.Store

/** A screen inside the main activity's tabs. */
interface Page {
    val view: View
    fun refresh()
}

class MainActivity : BaseActivity() {

    companion object {
        const val EXTRA_TAB = "tab"
    }

    private lateinit var pages: Map<Int, Page>
    private lateinit var nav: BottomNavigationView
    private lateinit var toolbar: MaterialToolbar
    private lateinit var fab: FloatingActionButton
    private var current = R.id.tab_home
    private val onChange: () -> Unit = { pages[current]?.refresh() }
    private val askNotifications = registerForActivityResult(ActivityResultContracts.RequestPermission()) {}

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        Ui.fitSystemBars(findViewById(R.id.root), bottom = false)
        toolbar = findViewById(R.id.toolbar)
        toolbar.setOnMenuItemClickListener {
            if (it.itemId == R.id.action_settings) startActivity(Intent(this, SettingsActivity::class.java))
            true
        }
        fab = findViewById(R.id.add)
        fab.setOnClickListener { startActivity(EditActivity.intent(this)) }

        val container = findViewById<FrameLayout>(R.id.pages)
        pages = mapOf(
            R.id.tab_home to HomePage(this),
            R.id.tab_activity to ActivityPage(this),
            R.id.tab_budgets to BudgetsPage(this),
            R.id.tab_insights to InsightsPage(this),
        )
        for (p in pages.values) {
            p.view.visibility = View.GONE
            container.addView(p.view, 0, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        }
        nav = findViewById(R.id.nav)
        nav.setOnItemSelectedListener {
            show(it.itemId)
            true
        }
        nav.selectedItemId = savedInstanceState?.getInt(EXTRA_TAB) ?: intent.getIntExtra(EXTRA_TAB, R.id.tab_home)
        show(nav.selectedItemId)

        Store.addListener(onChange)
        val added = Store.postDue(this)
        if (added > 0) Ui.toast(this, resources.getQuantityString(R.plurals.recurring_added, added, added))
        if (!Store.onboarded(this)) welcome()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val tab = intent.getIntExtra(EXTRA_TAB, 0)
        if (tab != 0) nav.selectedItemId = tab
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt(EXTRA_TAB, current)
    }

    override fun onResume() {
        super.onResume()
        // The date may have changed since the app was last open.
        if (Store.postDue(this) == 0) pages[current]?.refresh()
    }

    override fun onDestroy() {
        Store.removeListener(onChange)
        super.onDestroy()
    }

    fun select(tab: Int) {
        nav.selectedItemId = tab
    }

    private fun show(tab: Int) {
        current = if (pages.containsKey(tab)) tab else R.id.tab_home
        for ((id, p) in pages) p.view.visibility = if (id == current) View.VISIBLE else View.GONE
        toolbar.title = getString(
            when (current) {
                R.id.tab_activity -> R.string.tab_activity
                R.id.tab_budgets -> R.string.tab_budgets
                R.id.tab_insights -> R.string.tab_insights
                else -> R.string.app_name
            }
        )
        pages[current]?.refresh()
    }

    /** A short message above the add button, with an optional action. */
    fun snack(text: String, action: String? = null, onAction: () -> Unit = {}) {
        val s = Snackbar.make(findViewById(R.id.pages), text, Snackbar.LENGTH_LONG).setAnchorView(fab)
        if (action != null) s.setAction(action) { onAction() }
        s.show()
    }

    private fun welcome() {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.welcome_title)
            .setMessage(R.string.welcome_body)
            .setCancelable(false)
            .setPositiveButton(R.string.welcome_go) { _, _ ->
                Store.setOnboarded(this)
                if (Build.VERSION.SDK_INT >= 33) askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
            .show()
    }
}
