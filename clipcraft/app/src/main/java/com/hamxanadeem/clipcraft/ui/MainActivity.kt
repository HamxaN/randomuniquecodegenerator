package com.hamxanadeem.clipcraft.ui

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
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
        findViewById<View>(R.id.settings_hint).setOnClickListener { startActivity(Intent(this, SettingsActivity::class.java)) }
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
            IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)?.let { start(it) }
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
        findViewById<TextView>(R.id.settings_hint).setText(if (Settings.aiReady(this)) R.string.ai_ready else R.string.ai_missing)
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
