package com.hamxanadeem.spendwise.ui

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL

/**
 * App lock state. The app locks when it leaves the screen and asks for the
 * fingerprint, face or screen lock when it comes back.
 */
object Lock {
    const val AUTHENTICATORS = BIOMETRIC_WEAK or DEVICE_CREDENTIAL

    var locked = true
    var started = 0

    /** Set before opening the camera, a file picker or the share sheet, so coming back doesn't ask again. */
    var leavingOnPurpose = false

    fun available(context: Context): Boolean =
        BiometricManager.from(context).canAuthenticate(AUTHENTICATORS) == BiometricManager.BIOMETRIC_SUCCESS
}
