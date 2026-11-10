package com.hamxanadeem.spendwise

import android.app.Application
import com.hamxanadeem.spendwise.data.Store
import com.hamxanadeem.spendwise.ui.Alerts

class SpendwiseApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Alerts.createChannel(this)
        Store.ledger(this)
    }
}
