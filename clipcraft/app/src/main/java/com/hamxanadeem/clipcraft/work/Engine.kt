package com.hamxanadeem.clipcraft.work

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.hamxanadeem.clipcraft.R
import com.hamxanadeem.clipcraft.core.AdvisorException
import com.hamxanadeem.clipcraft.core.Captions
import com.hamxanadeem.clipcraft.core.ClipAdvisor
import com.hamxanadeem.clipcraft.core.ClipSource
import com.hamxanadeem.clipcraft.core.ClipState
import com.hamxanadeem.clipcraft.core.Heuristic
import com.hamxanadeem.clipcraft.core.Project
import com.hamxanadeem.clipcraft.core.Script
import com.hamxanadeem.clipcraft.core.Scripts
import com.hamxanadeem.clipcraft.core.ServerClipSource
import com.hamxanadeem.clipcraft.core.Transcript
import com.hamxanadeem.clipcraft.core.Word
import com.hamxanadeem.clipcraft.core.YouTube
import com.hamxanadeem.clipcraft.data.Languages
import com.hamxanadeem.clipcraft.data.ProjectStore
import com.hamxanadeem.clipcraft.data.Settings
import com.hamxanadeem.clipcraft.media.ClipRenderer
import com.hamxanadeem.clipcraft.media.FaceTracker
import com.hamxanadeem.clipcraft.media.Speech
import com.hamxanadeem.clipcraft.media.Style
import com.hamxanadeem.clipcraft.ui.MainActivity
import com.hamxanadeem.clipcraft.youtube.Uploader
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Does the slow work (transcribe, find clips, render, upload) one job at a time on a
 * background thread, saving results into the project as it goes. A foreground
 * service keeps the app alive while there is work, so you can leave the app.
 * Screens listen for changes and redraw.
 */
object Engine {
    private lateinit var app: Context
    private val worker = Executors.newSingleThreadExecutor()
    private val watcher = Executors.newSingleThreadScheduledExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val pending = AtomicInteger(0)
    private val progress = ConcurrentHashMap<String, String>()
    private val listeners = CopyOnWriteArraySet<() -> Unit>()
    private val transcripts = ConcurrentHashMap<String, Pair<Transcript, FloatArray>>()
    private var lastNotify = 0L
    private const val DONE_CHANNEL = "done"

    fun init(c: Context) {
        if (!::app.isInitialized) app = c.applicationContext
    }

    fun idle(): Boolean = pending.get() == 0

    fun listen(l: () -> Unit) = listeners.add(l)

    fun unlisten(l: () -> Unit) = listeners.remove(l)

    /** What's happening to the project right now, or null. */
    fun projectProgress(id: String): String? = progress[pKey(id)]

    /** What's happening to one clip right now ("Waiting…", "Making the Short… 40%"), or null. */
    fun clipProgress(id: String, i: Int): String? = progress[cKey(id, i)]

    fun busy(id: String): Boolean = progress.keys.any { it == pKey(id) || it.startsWith("c:$id:") }

    private fun pKey(id: String) = "p:$id"
    private fun cKey(id: String, i: Int) = "c:$id:$i"

    private fun changed() = main.post { listeners.forEach { it() } }

    private fun set(key: String, text: String) {
        progress[key] = text
        changed()
        notifyProgress(text)
    }

    private fun clear(key: String) {
        progress.remove(key)
        changed()
    }

    private fun enqueue(key: String, job: () -> Unit) {
        if (progress.containsKey(key)) return
        progress[key] = app.getString(R.string.waiting)
        changed()
        if (pending.getAndIncrement() == 0) startService()
        worker.execute {
            try {
                job()
            } catch (e: Exception) {
                // Each job reports its own errors; this is a last resort.
                post(app.getString(R.string.job_failed, e.message ?: e.javaClass.simpleName))
            } finally {
                clear(key)
                if (pending.decrementAndGet() == 0) main.post { if (idle()) stopService() }
            }
        }
    }

    // ---- Jobs ---------------------------------------------------------------

    /** Transcribes the video (once) and finds clips. [again] asks for a fresh set. */
    fun analyze(id: String, again: Boolean = false) = enqueue(pKey(id)) { runAnalyze(id, again) }

