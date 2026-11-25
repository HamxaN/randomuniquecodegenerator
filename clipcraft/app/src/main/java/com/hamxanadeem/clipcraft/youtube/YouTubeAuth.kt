package com.hamxanadeem.clipcraft.youtube

import android.app.Activity
import android.content.Intent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Scope

/**
 * Asks the user's permission to upload to their YouTube channel (Google sign-in with the
 * youtube.upload scope) and hands back a short-lived access token. Requires an OAuth
 * client for this app in Google Cloud (see README).
 */
object YouTubeAuth {
    const val SCOPE = "https://www.googleapis.com/auth/youtube.upload"

    /** Read-only access lets the app check whether YouTube accepted the upload. */
    const val READ_SCOPE = "https://www.googleapis.com/auth/youtube.readonly"

    private fun request() = AuthorizationRequest.builder().setRequestedScopes(listOf(Scope(SCOPE), Scope(READ_SCOPE))).build()

    /** Calls [onToken] with a token, or launches the consent screen through [consent] first. */
    fun authorize(activity: Activity, consent: ActivityResultLauncher<IntentSenderRequest>, onToken: (String) -> Unit, onError: (String) -> Unit) {
        Identity.getAuthorizationClient(activity).authorize(request())
            .addOnSuccessListener { result ->
                if (result.hasResolution()) {
                    val pi = result.pendingIntent
                    if (pi == null) onError("Google sign-in couldn't start.") else consent.launch(IntentSenderRequest.Builder(pi.intentSender).build())
                } else {
                    tokenOf(result, onToken, onError)
                }
            }
            .addOnFailureListener { e -> onError(explain(e)) }
    }

    /** Call with the result of the consent screen. */
    fun fromConsent(activity: Activity, data: Intent?, onToken: (String) -> Unit, onError: (String) -> Unit) {
        try {
            val result = Identity.getAuthorizationClient(activity).getAuthorizationResultFromIntent(data)
            tokenOf(result, onToken, onError)
        } catch (e: ApiException) {
            onError(explain(e))
        }
    }

    private fun tokenOf(r: AuthorizationResult, onToken: (String) -> Unit, onError: (String) -> Unit) {
        val token = r.accessToken
        if (token.isNullOrEmpty()) onError("Google didn't grant upload access.") else onToken(token)
    }

    private fun explain(e: Exception): String {
        val code = (e as? ApiException)?.statusCode
        return when (code) {
            CommonStatusCodes.DEVELOPER_ERROR ->
                "YouTube upload isn't set up for this build yet. Add an Android OAuth client for this app in Google Cloud (see README)."
            CommonStatusCodes.NETWORK_ERROR -> "No internet connection."
            CommonStatusCodes.CANCELED -> "Sign-in was cancelled."
            else -> "Google sign-in failed: ${e.message ?: "unknown error"}"
        }
    }
}
