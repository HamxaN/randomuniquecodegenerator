package com.hamxanadeem.penguinslide.ads

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.widget.FrameLayout
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import com.hamxanadeem.penguinslide.BuildConfig
import com.hamxanadeem.penguinslide.core.AdPolicy
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Owns everything to do with ads: the consent form (required by Google for users
 * in the EEA and UK), starting the Mobile Ads SDK, and loading and showing ads.
 */
object AdsManager {

    private const val TAG = "AdsManager"

    val policy = AdPolicy()

    private val mainHandler = Handler(Looper.getMainLooper())
    private val sdkStarted = AtomicBoolean(false)
    private var ready = false
    private val readyCallbacks = mutableListOf<() -> Unit>()

    private var interstitial: InterstitialAd? = null
    private var rewarded: RewardedAd? = null
    private var loadingInterstitial = false
    private var loadingRewarded = false
    private var lastInterstitialAt: Long? = null

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
                    loadInterstitial(app)
                    loadRewarded(app)
                    readyCallbacks.forEach { it() }
                    readyCallbacks.clear()
                }
            }
        }.start()
    }

    private fun whenReady(block: () -> Unit) {
        if (ready) block() else readyCallbacks += block
    }

    fun loadBanner(activity: Activity, container: FrameLayout) {
        whenReady {
            if (activity.isFinishing || activity.isDestroyed) return@whenReady
            val adView = AdView(activity).apply {
                setAdSize(AdSize.BANNER)
                adUnitId = BuildConfig.ADMOB_BANNER_ID
            }
            container.removeAllViews()
            container.addView(adView)
            adView.loadAd(AdRequest.Builder().build())
        }
    }

    private fun loadInterstitial(context: Context) {
        if (!ready || interstitial != null || loadingInterstitial) return
        loadingInterstitial = true
        InterstitialAd.load(
            context,
            BuildConfig.ADMOB_INTERSTITIAL_ID,
            AdRequest.Builder().build(),
            object : InterstitialAdLoadCallback() {
                override fun onAdLoaded(ad: InterstitialAd) {
                    interstitial = ad
                    loadingInterstitial = false
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    Log.w(TAG, "Interstitial failed to load: ${error.message}")
                    loadingInterstitial = false
                }
            },
        )
    }

    private fun loadRewarded(context: Context) {
        if (!ready || rewarded != null || loadingRewarded) return
        loadingRewarded = true
        RewardedAd.load(
            context,
            BuildConfig.ADMOB_REWARDED_ID,
            AdRequest.Builder().build(),
            object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    rewarded = ad
                    loadingRewarded = false
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    Log.w(TAG, "Rewarded ad failed to load: ${error.message}")
                    loadingRewarded = false
                }
            },
        )
    }

    fun isRewardedReady(): Boolean = rewarded != null

    /**
     * Shows an interstitial between games if [policy] allows one and one is loaded.
     * [onFinished] always runs, with `true` if an ad was shown.
     */
    fun maybeShowInterstitial(
        activity: Activity,
        gamesPlayed: Int,
        gamesSinceInterstitial: Int,
        onFinished: (shown: Boolean) -> Unit,
    ) {
        val ad = interstitial
        val now = SystemClock.elapsedRealtime()
        if (ad == null || !policy.shouldShowInterstitial(gamesPlayed, gamesSinceInterstitial, now, lastInterstitialAt)) {
            loadInterstitial(activity.applicationContext)
            onFinished(false)
            return
        }
        interstitial = null
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                lastInterstitialAt = SystemClock.elapsedRealtime()
                loadInterstitial(activity.applicationContext)
                onFinished(true)
            }

            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                Log.w(TAG, "Interstitial failed to show: ${error.message}")
                loadInterstitial(activity.applicationContext)
                onFinished(false)
            }
        }
        ad.show(activity)
    }

    /**
     * Shows a rewarded ad. [onRewarded] runs only if the player watched long enough
     * to earn the reward; [onFinished] runs when the ad closes or fails.
     */
    fun showRewarded(activity: Activity, onRewarded: () -> Unit, onFinished: () -> Unit) {
        val ad = rewarded
        if (ad == null) {
            loadRewarded(activity.applicationContext)
            onFinished()
            return
        }
        rewarded = null
        var earned = false
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                loadRewarded(activity.applicationContext)
                if (earned) onRewarded()
                onFinished()
            }

            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                Log.w(TAG, "Rewarded ad failed to show: ${error.message}")
                loadRewarded(activity.applicationContext)
                onFinished()
            }
        }
        ad.show(activity) { earned = true }
    }
}