    fun render(id: String, i: Int) = enqueue(cKey(id, i)) { runRender(id, i) }

    fun renderAll(id: String) {
        val p = ProjectStore.get(app, id) ?: return
        p.clips.forEachIndexed { i, c -> if (!rendered(c)) render(id, i) }
    }

    /**
     * Uploads clips (rendering first where needed). [publishAt] holds one RFC 3339 time
     * per clip for scheduled posts, or nulls to post now with [privacy].
     */
    fun upload(id: String, indices: List<Int>, token: String, privacy: String, publishAt: List<String?>) {
        indices.forEachIndexed { k, i ->
            enqueue(cKey(id, i)) { runUpload(id, i, token, privacy, publishAt.getOrNull(k)) }
        }
    }

    fun rendered(c: ClipState): Boolean = c.rendered != null && File(c.rendered).exists()

    // ---- Analyse ------------------------------------------------------------

    private fun runAnalyze(id: String, again: Boolean) {
        val key = pKey(id)
        var p = ProjectStore.update(app, id) { it.copy(status = Project.WORKING, message = "") } ?: return
        try {
            p = readable(p)
            val (t, loud) = transcript(p) { set(key, it) }
            val source = source()
            set(key, app.getString(if (source != null) R.string.ai_thinking else R.string.finding_offline))
            val count = Settings.clipCount(app)
            var note: String? = null
            var ai = false
            val plans = if (source != null) {
                try {
                    source.suggest(t, count, Settings.notes(app), loud).also { ai = true }
                } catch (e: AdvisorException) {
                    note = e.message
                    Heuristic.pick(t, count)
                }
            } else {
                Heuristic.pick(t, count)
            }
            if (again) p.clips.forEach { c -> c.rendered?.let { File(it).delete() } }
            val keep = if (again) emptyList() else p.clips
            val clips = if (keep.isNotEmpty()) keep else plans.map { ClipState(it) }
            val msg = when {
                clips.isEmpty() -> app.getString(R.string.no_clips)
                note != null -> app.getString(R.string.ai_fallback, note)
                ai -> app.getString(R.string.ai_found, clips.size, t.words.size)
                else -> app.getString(R.string.offline_found, clips.size)
            }
            ProjectStore.update(app, id) { it.copy(status = Project.READY, message = msg, aiUsed = ai, clips = clips) }
            post(app.getString(R.string.clips_ready_note, clips.size), id)
        } catch (e: Exception) {
            ProjectStore.update(app, id) {
                it.copy(status = Project.ERROR, message = app.getString(R.string.transcribe_failed, e.message ?: e.javaClass.simpleName))
            }
        }
    }

    /**
     * Makes sure we can still read the video after a restart. Videos picked in the app
     * keep their permission; shared ones get copied into the project folder.
     */
    private fun readable(p: Project): Project {
        val uri = Uri.parse(p.video)
        if (uri.scheme != "content" || ProjectStore.persisted(app, uri)) return p
        set(pKey(p.id), app.getString(R.string.copying_video))
        val f = File(ProjectStore.dir(app, p.id), "video.mp4")
        app.contentResolver.openInputStream(uri)?.use { input -> f.outputStream().use { input.copyTo(it) } }
            ?: throw IllegalStateException(app.getString(R.string.video_gone))
        return ProjectStore.update(app, p.id) { it.copy(video = Uri.fromFile(f).toString()) } ?: p
    }

    /** The project's transcript and loudness, from memory, disk, or by transcribing. */
    fun transcript(p: Project, onStatus: (String) -> Unit = {}): Pair<Transcript, FloatArray> {
        transcripts[p.id]?.let { return it }
        val dir = ProjectStore.dir(app, p.id)
        val tf = File(dir, "transcript_${p.language}.json")
        val lf = File(dir, "loudness.txt")
        var t = Speech.load(tf)
        var loud = Speech.loadLoudness(lf)
        if (t == null || loud == null) {
            val model = Languages.get(p.language)
            if (!Speech.hasModel(app, model)) {
                Speech.download(app, model) { f -> onStatus(app.getString(R.string.downloading_model_pct, model.name, (f * 100).toInt())) }
            }
            onStatus(app.getString(R.string.transcribing_pct, 0))
            var lastPct = -1
            val r = Speech.transcribe(app, Uri.parse(p.video), model) { f ->
                val pct = (f * 100).toInt()
                if (pct != lastPct) {
                    lastPct = pct
                    onStatus(app.getString(R.string.transcribing_pct, pct))
                }
            }
            t = r.transcript
            loud = r.loudness
            Speech.save(tf, t)
            Speech.saveLoudness(lf, loud)
        }
        val pair = t to loud
        transcripts[p.id] = pair
        return pair
    }

