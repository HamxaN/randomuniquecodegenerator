package com.hamxanadeem.rewind

import android.app.Application
import com.hamxanadeem.rewind.audio.Sfx
import com.hamxanadeem.rewind.data.Store

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        Sfx.enabled = Store.sound(this)
        Sfx.init(this)
    }
}
