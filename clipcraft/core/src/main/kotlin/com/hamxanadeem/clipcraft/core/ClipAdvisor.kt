package com.hamxanadeem.clipcraft.core

import com.anthropic.client.AnthropicClient
import com.anthropic.client.okhttp.AnthropicOkHttpClient
import com.anthropic.core.JsonValue
import com.anthropic.errors.AnthropicServiceException
import com.anthropic.errors.AnthropicIoException
import com.anthropic.errors.UnauthorizedException
import com.anthropic.errors.RateLimitException
import com.anthropic.models.messages.JsonOutputFormat
import com.anthropic.models.messages.MessageCreateParams
import com.anthropic.models.messages.OutputConfig
import com.anthropic.models.messages.StopReason

/** What went wrong asking the AI, in words the app can show. */
class AdvisorException(message: String, cause: Throwable? = null) : Exception(message, cause)

/**
 * Asks Claude to find the moments most likely to do well as YouTube Shorts.
 * The model reads the timestamped transcript and returns clips as strict JSON.
 */
class ClipAdvisor(apiKey: String, private val model: String = MODEL) {

    companion object {
        const val MODEL = "claude-haiku-5-5"

        val SYSTEM = """
            You are a senior short-form video editor who has grown many YouTube Shorts, TikTok and Reels channels.
            You get a timestamped transcript of a longer video. Find the moments most likely to go viral as
            standalone vertical shorts.

            A great clip:
            - hooks in the first 2-3 seconds (a bold claim, a question, a surprise, a strong emotion or a punchline setup)
            - makes sense on its own without the rest of the video
            - has a payoff: an answer, a reveal, a laugh, a useful tip or a strong opinion
            - is 20-55 seconds long, starts at the beginning of a sentence and ends after a complete thought

            For each clip, write in the same language the speaker uses:
            - title: a curiosity-driven YouTube Shorts title, at most 70 characters, no clickbait lies
            - hook: the opening line to show on screen, at most 8 words
            - description: 1-2 sentences for the YouTube description
            - hashtags: 4-7 relevant hashtags without spaces
            - score: 1-100, how likely it is to perform, judged strictly and relative to the other clips
            - reason: one sentence on why it works

            Prefer moments carried by the speaker's own words. Gaps in the transcript are often music
            or other people's audio, which risk copyright claims, so avoid clips built around them.

            Use the transcript's own timestamps (seconds) for start and end. Don't invent content that isn't there.
            Return the clips best first, without overlaps.
        """.trimIndent()

        /** The JSON schema the reply must match. */
        fun schema(): JsonOutputFormat.Schema {
            val str = mapOf("type" to "string")
            val num = mapOf("type" to "number")
            val clip = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "start" to num, "end" to num, "title" to str, "hook" to str, "description" to str,
                    "hashtags" to mapOf("type" to "array", "items" to str),
                    "score" to mapOf("type" to "integer"), "reason" to str,
                ),
                "required" to listOf("start", "end", "title", "hook", "description", "hashtags", "score", "reason"),
                "additionalProperties" to false,
            )
            return JsonOutputFormat.Schema.builder()
                .putAdditionalProperty("type", JsonValue.from("object"))
                .putAdditionalProperty("properties", JsonValue.from(mapOf("clips" to mapOf("type" to "array", "items" to clip))))
                .putAdditionalProperty("required", JsonValue.from(listOf("clips")))
                .putAdditionalProperty("additionalProperties", JsonValue.from(false))
                .build()
        }

        fun prompt(t: Transcript, count: Int, notes: String): String = buildString {
            append("Video length: ").append(Transcript.format(t.duration)).append('\n')
            append("Find up to ").append(count).append(" clips.\n")
            if (notes.isNotBlank()) append("Creator's notes about the video and audience: ").append(notes.trim()).append('\n')
            append("\n<transcript>\n").append(t.forPrompt()).append("</transcript>")
        }
    }

    private val client: AnthropicClient = AnthropicOkHttpClient.builder().apiKey(apiKey).build()

    /** Blocks while the model works; call it off the main thread. */
    fun suggest(t: Transcript, count: Int = 5, notes: String = ""): List<ClipPlan> {
        if (t.words.size < 20) throw AdvisorException("Not enough speech was found in this video to pick clips.")
        val params = MessageCreateParams.builder()
            .model(model)
            .maxTokens(8000L)
            .system(SYSTEM)
            .outputConfig(
                OutputConfig.builder()
                    .effort(OutputConfig.Effort.MEDIUM)
                    .format(JsonOutputFormat.builder().schema(schema()).build())
                    .build()
            )
            .addUserMessage(prompt(t, count, notes))
            .build()
        val msg = try {
            client.messages().create(params)
        } catch (e: UnauthorizedException) {
            throw AdvisorException("Your Anthropic API key was rejected. Check it in Settings.", e)
        } catch (e: RateLimitException) {
            throw AdvisorException("The AI is busy (rate limited). Try again in a minute.", e)
        } catch (e: AnthropicServiceException) {
            throw AdvisorException("The AI request failed (${e.statusCode()}). Try again.", e)
        } catch (e: AnthropicIoException) {
            throw AdvisorException("Couldn't reach the AI. Check your internet connection.", e)
        }
        when (msg.stopReason().orElse(null)) {
            StopReason.REFUSAL -> throw AdvisorException("The AI declined to analyse this video.")
            StopReason.MAX_TOKENS -> throw AdvisorException("The AI's answer was cut off. Try asking for fewer clips.")
            else -> Unit
        }
        val text = msg.content().mapNotNull { b -> b.text().orElse(null)?.text() }.joinToString("")
        val plans = try {
            Clips.fromJson(text)
        } catch (e: Exception) {
            throw AdvisorException("The AI's answer couldn't be read. Try again.", e)
        }
        return Clips.tidy(plans, t, count)
    }
}