    /** Words for captions: the transcript, with the clip's edited or converted words swapped in. */
    fun captionWords(t: Transcript, c: ClipState): List<Word> {
        val w = c.words ?: return t.words
        if (w.isEmpty()) return t.words.filter { it.end <= c.plan.start || it.start >= c.plan.end }
        val old = t.between(w.first().start, w.last().end)
        return if (old.isEmpty()) (t.words + w).sortedBy { it.start } else Captions.replace(t.words, old, w)
    }

    fun forget(id: String) {
        transcripts.remove(id)
    }

    /** Who to ask for AI help, per this user's choice on the AI page, or null for no Claude (offline). */
    fun source(): ClipSource? = source(app)

    fun source(c: Context): ClipSource? = when (Settings.aiMode(c)) {
        Settings.AI_KEY -> Settings.apiKey(c).takeIf { it.isNotBlank() }?.let { ClipAdvisor(it) }
        Settings.AI_SERVER -> Settings.serverUrl(c).takeIf { it.isNotBlank() }
            ?.let { ServerClipSource(it, Settings.serverToken(c), Settings.deviceId(c)) }
        else -> null
    }

    // ---- Render -------------------------------------------------------------

    private fun runRender(id: String, i: Int): Boolean {
        val key = cKey(id, i)
        val p = ProjectStore.get(app, id) ?: return false
        var c = p.clips.getOrNull(i) ?: return false
        val (t, _) = transcript(p) { set(key, it) }
        // Convert captions to Urdu or Roman Urdu once, if asked.
        val script = Script.of(Settings.script(app))
        if (script != Script.AS_SPOKEN && c.words == null) {
            val src = source()
            if (src != null) {
                set(key, app.getString(R.string.converting_script, script.label))
                val words = t.between(c.plan.start, c.plan.end)
                val texts = runCatching { src.transliterate(words.map { it.text }, script) }.getOrNull()
                if (texts != null && texts.size == words.size) {
                    c = c.copy(words = Scripts.apply(words, texts))
                    ProjectStore.update(app, id) { pr -> pr.copy(clips = pr.clips.toMutableList().also { it[i] = c }) }
                }
            }
        }
        val video = Uri.parse(p.video)
        val pan = if (Settings.reframe(app)) {
            set(key, app.getString(R.string.finding_faces))
            FaceTracker.pan(app, video, c.plan.start, c.plan.end)
        } else null
        val style = Style(Settings.captions(app), Settings.hook(app), Settings.captionColor(app),
            Settings.captionStyle(app), Settings.captionPosition(app))
        val captions = Captions.build(captionWords(t, c), c.plan.start, c.plan.end)
        val out = File(ProjectStore.dir(app, id), "clip_${i}_${System.currentTimeMillis()}.mp4")
        set(key, app.getString(R.string.rendering, 0))
        val done = CountDownLatch(1)
        var result: Result<File> = Result.failure(IllegalStateException())
        main.post {
            ClipRenderer(app).render(video, c.plan, captions, style, pan, out,
                onProgress = { pct -> set(key, app.getString(R.string.rendering, pct)) },
                onDone = { r ->
                    result = r
                    done.countDown()
                })
        }
        done.await()
        val r = result
        return if (r.isSuccess) {
            ProjectStore.update(app, id) { pr ->
                pr.copy(clips = pr.clips.toMutableList().also { list ->
                    list.getOrNull(i)?.rendered?.let { old -> if (old != out.absolutePath) File(old).delete() }
                    if (i < list.size) list[i] = list[i].copy(rendered = out.absolutePath)
                })
            }
            true
        } else {
            out.delete()
            val msg = app.getString(R.string.render_failed, r.exceptionOrNull()?.message ?: "")
            ProjectStore.update(app, id) { it.copy(message = msg) }
            post(msg, id)
            false
        }
    }

