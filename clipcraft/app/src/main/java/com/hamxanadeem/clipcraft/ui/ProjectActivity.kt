package com.hamxanadeem.clipcraft.ui

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.OptIn
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.FileProvider
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.progressindicator.LinearProgressIndicator
import com.hamxanadeem.clipcraft.R
import com.hamxanadeem.clipcraft.core.AdvisorException
import com.hamxanadeem.clipcraft.core.Captions
import com.hamxanadeem.clipcraft.core.ClipAdvisor
import com.hamxanadeem.clipcraft.core.ClipPlan
import com.hamxanadeem.clipcraft.core.Copyright
import com.hamxanadeem.clipcraft.core.Heuristic
import com.hamxanadeem.clipcraft.core.Transcript
import com.hamxanadeem.clipcraft.core.YouTube
import com.hamxanadeem.clipcraft.data.Languages
import com.hamxanadeem.clipcraft.data.Settings
import com.hamxanadeem.clipcraft.media.ClipRenderer
import com.hamxanadeem.clipcraft.media.Gallery
import com.hamxanadeem.clipcraft.media.Speech
import com.hamxanadeem.clipcraft.media.Style
import com.hamxanadeem.clipcraft.youtube.Uploader
import com.hamxanadeem.clipcraft.youtube.YouTubeAuth
import java.io.File
import java.util.concurrent.Executors

/**
 * One video: transcribe it on the phone, ask the AI for the best moments, then
 * preview, render, save, share or upload each clip.
 */
@OptIn(UnstableApi::class)
class ProjectActivity : AppCompatActivity() {

    private lateinit var video: Uri
    private lateinit var player: ExoPlayer
    private lateinit var status: TextView
    private lateinit var progress: LinearProgressIndicator
    private lateinit var list: RecyclerView
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var transcript: Transcript? = null
    private var loudness: FloatArray = FloatArray(0)
    private var clips: List<ClipPlan> = emptyList()
    private val rendered = mutableMapOf<Int, File>()
    private val busy = mutableSetOf<Int>()
    private val clipProgress = mutableMapOf<Int, String>()
    private var renderer: ClipRenderer? = null
    private var pendingUpload: Int = -1
    private var aiUsed = false

    private val consent = registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { r ->
        YouTubeAuth.fromConsent(this, r.data, { token -> upload(pendingUpload, token) }, { msg -> Ui.toast(this, msg) })
    }

    private val adapter = object : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
        override fun getItemCount() = clips.size
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            object : RecyclerView.ViewHolder(LayoutInflater.from(parent.context).inflate(R.layout.item_clip, parent, false)) {}

