package com.hamxanadeem.clipcraft.ui

import android.Manifest
import android.content.ClipboardManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.text.InputType
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.IntentCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.hamxanadeem.clipcraft.R
import com.hamxanadeem.clipcraft.core.Links
import com.hamxanadeem.clipcraft.core.Project
import com.hamxanadeem.clipcraft.data.ProjectStore
import com.hamxanadeem.clipcraft.data.Settings
import com.hamxanadeem.clipcraft.work.Engine

/** Your saved projects, and a button to start a new one (or share a video to the app). */
class MainActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_PROJECT = "project"
    }

    private var projects: List<Project> = emptyList()
    private val refresh: () -> Unit = { reload() }

    private val pick = registerForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) start(uri)
    }

    private val askNotify = registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    private val adapter = object : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
        override fun getItemCount() = projects.size
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            object : RecyclerView.ViewHolder(LayoutInflater.from(parent.context).inflate(R.layout.item_project, parent, false)) {}

        override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
            val p = projects[position]
            holder.itemView.findViewById<TextView>(R.id.name).text = p.name
            holder.itemView.findViewById<TextView>(R.id.detail).text = detail(p)
            holder.itemView.setOnClickListener { open(p.id) }
            holder.itemView.setOnLongClickListener {
                confirmDelete(p)
                true
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        Engine.init(this)
        setContentView(R.layout.activity_main)
        Ui.fitSystemBars(findViewById(R.id.root))
        findViewById<MaterialToolbar>(R.id.toolbar).setOnMenuItemClickListener {
            if (it.itemId == R.id.action_settings) startActivity(Intent(this, SettingsActivity::class.java))
            true
        }
        val list = findViewById<RecyclerView>(R.id.projects)
        list.layoutManager = LinearLayoutManager(this)
        list.adapter = adapter
        findViewById<View>(R.id.pick).setOnClickListener {
            pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly))
        }
        findViewById<View>(R.id.link).setOnClickListener { askLink() }
        findViewById<View>(R.id.settings_hint).setOnClickListener { startActivity(Intent(this, AiActivity::class.java)) }
        if (Build.VERSION.SDK_INT >= 33) askNotify.launch(Manifest.permission.POST_NOTIFICATIONS)
        if (savedInstanceState == null) handle(intent)
        resumeUnfinished()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND) {
            val stream = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
            if (stream != null) {
                start(stream)
            } else {
                // A link shared from the browser or another app.
                intent.getStringExtra(Intent.EXTRA_TEXT)?.let { askLink(it) }
            }
        }
        intent?.getStringExtra(EXTRA_PROJECT)?.let { open(it) }
    }

    /** Projects whose work stopped (the phone restarted or the app was closed) carry on. */
    private fun resumeUnfinished() {
        for (p in ProjectStore.all(this)) {
            if ((p.status == Project.NEW || p.status == Project.WORKING) && !Engine.busy(p.id)) Engine.analyze(p.id)
        }
    }

    override fun onResume() {
        super.onResume()
        Engine.listen(refresh)
        reload()
        findViewById<TextView>(R.id.settings_hint).setText(when {
            Settings.aiReady(this) -> R.string.ai_ready
            Settings.aiMode(this) == Settings.AI_OFF -> R.string.ai_off_hint
            else -> R.string.ai_missing
        })
    }

    override fun onPause() {
        Engine.unlisten(refresh)
        super.onPause()
    }

    private fun reload() {
        projects = ProjectStore.all(this)
        @Suppress("NotifyDataSetChanged")
        adapter.notifyDataSetChanged()
        findViewById<View>(R.id.empty).visibility = if (projects.isEmpty()) View.VISIBLE else View.GONE
    }

    private fun detail(p: Project): String {
        Engine.projectProgress(p.id)?.let { return it }
        val made = p.clips.count { Engine.rendered(it) }
        val posted = p.clips.count { it.youtubeId != null }
        return when (p.status) {
            Project.READY -> getString(R.string.project_summary, p.clips.size, made, posted)
            Project.ERROR -> p.message
            else -> getString(R.string.waiting)
        }
    }

    private fun start(uri: Uri) {
        val p = ProjectStore.create(this, uri, Settings.language(this))
        Engine.analyze(p.id)
        open(p.id)
    }

    /** Paste (or confirm a shared) link to a video file. */
    private fun askLink(prefill: String? = null) {
        val field = EditText(this).apply {
            hint = getString(R.string.link_hint)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO
            minHeight = Ui.dp(this@MainActivity, 48)
            val clip = getSystemService(ClipboardManager::class.java)?.primaryClip?.takeIf { it.itemCount > 0 }
                ?.getItemAt(0)?.coerceToText(this@MainActivity)?.toString()
            setText(prefill ?: clip?.let { Links.find(it) } ?: "")
        }
        val box = FrameLayout(this).apply {
            val pad = Ui.dp(this@MainActivity, 20)
            setPadding(pad, Ui.dp(this@MainActivity, 8), pad, 0)
            addView(field)
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.link_title)
            .setMessage(R.string.link_body)
            .setView(box)
            .setPositiveButton(R.string.link_go) { _, _ -> startLink(field.text.toString()) }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun startLink(text: String) {
        when (val r = Links.resolve(text, Settings.allowPlatformLinks(this))) {
            is Links.Result.Refused -> MaterialAlertDialogBuilder(this)
                .setTitle(R.string.link_refused_title)
                .setMessage(r.reason + "\n\n" + getString(R.string.platform_links_hint))
                .setPositiveButton(R.string.ok, null)
                .show()
            is Links.Result.Download -> {
                val p = ProjectStore.create(this, Uri.parse(r.url), Settings.language(this), getString(R.string.link_project_name, r.name.take(40)))
                Engine.analyze(p.id)
                open(p.id)
            }
            is Links.Result.Platform -> {
                val p = ProjectStore.create(this, Uri.parse(r.url), Settings.language(this),
                    getString(R.string.platform_project_name, r.site), origin = r.site)
                Engine.analyze(p.id)
                open(p.id)
            }
        }
    }

    private fun open(id: String) {
        startActivity(Intent(this, ProjectActivity::class.java).putExtra(EXTRA_PROJECT, id))
    }

    private fun confirmDelete(p: Project) {
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.delete_project)
            .setMessage(getString(R.string.delete_project_body, p.name))
            .setPositiveButton(R.string.delete) { _, _ ->
                if (Engine.busy(p.id)) {
                    Ui.toast(this, getString(R.string.busy_cant_delete))
                } else {
                    Engine.forget(p.id)
                    ProjectStore.delete(this, p.id)
                    reload()
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }
}
