package com.hamxanadeem.snapdoc.ui

import android.app.Activity
import android.net.Uri
import android.widget.Toast
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.hamxanadeem.snapdoc.R

/**
 * Google's on-device document scanner: camera or gallery, automatic edge
 * detection, cropping, rotation and clean-up filters, many pages at once.
 * Register it in onCreate; [onPages] gets the scanned page images.
 */
class Scanner(private val activity: AppCompatActivity, private val onPages: (List<Uri>) -> Unit) {

    private val launcher: ActivityResultLauncher<IntentSenderRequest> =
        activity.registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
            if (result.resultCode != Activity.RESULT_OK) return@registerForActivityResult
            val scan = GmsDocumentScanningResult.fromActivityResultIntent(result.data)
            val pages = scan?.pages?.map { it.imageUri }.orEmpty()
            if (pages.isNotEmpty()) onPages(pages)
        }

    fun start(pageLimit: Int = 50) {
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(pageLimit)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        GmsDocumentScanning.getClient(options)
            .getStartScanIntent(activity)
            .addOnSuccessListener { sender -> launcher.launch(IntentSenderRequest.Builder(sender).build()) }
            .addOnFailureListener { e ->
                val msg = if (e.message.isNullOrBlank()) activity.getString(R.string.scanner_unavailable)
                else activity.getString(R.string.scan_failed, e.message)
                Toast.makeText(activity, msg, Toast.LENGTH_LONG).show()
            }
    }
}
