package com.hamxanadeem.rewind.ads

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdListener
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
import com.hamxanadeem.rewind.BuildConfig
import com.hamxanadeem.rewind.data.Store
import java.util.concurrent.atomic.AtomicBoolean

/**
 * All advertising, in one place, with player-friendly rules:
 *
 * - Google's consent form (GDPR / US states) is shown first where required, and ads
 *   are only requested once consent allows it. Privacy choices can be changed later.
 * - **Rewarded** ads are always the player's choice: an extra rewind, a revive, or
 *   double crystals. They work even after buying "Remove ads".
 * - **Interstitials** only between levels, never during play, never in the first two
 *   games, at most one per two finished levels and 3 minutes, and not right after
 *   the player chose to watch a rewarded ad.
 * - **Banners** only on menus, never over the game.
 *
 * Ad unit IDs come from BuildConfig: Google's test units in debug builds and until
 * real ones are configured (see README).
 */
object Ads {
    private const val TAG = "Ads"
    private const val MIN_GAP_MS = 180_000L
    private const val LEVELS_BETWEEN = 2
    private const val FIRST_GAMES_FREE = 2

    private val main = Handler(Looper.getMainLooper())
    private val started = AtomicBoolean(false)
    private var consent: ConsentInformation? = null
    private var interstitial: InterstitialAd? = null
    private var rewarded: RewardedAd? = null
    private var loadingInterstitial = false
    private var loadingRewarded = false
    private var lastInterstitial = 0L
    private var levelsSinceInterstitial = 0
    private var rewardedThisLevel = false

    /** Runs the consent flow (if needed) and starts the ads SDK. Call from the first screen. */
    fun start(activity: Activity, onReady: () -> Unit = {}) {
        val info = UserMessagingPlatform.getConsentInformation(activity)
        consent = info
        val params = ConsentRequestParameters.Builder().build()
        info.requestConsentInfoUpdate(activity, params, {
            UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { error ->
                if (error != null) Log.w(TAG, "Consent form: ${error.message}")
                if (info.canRequestAds()) initSdk(activity)
                onReady()
            }
        }, { error ->
            Log.w(TAG, "Consent info: ${error.message}")
            onReady()
        })
        // Consent from an earlier session lets ads start straight away.
        if (info.canRequestAds()) initSdk(activity)
    }

    private fun initSdk(context: Context) {
        if (started.getAndSet(true)) return
        val app = context.applicationContext
        Thread {
            MobileAds.initialize(app) {}
            main.post {
                loadRewarded(app)
                if (!Store.adsRemoved(app)) loadInterstitial(app)
            }
        }.start()
    }

    val canRequestAds: Boolean get() = consent?.canRequestAds() == true

    /** True where the law requires a way to change ad privacy choices (show the button). */
    val privacyOptionsRequired: Boolean
        get() = consent?.privacyOptionsRequirementStatus == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

    fun showPrivacyOptions(activity: Activity) {
        UserMessagingPlatform.showPrivacyOptionsForm(activity) { error ->
            if (error != null) Log.w(TAG, "Privacy options: ${error.message}")
        }
    }

    private fun request() = AdRequest.Builder().build()

    // ---- Rewarded -------------------------------------------------------------------

    private fun loadRewarded(context: Context) {
        if (!canRequestAds || rewarded != null || loadingRewarded) return
        loadingRewarded = true
        RewardedAd.load(context, BuildConfig.AD_REWARDED, request(), object : RewardedAdLoadCallback() {
            override fun onAdLoaded(ad: RewardedAd) {
                rewarded = ad
                loadingRewarded = false
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                loadingRewarded = false
                Log.w(TAG, "Rewarded failed: ${error.message}")
                // Try again later, gently.
                main.postDelayed({ loadRewarded(context) }, 60_000)
            }
        })
    }

    fun rewardedReady(): Boolean = rewarded != null

    /** Shows a rewarded ad; [onReward] runs only if the player watched it through. */
    fun showRewarded(activity: Activity, onReward: () -> Unit, onClosed: () -> Unit = {}) {
        val ad = rewarded ?: run {
            loadRewarded(activity)
            onClosed()
            return
        }
        rewarded = null
        var earned = false
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                loadRewarded(activity.applicationContext)
                if (earned) onReward()
                onClosed()
            }

            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                loadRewarded(activity.applicationContext)
                onClosed()
            }
        }
        ad.show(activity) {
            earned = true
            rewardedThisLevel = true
        }
    }

    // ---- Interstitial -----------------------------------------------------------------

    private fun loadInterstitial(context: Context) {
        if (!canRequestAds || interstitial != null || loadingInterstitial || Store.adsRemoved(context)) return
        loadingInterstitial = true
        InterstitialAd.load(context, BuildConfig.AD_INTERSTITIAL, request(), object : InterstitialAdLoadCallback() {
            override fun onAdLoaded(ad: InterstitialAd) {
                interstitial = ad
                loadingInterstitial = false
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                loadingInterstitial = false
                Log.w(TAG, "Interstitial failed: ${error.message}")
            }
        })
    }

    /** Call when a level ends (win or lose). */
    fun levelFinished() {
        levelsSinceInterstitial++
    }

    /** Call when a level starts. */
    fun levelStarted() {
        rewardedThisLevel = false
    }

    /**
     * Between levels: maybe shows an interstitial (within the caps), then runs [next].
     * [gamesPlayed] is the player's total finished games.
     */
    fun betweenLevels(activity: Activity, gamesPlayed: Int, next: () -> Unit) {
        val ad = interstitial
        val now = SystemClock.elapsedRealtime()
        val allowed = ad != null && !Store.adsRemoved(activity) && gamesPlayed >= FIRST_GAMES_FREE &&
            levelsSinceInterstitial >= LEVELS_BETWEEN && (lastInterstitial == 0L || now - lastInterstitial >= MIN_GAP_MS) &&
            !rewardedThisLevel
        if (!allowed || ad == null) {
            loadInterstitial(activity.applicationContext)
            next()
            return
        }
        interstitial = null
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                lastInterstitial = SystemClock.elapsedRealtime()
                levelsSinceInterstitial = 0
                loadInterstitial(activity.applicationContext)
                next()
            }

            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                loadInterstitial(activity.applicationContext)
                next()
            }
        }
        ad.show(activity)
    }

    // ---- Banner -------------------------------------------------------------------------

    /** Fills [container] with an adaptive banner on menu screens (hidden after "Remove ads"). */
    fun banner(activity: Activity, container: FrameLayout): AdView? {
        container.removeAllViews()
        if (Store.adsRemoved(activity) || !canRequestAds) {
            container.visibility = View.GONE
            return null
        }
        val widthDp = (activity.resources.displayMetrics.widthPixels / activity.resources.displayMetrics.density).toInt()
        val view = AdView(activity)
        view.adUnitId = BuildConfig.AD_BANNER
        view.setAdSize(AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(activity, minOf(widthDp, 728)))
        view.adListener = object : AdListener() {
            override fun onAdLoaded() {
                container.visibility = View.VISIBLE
            }

            override fun onAdFailedToLoad(error: LoadAdError) {
                container.visibility = View.GONE
            }
        }
        container.addView(view)
        view.loadAd(request())
        return view
    }

    /** After buying "Remove ads": drop the loaded interstitial. */
    fun adsRemoved() {
        interstitial = null
    }
}
