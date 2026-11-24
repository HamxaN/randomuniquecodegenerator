package com.hamxanadeem.clipcraft.data

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.hamxanadeem.clipcraft.core.Project
import com.hamxanadeem.clipcraft.core.ProjectCodec
import java.io.File
import java.text.DateFormat
import java.util.Date
import java.util.UUID

/** Projects saved on this phone, one folder each (project.json, transcript, loudness, clips). */
object ProjectStore {
    private val cache = mutableMapOf<String, Project>()
    private var loaded = false

    fun root(c: Context): File = File(c.applicationContext.filesDir, "projects").apply { mkdirs() }

    fun dir(c: Context, id: String): File = File(root(c), id).apply { mkdirs() }

    @Synchronized
    fun all(c: Context): List<Project> {
        if (!loaded) {
            root(c).listFiles()?.forEach { d ->
                val f = File(d, "project.json")
                if (f.exists()) ProjectCodec.decode(f.readText())?.let { cache[it.id] = it }
            }
            loaded = true
        }
        return cache.values.sortedByDescending { it.created }
    }

    @Synchronized
    fun get(c: Context, id: String): Project? {
        all(c)
        return cache[id]
    }

    /** Starts a project for a video, keeping long-term read access to it where Android allows. */
    fun create(c: Context, video: Uri, language: String, name: String? = null): Project {
        if (video.scheme == "content") {
            runCatching { c.contentResolver.takePersistableUriPermission(video, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
        }
        val now = System.currentTimeMillis()
        val p = Project(UUID.randomUUID().toString().take(12),
            name ?: ("Video " + DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(now))),
            video.toString(), now, language)
        save(c, p)
        return p
    }

    @Synchronized
    fun save(c: Context, p: Project) {
        cache[p.id] = p
        val d = dir(c, p.id)
        val tmp = File(d, "project.json.tmp")
        tmp.writeText(ProjectCodec.encode(p))
        if (!tmp.renameTo(File(d, "project.json"))) {
            File(d, "project.json").writeText(ProjectCodec.encode(p))
            tmp.delete()
        }
    }

    @Synchronized
    fun update(c: Context, id: String, change: (Project) -> Project): Project? {
        val p = get(c, id) ?: return null
        val n = change(p)
        save(c, n)
        return n
    }

    @Synchronized
    fun delete(c: Context, id: String) {
        val p = cache.remove(id)
        dir(c, id).deleteRecursively()
        if (p != null && p.video.startsWith("content://")) {
            runCatching { c.contentResolver.releasePersistableUriPermission(Uri.parse(p.video), Intent.FLAG_GRANT_READ_URI_PERMISSION) }
        }
    }

    /** True if the app may still read [uri] after restarts. */
    fun persisted(c: Context, uri: Uri): Boolean =
        uri.scheme == "file" || c.contentResolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission }
}
