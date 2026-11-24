package com.hamxanadeem.clipcraft.core

import java.net.URI

/** Turning a pasted link into something ClipCraft can download. */
object Links {
    sealed class Result {
        /** A link to fetch the video file from. */
        data class Download(val url: String, val name: String) : Result()

        /** A link ClipCraft won't fetch, with what to do instead. */
        data class Refused(val reason: String) : Result()
    }

    private val platforms = mapOf(
        "youtube.com" to "YouTube", "youtu.be" to "YouTube", "tiktok.com" to "TikTok",
        "instagram.com" to "Instagram", "facebook.com" to "Facebook", "fb.watch" to "Facebook",
        "x.com" to "X", "twitter.com" to "X", "twitch.tv" to "Twitch", "vimeo.com" to "Vimeo",
        "snapchat.com" to "Snapchat", "dailymotion.com" to "Dailymotion",
    )

    /** Pulls the first http(s) link out of shared or pasted text. */
    fun find(text: String): String? = Regex("https?://\\S+").find(text)?.value?.trimEnd('.', ',', ')', '"', '\'')

    fun resolve(input: String): Result {
        val raw = find(input.trim()) ?: return Result.Refused("That doesn't look like a link. It should start with https://")
        val uri = runCatching { URI(raw) }.getOrNull() ?: return Result.Refused("That link isn't valid.")
        val host = (uri.host ?: return Result.Refused("That link isn't valid.")).lowercase().removePrefix("www.").removePrefix("m.")
        platforms.entries.firstOrNull { host == it.key || host.endsWith("." + it.key) }?.let { (_, site) ->
            return Result.Refused(
                "$site doesn't allow other apps to download its videos, and re-posting someone else's video can get your channel a copyright strike. " +
                    "If it's your own video, download the original file (for YouTube: YouTube Studio → Content → ⋮ → Download) and pick it from your phone."
            )
        }
        val name = uri.path.orEmpty().substringAfterLast('/').ifBlank { "video" }
        // Dropbox share links show a web page unless asked for the file.
        if (host == "dropbox.com" || host.endsWith(".dropbox.com")) {
            val q = (uri.rawQuery ?: "").split('&').filter { it.isNotEmpty() && !it.startsWith("dl=") && !it.startsWith("raw=") }
            return Result.Download(URI(uri.scheme, uri.rawAuthority, uri.rawPath, null, null).toString() + "?" + (q + "dl=1").joinToString("&"), name)
        }
        // Google Drive "view" links → direct download.
        if (host == "drive.google.com") {
            val id = Regex("/file/d/([\\w-]+)").find(uri.path.orEmpty())?.groupValues?.get(1)
                ?: Regex("(?:^|&)id=([\\w-]+)").find(uri.rawQuery.orEmpty())?.groupValues?.get(1)
                ?: return Result.Refused("Couldn't find the file in that Google Drive link. Use Share → Copy link on the video file.")
            return Result.Download("https://drive.google.com/uc?export=download&confirm=t&id=$id", "drive_$id")
        }
        return Result.Download(raw, name)
    }

    /** True if a download's content type looks like a video (or an unlabeled file). */
    fun looksLikeVideo(contentType: String?): Boolean {
        val t = contentType?.lowercase()?.substringBefore(';')?.trim() ?: return true
        return t.startsWith("video/") || t == "application/octet-stream" || t == "binary/octet-stream" || t == "application/mp4"
    }
}
