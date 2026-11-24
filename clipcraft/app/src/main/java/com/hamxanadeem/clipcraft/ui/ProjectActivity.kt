package com.hamxanadeem.clipcraft.ui

import android.content.ClipData
import android.content.DialogInterface
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.FileProvider
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.datepicker.MaterialDatePicker
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.materialswitch.MaterialSwitch
import com.google.android.material.progressindicator.LinearProgressIndicator
import com.google.android.material.slider.Slider
import com.google.android.material.timepicker.MaterialTimePicker
import com.google.android.material.timepicker.TimeFormat
import com.hamxanadeem.clipcraft.R
import com.hamxanadeem.clipcraft.core.Captions
import com.hamxanadeem.clipcraft.core.ClipState
import com.hamxanadeem.clipcraft.core.Clips
import com.hamxanadeem.clipcraft.core.Copyright
import com.hamxanadeem.clipcraft.core.Project
import com.hamxanadeem.clipcraft.core.Schedule
import com.hamxanadeem.clipcraft.core.Transcript
import com.hamxanadeem.clipcraft.core.Word
import com.hamxanadeem.clipcraft.core.YouTube
import com.hamxanadeem.clipcraft.data.ProjectStore
import com.hamxanadeem.clipcraft.data.Settings
import com.hamxanadeem.clipcraft.media.Gallery
import com.hamxanadeem.clipcraft.work.Engine
import com.hamxanadeem.clipcraft.youtube.YouTubeAuth
import java.io.File
import java.text.DateFormat
import java.util.Calendar
import java.util.Date
import java.util.TimeZone
import java.util.concurrent.Executors

/**
 * One saved video: its clips, which you can preview, edit, trim, fix captions on,
 * render, save, share or post (one by one, all at once, or on a schedule). The slow
 * work runs in [Engine], so it carries on if you leave this screen.
 */
class ProjectActivity : AppCompatActivity() {

    private lateinit var id: String
    private lateinit var player: ExoPlayer
    private lateinit var status: TextView
    private lateinit var progress: LinearProgressIndicator
    private var project: Project? = null
    private var transcript: Transcript? = null
    private var loudness: FloatArray = FloatArray(0)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val refresh: () -> Unit = { reload() }
    private var playerVideo: String? = null

    /** The upload waiting for Google sign-in: clip indices, privacy and schedule times. */
    private var pendingUpload: Triple<List<Int>, String, List<String?>>? = null

    private val consent = registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { r ->
        YouTubeAuth.fromConsent(this, r.data, { token -> startUpload(token) }, { msg -> Ui.toast(this, msg) })
    }

    private val clips: List<ClipState> get() = project?.clips ?: emptyList()

    private val adapter = object : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
        override fun getItemCount() = clips.size
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            object : RecyclerView.ViewHolder(LayoutInflater.from(parent.context).inflate(R.layout.item_clip, parent, false)) {}

