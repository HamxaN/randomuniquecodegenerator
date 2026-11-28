package com.hamxanadeem.rewind.ads

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.hamxanadeem.rewind.data.Store

/**
 * The one-time "Remove ads" purchase through Google Play. Restored automatically on
 * reinstall (Play remembers it). Without Play (e.g. a sideloaded test build) the
 * button just says it isn't available.
 */
object Billing : PurchasesUpdatedListener {
    const val PRODUCT = "remove_ads"
    private const val TAG = "Billing"

    private lateinit var app: Context
    private var client: BillingClient? = null
    private var details: ProductDetails? = null
    private val main = Handler(Looper.getMainLooper())
    var onChange: (() -> Unit)? = null

    /** The price to show, once Play has told us. */
    val price: String? get() = details?.oneTimePurchaseOfferDetails?.formattedPrice

    fun start(context: Context) {
        if (client != null) return
        app = context.applicationContext
        val c = BillingClient.newBuilder(app)
            .setListener(this)
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .build()
        client = c
        c.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                    Log.w(TAG, "Billing unavailable: ${result.debugMessage}")
                    return
                }
                restore()
                loadDetails()
            }

            override fun onBillingServiceDisconnected() {
                Log.w(TAG, "Billing disconnected")
            }
        })
    }

    private fun loadDetails() {
        val c = client ?: return
        val params = QueryProductDetailsParams.newBuilder().setProductList(listOf(
            QueryProductDetailsParams.Product.newBuilder().setProductId(PRODUCT).setProductType(BillingClient.ProductType.INAPP).build()
        )).build()
        c.queryProductDetailsAsync(params) { result, list ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                details = list.firstOrNull()
                main.post { onChange?.invoke() }
            }
        }
    }

    /** Checks Play for an earlier purchase (new phone, reinstall). */
    fun restore() {
        val c = client ?: return
        c.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) handle(purchases)
        }
    }

    /** Opens Google Play's purchase sheet. Returns false if it isn't available. */
    fun buy(activity: Activity): Boolean {
        val c = client ?: return false
        val d = details ?: return false
        val flow = BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(
            BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(d).build()
        )).build()
        return c.launchBillingFlow(activity, flow).responseCode == BillingClient.BillingResponseCode.OK
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        if (result.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) handle(purchases)
    }

    private fun handle(purchases: List<Purchase>) {
        for (p in purchases) {
            if (PRODUCT !in p.products || p.purchaseState != Purchase.PurchaseState.PURCHASED) continue
            Store.setAdsRemoved(app, true)
            Ads.adsRemoved()
            if (!p.isAcknowledged) {
                client?.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.purchaseToken).build()) { r ->
                    if (r.responseCode != BillingClient.BillingResponseCode.OK) Log.w(TAG, "Acknowledge failed: ${r.debugMessage}")
                }
            }
            main.post { onChange?.invoke() }
        }
    }
}
