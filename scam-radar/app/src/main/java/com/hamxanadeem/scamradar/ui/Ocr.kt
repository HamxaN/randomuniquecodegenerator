package com.hamxanadeem.scamradar.ui

import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

/** Reads the text in a screenshot, on the phone. */
object Ocr {
    fun read(context: Context, uri: Uri, done: (String?) -> Unit) {
        val image = runCatching { InputImage.fromFilePath(context, uri) }.getOrElse {
            done(null)
            return
        }
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(image)
            .addOnSuccessListener { result -> done(result.textBlocks.joinToString("\n") { it.text }) }
            .addOnFailureListener { done(null) }
            .addOnCompleteListener { recognizer.close() }
    }
}