        override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) = bind(holder.itemView, position)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        Engine.init(this)
        setContentView(R.layout.activity_project)
        Ui.fitSystemBars(findViewById(R.id.root))
        id = intent.getStringExtra(MainActivity.EXTRA_PROJECT) ?: run {
            finish()
            return
        }
        if (ProjectStore.get(this, id) == null) {
            finish()
            return
        }
        val toolbar = findViewById<MaterialToolbar>(R.id.toolbar)
        toolbar.setNavigationOnClickListener { finish() }
        toolbar.setOnMenuItemClickListener {
            when (it.itemId) {
                R.id.action_again -> findAgain()
                R.id.action_make_all -> Engine.renderAll(id)
                R.id.action_upload_all -> askUpload(clips.indices.filter { i -> clips[i].youtubeId == null })
            }
            true
        }
        status = findViewById(R.id.status)
        progress = findViewById(R.id.progress)
        val list = findViewById<RecyclerView>(R.id.clips)
        list.layoutManager = LinearLayoutManager(this)
        list.adapter = adapter
        player = ExoPlayer.Builder(this).build()
        findViewById<PlayerView>(R.id.player).player = player
    }

    override fun onResume() {
        super.onResume()
        Engine.listen(refresh)
        reload()
    }

    override fun onPause() {
        Engine.unlisten(refresh)
        player.pause()
        super.onPause()
    }

    override fun onDestroy() {
        if (::player.isInitialized) player.release()
        io.shutdownNow()
        super.onDestroy()
    }

    private fun reload() {
        val p = ProjectStore.get(this, id) ?: return finish()
        project = p
        findViewById<MaterialToolbar>(R.id.toolbar).title = p.name
        if (playerVideo != p.video) {
            playerVideo = p.video
            player.setMediaItem(MediaItem.fromUri(Uri.parse(p.video)))
            player.prepare()
        }
        if (p.status == Project.READY && transcript == null) loadTranscript(p)
        val working = Engine.projectProgress(id)
        if (working != null) {
            status.text = working
            val pct = Regex("(\\d+)%").find(working)?.groupValues?.get(1)?.toIntOrNull()
            progress.isIndeterminate = pct == null
            if (pct != null) progress.setProgressCompat(pct, true)
            progress.visibility = View.VISIBLE
        } else {
            status.text = p.message
            progress.visibility = View.GONE
        }
        @Suppress("NotifyDataSetChanged")
        adapter.notifyDataSetChanged()
    }

    private fun loadTranscript(p: Project) {
        io.execute {
            val r = runCatching { Engine.transcript(p) }.getOrNull() ?: return@execute
            main.post {
                transcript = r.first
                loudness = r.second
                @Suppress("NotifyDataSetChanged")
                adapter.notifyDataSetChanged()
            }
        }
    }

    private fun findAgain() {
        if (Engine.busy(id)) {
            Ui.toast(this, getString(R.string.wait_for_work))
            return
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.find_again)
            .setMessage(R.string.find_again_body)
            .setPositiveButton(R.string.find_again) { _, _ -> Engine.analyze(id, again = true) }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun bind(v: View, i: Int) {
        val s = clips[i]
        val c = s.plan
        v.findViewById<TextView>(R.id.score).text = c.score.toString()
        v.findViewById<TextView>(R.id.title).text = c.title
        v.findViewById<TextView>(R.id.time).text = getString(R.string.clip_time,
            Transcript.format(c.start), Transcript.format(c.end), c.length.toInt())
        v.findViewById<TextView>(R.id.reason).text = c.reason
        v.findViewById<TextView>(R.id.tags).text = c.hashtags.joinToString(" ")
        val warn = musicWarning(s)
        v.findViewById<TextView>(R.id.music).apply {
            text = warn ?: ""
            visibility = if (warn == null) View.GONE else View.VISIBLE
        }
        val busy = Engine.clipProgress(id, i)
        val made = Engine.rendered(s)
        val lines = mutableListOf<String>()
        if (busy != null) lines += busy else if (made) lines += getString(R.string.ready)
        s.publishAt?.let { lines += getString(R.string.scheduled_for, localTime(it)) }
        s.youtubeStatus?.let { lines += it }
        val state = v.findViewById<TextView>(R.id.state)
        state.text = lines.joinToString("\n")
        state.visibility = if (lines.isEmpty()) View.GONE else View.VISIBLE
        v.findViewById<Button>(R.id.preview).setOnClickListener { preview(s) }
        v.findViewById<Button>(R.id.edit).setOnClickListener { edit(i) }
        v.findViewById<Button>(R.id.captions).setOnClickListener { editCaptions(i) }
        val make = v.findViewById<Button>(R.id.make)
        make.isEnabled = busy == null
        make.setText(if (!made) R.string.make_short else R.string.remake_short)
        make.setOnClickListener { Engine.render(id, i) }
        v.findViewById<LinearLayout>(R.id.after).visibility = if (made) View.VISIBLE else View.GONE
        v.findViewById<Button>(R.id.save).setOnClickListener { save(s) }
        v.findViewById<Button>(R.id.share).setOnClickListener { share(s) }
        v.findViewById<Button>(R.id.upload).apply {
            isEnabled = busy == null
            setOnClickListener { askUpload(listOf(i)) }
        }
    }

    private fun preview(s: ClipState) {
        val p = project ?: return
        val rendered = s.rendered?.let { File(it) }?.takeIf { it.exists() }
        val item = if (rendered != null) {
            MediaItem.fromUri(Uri.fromFile(rendered))
        } else {
            MediaItem.Builder().setUri(Uri.parse(p.video)).setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs((s.plan.start * 1000).toLong())
                    .setEndPositionMs((s.plan.end * 1000).toLong())
                    .build()
            ).build()
        }
        playerVideo = null
        player.setMediaItem(item)
        player.prepare()
        player.play()
    }

    /** Replaces clip [i] and marks it as needing a new render. */
    private fun change(i: Int, f: (ClipState) -> ClipState) {
        if (Engine.clipProgress(id, i) != null) {
            Ui.toast(this, getString(R.string.wait_for_work))
            return
        }
        ProjectStore.update(this, id) { p ->
            p.copy(clips = p.clips.toMutableList().also { list ->
                val old = list[i]
                old.rendered?.let { File(it).delete() }
                list[i] = f(old).copy(rendered = null)
            })
        }
        reload()
    }

    /** Title, hook, description, and trimming the start and end a second at a time. */
    private fun edit(i: Int) {
        val s = clips[i]
        val view = LayoutInflater.from(this).inflate(R.layout.dialog_edit, null as ViewGroup?)
        val title = view.findViewById<EditText>(R.id.edit_title)
        val hook = view.findViewById<EditText>(R.id.edit_hook)
        val desc = view.findViewById<EditText>(R.id.edit_description)
        title.setText(s.plan.title)
        hook.setText(s.plan.hook)
        desc.setText(s.plan.description)
        var plan = s.plan
        val duration = maxOf(player.duration.takeIf { it > 0 }?.div(1000.0) ?: 0.0, transcript?.duration ?: 0.0, plan.end)
        val time = view.findViewById<TextView>(R.id.trim_time)
        val show = { time.text = getString(R.string.clip_time, Transcript.format(plan.start), Transcript.format(plan.end), plan.length.toInt()) }
        show()
        fun nudge(b: Int, startBy: Double, endBy: Double) = view.findViewById<Button>(b).setOnClickListener {
            plan = Clips.nudge(plan, startBy, endBy, duration)
            show()
        }
        nudge(R.id.start_minus, -1.0, 0.0)
        nudge(R.id.start_plus, 1.0, 0.0)
        nudge(R.id.end_minus, 0.0, -1.0)
        nudge(R.id.end_plus, 0.0, 1.0)
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.edit_clip)
            .setView(view)
            .setPositiveButton(R.string.save_changes) { _, _ ->
                change(i) {
                    it.copy(plan = plan.copy(title = title.text.toString().trim(), hook = hook.text.toString().trim(),
                        description = desc.text.toString().trim()))
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    /** Fix any caption: one box per caption line, in order. */
    private fun editCaptions(i: Int) {
        val t = transcript ?: run {
            Ui.toast(this, getString(R.string.wait_for_work))
            return
        }
        val s = clips[i]
        val source = Engine.captionWords(t, s)
        val caps = Captions.build(source, s.plan.start, s.plan.end)
        if (caps.isEmpty()) {
            Ui.toast(this, getString(R.string.no_captions))
            return
        }
        // Captions are in clip time; the edits are stored in video time.
        val inClip = source.filter { it.end > s.plan.start && it.start < s.plan.end }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val pad = Ui.dp(this@ProjectActivity, 20)
            setPadding(pad, Ui.dp(this@ProjectActivity, 8), pad, 0)
        }
        val fields = caps.map { cap ->
            box.addView(TextView(this).apply {
                text = Transcript.format(s.plan.start + cap.start)
                setTextColor(getColor(R.color.ink_soft))
                textSize = 12f
            })
            EditText(this).apply {
                setText(cap.words.joinToString(" ") { it.text })
                inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
                minHeight = Ui.dp(this@ProjectActivity, 48)
                importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO
                contentDescription = getString(R.string.caption_at, Transcript.format(s.plan.start + cap.start))
                box.addView(this)
            }
        }
        val scroll = ScrollView(this).apply { addView(box) }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.edit_captions)
            .setMessage(R.string.edit_captions_body)
            .setView(scroll)
            .setPositiveButton(R.string.save_changes) { _, _ ->
                var words: List<Word> = inClip
                caps.forEachIndexed { k, cap ->
                    val before = cap.words.joinToString(" ") { it.text }
                    val after = fields[k].text.toString().trim()
                    if (after != before) {
                        // Back to video time for storage.
                        val old = cap.words.map { it.copy(start = it.start + s.plan.start, end = it.end + s.plan.start) }
                        words = Captions.replace(words, old, Captions.retime(old, after))
                    }
                }
                change(i) { it.copy(words = words) }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun save(s: ClipState) {
        val f = s.rendered?.let { File(it) } ?: return
        val uri = runCatching { Gallery.save(this, f, "clipcraft_${System.currentTimeMillis()}") }.getOrNull()
        Ui.toast(this, getString(if (uri != null) R.string.saved else R.string.save_failed))
    }

    private fun share(s: ClipState) {
        val f = s.rendered?.let { File(it) } ?: return
        val uri = FileProvider.getUriForFile(this, "$packageName.files", f)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, s.plan.title + "\n\n" + YouTube.description(s.plan))
            clipData = ClipData.newRawUri("clip", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(send, getString(R.string.share)))
    }

    private fun musicWarning(s: ClipState): String? {
        val t = transcript ?: return null
        return Copyright.warning(Copyright.musicRisk(loudness, t, s.plan.start, s.plan.end))
    }

    /**
     * One copyright checklist for every clip being posted, then post now or schedule
     * them spaced out (YouTube publishes scheduled videos itself, even if the phone is off).
     */
    private fun askUpload(indices: List<Int>) {
        if (indices.isEmpty()) {
            Ui.toast(this, getString(R.string.nothing_to_upload))
            return
        }
        val view = LayoutInflater.from(this).inflate(R.layout.dialog_upload, null as ViewGroup?)
        val privacy = Settings.privacy(this)
        view.findViewById<TextView>(R.id.upload_summary).text = if (indices.size == 1) {
            getString(R.string.upload_body, YouTube.title(clips[indices[0]].plan), getString(privacyLabel(privacy)))
        } else {
            getString(R.string.upload_many_body, indices.size, getString(privacyLabel(privacy)))
        }
        val warnings = indices.mapNotNull { i -> musicWarning(clips[i])?.let { w -> if (indices.size == 1) w else "#${i + 1}: $w" } }
        view.findViewById<TextView>(R.id.upload_music).apply {
            text = if (warnings.isEmpty()) getString(R.string.no_music_found) else warnings.joinToString("\n")
            setTextColor(getColor(if (warnings.isNotEmpty()) R.color.brand else R.color.ink_soft))
        }
        val own = view.findViewById<CheckBox>(R.id.check_own)
        val music = view.findViewById<CheckBox>(R.id.check_music)
        val schedule = view.findViewById<MaterialSwitch>(R.id.schedule)
        val scheduleBox = view.findViewById<View>(R.id.schedule_box)
        val whenButton = view.findViewById<Button>(R.id.schedule_when)
        val gap = view.findViewById<Slider>(R.id.schedule_gap)
        val gapLabel = view.findViewById<TextView>(R.id.schedule_gap_label)
        // Default: tomorrow at 18:00 local time.
        val first = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 18)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val showWhen = { whenButton.text = getString(R.string.schedule_first, DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(first.time)) }
        val showGap = { gapLabel.text = getString(R.string.schedule_gap, gap.value.toInt()) }
        showWhen()
        showGap()
        gap.visibility = if (indices.size > 1) View.VISIBLE else View.GONE
        gapLabel.visibility = gap.visibility
        gap.addOnChangeListener { _, _, _ -> showGap() }
        whenButton.setOnClickListener { pickTime(first) { showWhen() } }
        schedule.setOnCheckedChangeListener { _, on -> scheduleBox.visibility = if (on) View.VISIBLE else View.GONE }
        val dialog = MaterialAlertDialogBuilder(this)
            .setTitle(if (indices.size == 1) R.string.upload_title else R.string.upload_all_title)
            .setView(view)
            .setPositiveButton(R.string.upload) { _, _ ->
                val times: List<String?> = if (schedule.isChecked) {
                    if (first.timeInMillis < System.currentTimeMillis() + 15 * 60_000L) {
                        Ui.toast(this, getString(R.string.schedule_too_soon))
                        return@setPositiveButton
                    }
                    Schedule.times(first.timeInMillis, gap.value.toInt(), indices.size)
                } else {
                    indices.map { null }
                }
                pendingUpload = Triple(indices, if (schedule.isChecked) "private" else privacy, times)
                YouTubeAuth.authorize(this, consent, { token -> startUpload(token) }, { msg -> Ui.toast(this, msg) })
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
        val go = dialog.getButton(DialogInterface.BUTTON_POSITIVE)
        val update = { go.isEnabled = own.isChecked && music.isChecked }
        update()
        own.setOnCheckedChangeListener { _, _ -> update() }
        music.setOnCheckedChangeListener { _, _ -> update() }
    }

    private fun pickTime(cal: Calendar, done: () -> Unit) {
        // The date picker works in UTC days; convert to and from the local calendar.
        val utc = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH))
        }
        val date = MaterialDatePicker.Builder.datePicker().setSelection(utc.timeInMillis).build()
        date.addOnPositiveButtonClickListener { sel ->
            val d = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = sel }
            cal.set(d.get(Calendar.YEAR), d.get(Calendar.MONTH), d.get(Calendar.DAY_OF_MONTH))
            val time = MaterialTimePicker.Builder()
                .setTimeFormat(if (android.text.format.DateFormat.is24HourFormat(this)) TimeFormat.CLOCK_24H else TimeFormat.CLOCK_12H)
                .setHour(cal.get(Calendar.HOUR_OF_DAY))
                .setMinute(cal.get(Calendar.MINUTE))
                .build()
            time.addOnPositiveButtonClickListener {
                cal.set(Calendar.HOUR_OF_DAY, time.hour)
                cal.set(Calendar.MINUTE, time.minute)
                done()
            }
            time.show(supportFragmentManager, "time")
        }
        date.show(supportFragmentManager, "date")
    }

    private fun startUpload(token: String) {
        val (indices, privacy, times) = pendingUpload ?: return
        pendingUpload = null
        Engine.upload(id, indices, token, privacy, times)
        Ui.toast(this, getString(R.string.upload_queued, indices.size))
    }

    private fun privacyLabel(p: String) = when (p) {
        "public" -> R.string.privacy_public
        "unlisted" -> R.string.privacy_unlisted
        else -> R.string.privacy_private
    }

    private fun localTime(rfc3339: String): String = runCatching {
        DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(java.time.Instant.parse(rfc3339).toEpochMilli()))
    }.getOrDefault(rfc3339)
}
