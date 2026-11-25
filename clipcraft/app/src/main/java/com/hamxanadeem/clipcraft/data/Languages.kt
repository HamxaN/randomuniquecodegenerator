package com.hamxanadeem.clipcraft.data

/** On-device speech models (Vosk, Apache 2.0), downloaded once on first use. */
data class SpeechModel(val code: String, val name: String, val url: String, val sizeMb: Int)

object Languages {
    val ALL = listOf(
        SpeechModel("en", "English", "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip", 40),
        SpeechModel("hi", "Hindi / Urdu (Hindi script)", "https://alphacephei.com/vosk/models/vosk-model-small-hi-0.22.zip", 42),
        SpeechModel("es", "Spanish", "https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip", 39),
        SpeechModel("fr", "French", "https://alphacephei.com/vosk/models/vosk-model-small-fr-0.22.zip", 41),
        SpeechModel("de", "German", "https://alphacephei.com/vosk/models/vosk-model-small-de-0.15.zip", 45),
        SpeechModel("pt", "Portuguese", "https://alphacephei.com/vosk/models/vosk-model-small-pt-0.3.zip", 31),
    )

    fun get(code: String): SpeechModel = ALL.firstOrNull { it.code == code } ?: ALL[0]
}