    // ---- Upload -------------------------------------------------------------

    private fun runUpload(id: String, i: Int, token: String, privacy: String, publishAt: String?) {
        val key = cKey(id, i)
        var c = ProjectStore.get(app, id)?.clips?.getOrNull(i) ?: return
        if (!rendered(c)) {
            if (!runRender(id, i)) return
            c = ProjectStore.get(app, id)?.clips?.getOrNull(i) ?: return
        }
        val file = File(c.rendered ?: return)
        set(key, app.getString(R.string.uploading, 0))
        val meta = YouTube.metadata(c.plan, privacy, publishAt = publishAt)
        var last = -1
        val ytId = try {
            Uploader.upload(token, file, meta) { f ->
                val pct = (f * 100).toInt()
                if (pct != last) {
                    last = pct
                    set(key, app.getString(R.string.uploading, pct))
                }
            }
        } catch (e: Exception) {
            val msg = e.message ?: app.getString(R.string.upload_failed)
            setClip(id, i) { it.copy(youtubeStatus = msg) }
            post(msg, id)
            return
        }
        setClip(id, i) { it.copy(youtubeId = ytId, publishAt = publishAt, youtubeStatus = app.getString(R.string.checking_youtube)) }
        watch(id, i, ytId, token, 0)
    }

    private fun setClip(id: String, i: Int, change: (ClipState) -> ClipState) {
        ProjectStore.update(app, id) { pr ->
            if (i >= pr.clips.size) pr else pr.copy(clips = pr.clips.toMutableList().also { it[i] = change(it[i]) })
        }
        changed()
    }

    /** Asks YouTube every 20 s (up to 5 minutes) whether it accepted or rejected the video. */
    private fun watch(id: String, i: Int, ytId: String, token: String, attempt: Int) {
        watcher.schedule({
            val check = runCatching { Uploader.status(token, ytId) }.getOrNull()
            when {
                check != null && check.done -> {
                    setClip(id, i) { it.copy(youtubeStatus = check.message) }
                    post(check.message, id)
                }
                attempt >= 14 -> setClip(id, i) { it.copy(youtubeStatus = app.getString(R.string.still_processing)) }
                else -> watch(id, i, ytId, token, attempt + 1)
            }
        }, 20, TimeUnit.SECONDS)
    }

    // ---- Service and notifications -------------------------------------------

    private fun startService() {
        runCatching { ContextCompat.startForegroundService(app, Intent(app, WorkService::class.java)) }
    }

    private fun stopService() {
        app.stopService(Intent(app, WorkService::class.java))
    }

    private fun canNotify(): Boolean = Build.VERSION.SDK_INT < 33 ||
        ContextCompat.checkSelfPermission(app, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun notifyProgress(text: String) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastNotify < 1000 || idle() || !canNotify()) return
        lastNotify = now
        val pct = Regex("(\\d+)%").find(text)?.groupValues?.get(1)?.toIntOrNull() ?: -1
        val nm = app.getSystemService(NotificationManager::class.java) ?: return
        runCatching { nm.notify(WorkService.ID, WorkService.notification(app, text, pct)) }
    }

    /** A one-off "done" or "problem" notification that opens the project. */
    private fun post(text: String, projectId: String? = null) {
        if (!canNotify()) return
        val nm = app.getSystemService(NotificationManager::class.java) ?: return
        nm.createNotificationChannel(NotificationChannel(DONE_CHANNEL, app.getString(R.string.channel_done), NotificationManager.IMPORTANCE_DEFAULT))
        val intent = Intent(app, MainActivity::class.java).putExtra(MainActivity.EXTRA_PROJECT, projectId)
        val open = PendingIntent.getActivity(app, projectId.hashCode(), intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(app, DONE_CHANNEL)
            .setSmallIcon(R.drawable.ic_cut)
            .setContentTitle(app.getString(R.string.app_name))
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        runCatching { nm.notify(SystemClock.elapsedRealtime().toInt(), n) }
    }
}
