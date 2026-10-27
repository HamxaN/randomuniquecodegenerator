package com.hamxanadeem.wigglewars.ui

import android.app.Activity
import android.os.Build
import android.view.View
import android.view.WindowManager
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/** Full-screen helpers shared by every screen. */
object Screen {

    /** Hides the status and navigation bars; a swipe from the edge shows them for a moment. */
    fun immersive(activity: Activity) {
        WindowCompat.setDecorFitsSystemWindows(activity.window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // Use the space beside the camera cutout too.
            activity.window.attributes = activity.window.attributes.apply {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        WindowInsetsControllerCompat(activity.window, activity.window.decorView).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }
    }

    /** Keeps [view]'s content clear of the camera cutout, any visible bars and the keyboard. */
    fun padForInsets(view: View) {
        val left = view.paddingLeft
        val top = view.paddingTop
        val right = view.paddingRight
        val bottom = view.paddingBottom
        ViewCompat.setOnApplyWindowInsetsListener(view) { v, insets ->
            val i = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout() or WindowInsetsCompat.Type.ime())
            v.setPadding(left + i.left, top + i.top, right + i.right, bottom + i.bottom)
            insets
        }
    }
}
