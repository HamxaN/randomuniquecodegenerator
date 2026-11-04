package com.hamxanadeem.snapdoc.ads

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.FrameLayout
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.MobileAds
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import com.hamxanadeem.snapdoc.BuildConfig
import java.util.concurrent.atomic.AtomicBoolean

/**
 * The app's only ads: an anchored adaptive banner at the bottom of the
 * document screens. No interstitials, no rewarded ads, nothing full-screen.
 * Also shows Google's consent form where the law requires it (EEA, UK).
 */
object AdsManager {

    private const val TAG = "AdsManager"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val sdkStarted = AtomicBoolean(false)
    private var ready = false
    private val readyCallbacks = mutableListOf<() -> Unit>()

    /** Asks for consent when needed, then starts the SDK. Call from the launcher activity. */
    fun initialize(activity: Activity) {
        val consent = UserMessagingPlatform.getConsentInformation(activity)
        consent.requestConsentInfoUpdate(
            activity,
            ConsentRequestParameters.Builder().build(),
            {
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { error ->
                    if (error != null) Log.w(TAG, "Consent form error: ${error.message}")
                    if (consent.canRequestAds()) startSdk(activity)
                }
            },
            { error ->
                Log.w(TAG, "Consent info update failed: ${error.message}")
                if (consent.canRequestAds()) startSdk(activity)
            },
        )
        // Consent given in an earlier session lets us start right away.
        if (consent.canRequestAds()) startSdk(activity)
    }

    fun isPrivacyOptionsRequired(context: Context): Boolean =
        UserMessagingPlatform.getConsentInformation(context).privacyOptionsRequirementStatus ==
            ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

    fun showPrivacyOptions(activity: Activity) {
        UserMessagingPlatform.showPrivacyOptionsForm(activity) { error ->
            if (error != null) Log.w(TAG, "Privacy options error: ${error.message}")
        }
    }

    private fun startSdk(context: Context) {
        if (!sdkStarted.compareAndSet(false, true)) return
        val app = context.applicationContext
        // Google recommends initialising off the main thread.
        Thread {
            MobileAds.initialize(app) {
                mainHandler.post {
                    ready = true
                    readyCallbacks.forEach { it() }
                    readyCallbacks.clear()
                }
            }
        }.start()
    }

    /** Fills [container] with a banner as wide as the screen. */
    fun loadBanner(activity: Activity, container: FrameLayout) {
        val load = {
            if (!activity.isFinishing && !activity.isDestroyed) {
                val metrics = activity.resources.displayMetrics
                val widthDp = (metrics.widthPixels / metrics.density).toInt()
                val adView = AdView(activity).apply {
                    setAdSize(AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(activity, widthDp))
                    adUnitId = BuildConfig.ADMOB_BANNER_ID
                }
                container.removeAllViews()
                container.addView(adView)
                adView.loadAd(AdRequest.Builder().build())
            }
        }
        if (ready) load() else readyCallbacks += load
    }
}