        override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) = bind(holder.itemView, position)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_project)
        Ui.fitSystemBars(findViewById(R.id.root))
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        video = intent.data ?: run {
            finish()
            return
        }
        val toolbar = findViewById<MaterialToolbar>(R.id.toolbar)
        toolbar.setNavigationOnClickListener { finish() }
        toolbar.setOnMenuItemClickListener {
            if (it.itemId == R.id.action_again) findClips()
            true
        }
        status = findViewById(R.id.status)
        progress = findViewById(R.id.progress)
        list = findViewById(R.id.clips)
        list.layoutManager = LinearLayoutManager(this)
        list.adapter = adapter
        player = ExoPlayer.Builder(this).build()
        findViewById<PlayerView>(R.id.player).player = player
        player.setMediaItem(MediaItem.fromUri(video))
        player.prepare()
        start()
    }

    override fun onDestroy() {
        renderer?.cancel()
        player.release()
        io.shutdownNow()
        super.onDestroy()
    }

    private fun setStatus(text: String, value: Float? = null) {
        status.text = text
        if (value == null) {
            progress.isIndeterminate = true
        } else {
            progress.isIndeterminate = false
            progress.setProgressCompat((value * 100).toInt(), true)
        }
        progress.visibility = View.VISIBLE
    }

    private fun done(text: String) {
        status.text = text
        progress.visibility = View.GONE
    }

    private fun cacheFile(): File = File(cacheDir, "transcripts/${video.toString().hashCode()}_${Settings.language(this)}.json")

    private fun loudnessFile(): File = File(cacheDir, "transcripts/${video.toString().hashCode()}.loud")

    /** Step 1: transcribe (downloading the speech model first if needed). */
    private fun start() {
        val model = Languages.get(Settings.language(this))
        io.execute {
            try {
                var t = Speech.load(cacheFile())
                var loud = Speech.loadLoudness(loudnessFile())
                if (t == null || loud == null) {
                    if (!Speech.hasModel(this, model)) {
                        Speech.download(this, model) { p -> main.post { setStatus(getString(R.string.downloading_model, model.name, model.sizeMb), p) } }
                    }
                    main.post { setStatus(getString(R.string.transcribing), 0f) }
                    val r = Speech.transcribe(this, video, model) { p -> main.post { setStatus(getString(R.string.transcribing), p) } }
                    t = r.transcript
                    loud = r.loudness
                    Speech.save(cacheFile(), t)
                    Speech.saveLoudness(loudnessFile(), loud)
                }
                transcript = t
                loudness = loud
                main.post { findClips() }
            } catch (e: Exception) {
                main.post { done(getString(R.string.transcribe_failed, e.message ?: "")) }
            }
        }
    }

    /** Step 2: the AI (or the offline picker) chooses the clips. */
    private fun findClips() {
        val t = transcript ?: return
        val key = Settings.apiKey(this)
        val count = Settings.clipCount(this)
        val notes = Settings.notes(this)
        setStatus(getString(if (key.isNotBlank()) R.string.ai_thinking else R.string.finding_offline))
        io.execute {
            var note: String? = null
            val picked = if (key.isNotBlank()) {
                try {
                    aiUsed = true
                    ClipAdvisor(key).suggest(t, count, notes)
                } catch (e: AdvisorException) {
                    aiUsed = false
                    note = e.message
                    Heuristic.pick(t, count)
                }
            } else {
                aiUsed = false
                Heuristic.pick(t, count)
            }
            main.post {
                clips = picked
                rendered.clear()
                @Suppress("NotifyDataSetChanged")
                adapter.notifyDataSetChanged()
                when {
                    picked.isEmpty() -> done(getString(R.string.no_clips))
                    note != null -> done(getString(R.string.ai_fallback, note))
                    aiUsed -> done(getString(R.string.ai_found, picked.size, t.words.size))
                    else -> done(getString(R.string.offline_found, picked.size))
                }
            }
        }
    }

    private fun bind(v: View, i: Int) {
        val c = clips[i]
        v.findViewById<TextView>(R.id.score).text = c.score.toString()
        v.findViewById<TextView>(R.id.title).text = c.title
        v.findViewById<TextView>(R.id.time).text = getString(R.string.clip_time,
            Transcript.format(c.start), Transcript.format(c.end), c.length.toInt())
        v.findViewById<TextView>(R.id.reason).text = c.reason
        v.findViewById<TextView>(R.id.tags).text = c.hashtags.joinToString(" ")
        val warn = musicWarning(c)
        v.findViewById<TextView>(R.id.music).apply {
            text = warn ?: ""
            visibility = if (warn == null) View.GONE else View.VISIBLE
        }
        val state = v.findViewById<TextView>(R.id.state)
        val file = rendered[i]
        state.text = clipProgress[i] ?: if (file != null) getString(R.string.ready) else ""
        state.visibility = if (state.text.isNullOrEmpty()) View.GONE else View.VISIBLE
        v.findViewById<Button>(R.id.preview).setOnClickListener { preview(c) }
        v.findViewById<Button>(R.id.edit).setOnClickListener { edit(i) }
        val make = v.findViewById<Button>(R.id.make)
        make.isEnabled = i !in busy
        make.setText(if (file == null) R.string.make_short else R.string.remake_short)
        make.setOnClickListener { render(i) }
        val after = v.findViewById<LinearLayout>(R.id.after)
        after.visibility = if (file != null) View.VISIBLE else View.GONE
        v.findViewById<Button>(R.id.save).setOnClickListener { save(i) }
        v.findViewById<Button>(R.id.share).setOnClickListener { share(i) }
        v.findViewById<Button>(R.id.upload).apply {
            isEnabled = i !in busy
            setOnClickListener { startUpload(i) }
        }
    }

    private fun preview(c: ClipPlan) {
        player.setMediaItem(
            MediaItem.Builder().setUri(video).setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs((c.start * 1000).toLong())
                    .setEndPositionMs((c.end * 1000).toLong())
                    .build()
            ).build()
        )
        player.prepare()
        player.play()
    }

    private fun edit(i: Int) {
        val c = clips[i]
        val view = LayoutInflater.from(this).inflate(R.layout.dialog_edit, null as ViewGroup?)
        val title = view.findViewById<EditText>(R.id.edit_title)
        val hook = view.findViewById<EditText>(R.id.edit_hook)
        val desc = view.findViewById<EditText>(R.id.edit_description)
        title.setText(c.title)
        hook.setText(c.hook)
        desc.setText(c.description)
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.edit_clip)
            .setView(view)
            .setPositiveButton(R.string.save_changes) { _, _ ->
                clips = clips.toMutableList().also {
                    it[i] = c.copy(title = title.text.toString().trim(), hook = hook.text.toString().trim(), description = desc.text.toString().trim())
                }
                rendered.remove(i)
                adapter.notifyItemChanged(i)
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    /** Step 3: make the vertical short. */
    private fun render(i: Int) {
        val t = transcript ?: return
        if (renderer != null) {
            Ui.toast(this, getString(R.string.one_at_a_time))
            return
        }
        val c = clips[i]
        busy += i
        clipProgress[i] = getString(R.string.rendering, 0)
        adapter.notifyItemChanged(i)
        val r = ClipRenderer(this)
        renderer = r
        val style = Style(Settings.captions(this), Settings.hook(this), Settings.captionColor(this))
        val out = File(cacheDir, "clips/clip_${System.currentTimeMillis()}.mp4")
        r.render(video, c, Captions.build(t, c.start, c.end), style, out,
            onProgress = { p ->
                clipProgress[i] = getString(R.string.rendering, p)
                adapter.notifyItemChanged(i)
            },
            onDone = { result ->
                renderer = null
                busy -= i
                clipProgress.remove(i)
                result.onSuccess { rendered[i] = it }
                    .onFailure { Ui.toast(this, getString(R.string.render_failed, it.message ?: "")) }
                adapter.notifyItemChanged(i)
            })
    }

    private fun save(i: Int) {
        val f = rendered[i] ?: return
        val uri = runCatching { Gallery.save(this, f, "clipcraft_${System.currentTimeMillis()}") }.getOrNull()
        Ui.toast(this, getString(if (uri != null) R.string.saved else R.string.save_failed))
    }

    private fun share(i: Int) {
        val f = rendered[i] ?: return
        val uri = FileProvider.getUriForFile(this, "$packageName.files", f)
        val c = clips[i]
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, c.title + "\n\n" + YouTube.description(c))
            clipData = ClipData.newRawUri("clip", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(send, getString(R.string.share)))
    }

    private fun musicWarning(c: ClipPlan): String? {
        val t = transcript ?: return null
        return Copyright.warning(Copyright.musicRisk(loudness, t, c.start, c.end))
    }

    /** Step 4: post it to the user's channel, after a quick copyright checklist. */
    private fun startUpload(i: Int) {
        if (rendered[i] == null) return
        val c = clips[i]
        val view = LayoutInflater.from(this).inflate(R.layout.dialog_upload, null as ViewGroup?)
        view.findViewById<TextView>(R.id.upload_summary).text =
            getString(R.string.upload_body, YouTube.title(c), getString(privacyLabel(Settings.privacy(this))))
        val warn = musicWarning(c)
        view.findViewById<TextView>(R.id.upload_music).apply {
            text = warn ?: getString(R.string.no_music_found)
            setTextColor(getColor(if (warn != null) R.color.brand else R.color.ink_soft))
        }
        val own = view.findViewById<CheckBox>(R.id.check_own)
        val music = view.findViewById<CheckBox>(R.id.check_music)
        val dialog = MaterialAlertDialogBuilder(this)
            .setTitle(R.string.upload_title)
            .setView(view)
            .setPositiveButton(R.string.upload) { _, _ ->
                pendingUpload = i
                YouTubeAuth.authorize(this, consent, { token -> upload(i, token) }, { msg -> Ui.toast(this, msg) })
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
        val go = dialog.getButton(android.content.DialogInterface.BUTTON_POSITIVE)
        val update = { go.isEnabled = own.isChecked && music.isChecked }
        update()
        own.setOnCheckedChangeListener { _, _ -> update() }
        music.setOnCheckedChangeListener { _, _ -> update() }
    }

    private fun privacyLabel(p: String) = when (p) {
        "public" -> R.string.privacy_public
        "unlisted" -> R.string.privacy_unlisted
        else -> R.string.privacy_private
    }

    private fun upload(i: Int, token: String) {
        val f = rendered[i] ?: return
        val c = clips[i]
        busy += i
        clipProgress[i] = getString(R.string.uploading, 0)
        adapter.notifyItemChanged(i)
        val meta = YouTube.metadata(c, Settings.privacy(this))
        io.execute {
            val result = runCatching {
                Uploader.upload(token, f, meta) { p ->
                    main.post {
                        clipProgress[i] = getString(R.string.uploading, (p * 100).toInt())
                        adapter.notifyItemChanged(i)
                    }
                }
            }
            main.post {
                busy -= i
                clipProgress.remove(i)
                adapter.notifyItemChanged(i)
                result.onSuccess { id -> uploaded(id, token) }
                    .onFailure { Ui.toast(this, it.message ?: getString(R.string.upload_failed)) }
            }
        }
    }

    private fun uploaded(id: String, token: String) {
        val url = "https://youtube.com/shorts/$id"
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.uploaded_title)
            .setMessage(getString(R.string.uploaded_body, url))
            .setPositiveButton(R.string.open_youtube) { _, _ -> startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
            .setNegativeButton(R.string.close, null)
            .show()
        watch(id, token, url)
    }

    /** Asks YouTube every 20 s (for up to 5 minutes) whether it accepted or rejected the video. */
    private fun watch(id: String, token: String, url: String) {
        setStatus(getString(R.string.checking_youtube))
        io.execute {
            var verdict: Copyright.UploadCheck? = null
            for (attempt in 0 until 15) {
                val check = runCatching { Uploader.status(token, id) }.getOrNull()
                if (check != null && check.done) {
                    verdict = check
                    break
                }
                try {
                    Thread.sleep(20_000)
                } catch (_: InterruptedException) {
                    return@execute
                }
            }
            main.post {
                if (isFinishing || isDestroyed) return@post
                val v = verdict
                if (v == null) {
                    done(getString(R.string.still_processing))
                    return@post
                }
                done(v.message)
                MaterialAlertDialogBuilder(this)
                    .setTitle(if (v.ok) R.string.youtube_ok_title else R.string.youtube_problem_title)
                    .setMessage(v.message)
                    .setPositiveButton(R.string.open_youtube) { _, _ -> startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
                    .setNegativeButton(R.string.close, null)
                    .show()
            }
        }
    }
}
