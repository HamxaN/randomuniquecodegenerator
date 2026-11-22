package com.hamxanadeem.scamradar.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.widget.NestedScrollView
import com.google.android.material.appbar.MaterialToolbar
import com.hamxanadeem.scamradar.R
import com.hamxanadeem.scamradar.core.Guide
import com.hamxanadeem.scamradar.data.Store

/** The common scams, an example of each, and how to spot it. */
class LearnActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_list)
        Ui.fitSystemBars(findViewById(R.id.root))
        val toolbar = findViewById<MaterialToolbar>(R.id.toolbar)
        toolbar.setTitle(R.string.learn)
        toolbar.setNavigationOnClickListener { finish() }
        findViewById<View>(R.id.list).visibility = View.GONE
        val box = findViewById<LinearLayout>(R.id.lessons)
        findViewById<NestedScrollView>(R.id.lessons_scroll).visibility = View.VISIBLE
        val urdu = Store.urdu(this)
        for (l in Guide.LESSONS) {
            val v = LayoutInflater.from(this).inflate(R.layout.item_lesson, box, false)
            v.findViewById<TextView>(R.id.title).text = if (urdu) l.type.ur else l.type.en
            v.findViewById<TextView>(R.id.example).text = l.exampleEn
            v.findViewById<TextView>(R.id.sign).apply {
                text = if (urdu) l.signUr else l.signEn
                textDirection = if (urdu) View.TEXT_DIRECTION_RTL else View.TEXT_DIRECTION_LTR
            }
            box.addView(v)
        }
    }
}
