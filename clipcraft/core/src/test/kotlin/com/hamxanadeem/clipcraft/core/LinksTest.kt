package com.hamxanadeem.clipcraft.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class LinksTest {
    private fun dl(s: String) = Links.resolve(s) as Links.Result.Download

    @Test
    fun directAndShared() {
        assertEquals("https://example.com/a/talk.mp4", dl("https://example.com/a/talk.mp4").url)
        assertEquals("talk.mp4", dl("Watch this https://example.com/a/talk.mp4.").name)
        assertEquals("https://www.dropbox.com/s/abc/v.mp4?dl=1", dl("https://www.dropbox.com/s/abc/v.mp4?dl=0").url)
        assertEquals("https://www.dropbox.com/scl/fi/x/v.mp4?rlkey=k&dl=1", dl("https://www.dropbox.com/scl/fi/x/v.mp4?rlkey=k&dl=0").url)
        assertEquals("https://drive.google.com/uc?export=download&confirm=t&id=1AbC-d_9",
            dl("https://drive.google.com/file/d/1AbC-d_9/view?usp=sharing").url)
        assertEquals("https://drive.google.com/uc?export=download&confirm=t&id=XYZ", dl("https://drive.google.com/open?id=XYZ").url)
    }

    @Test
    fun refused() {
        for (u in listOf("https://www.youtube.com/watch?v=abc", "https://youtu.be/abc", "https://m.youtube.com/shorts/x",
            "https://vm.tiktok.com/x", "https://www.instagram.com/reel/x", "not a link")) {
            assertTrue(Links.resolve(u) is Links.Result.Refused, u)
        }
        assertTrue((Links.resolve("https://youtu.be/abc") as Links.Result.Refused).reason.contains("YouTube Studio"))
        // The internal testing switch lets platform links through, labelled with the site.
        assertEquals(Links.Result.Platform("https://youtu.be/abc", "YouTube"), Links.resolve("https://youtu.be/abc", allowPlatforms = true))
        assertEquals("TikTok", (Links.resolve("see https://vm.tiktok.com/x", true) as Links.Result.Platform).site)
        assertTrue(Links.resolve("https://example.com/v.mp4", true) is Links.Result.Download)
    }

    @Test
    fun contentTypes() {
        assertTrue(Links.looksLikeVideo("video/mp4"))
        assertTrue(Links.looksLikeVideo("application/octet-stream; charset=x"))
        assertTrue(Links.looksLikeVideo(null))
        assertFalse(Links.looksLikeVideo("text/html; charset=utf-8"))
    }
}
