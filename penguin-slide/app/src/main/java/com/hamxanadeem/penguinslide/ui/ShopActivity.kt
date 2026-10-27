package com.hamxanadeem.penguinslide.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.hamxanadeem.penguinslide.R
import com.hamxanadeem.penguinslide.ads.AdsManager
import com.hamxanadeem.penguinslide.core.Progress
import com.hamxanadeem.penguinslide.core.SkinCatalog
import com.hamxanadeem.penguinslide.data.ProgressStore
import com.hamxanadeem.penguinslide.fx.GameSounds
import com.hamxanadeem.penguinslide.fx.Sounds

/** Spend fish on outfits; a rewarded ad gives free fish. */
class ShopActivity : AppCompatActivity() {

    private lateinit var store: ProgressStore
    private lateinit var progress: Progress
    private lateinit var list: LinearLayout
    private lateinit var fishText: TextView
    private lateinit var freeFish: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_shop)
        store = ProgressStore(this)
        progress = store.load()
        list = findViewById(R.id.skinList)
        fishText = findViewById(R.id.fishText)
        freeFish = findViewById(R.id.freeFishButton)
        freeFish.text = getString(R.string.free_fish, FREE_FISH)
        freeFish.setOnClickListener {
            freeFish.isEnabled = false
            AdsManager.showRewarded(
                this,
                onRewarded = {
                    Sounds.play(GameSounds.CHECKPOINT)
                    update(progress.addFish(FREE_FISH))
                },
                onFinished = { render() },
            )
        }
        findViewById<Button>(R.id.backButton).setOnClickListener { finish() }
        render()
    }

    private fun update(newProgress: Progress) {
        progress = newProgress
        store.save(progress)
        render()
    }

    private fun render() {
        fishText.text = getString(R.string.fish_format, progress.fish)
        freeFish.isEnabled = AdsManager.isRewardedReady()
        list.removeAllViews()
        val inflater = LayoutInflater.from(this)
        for (skin in SkinCatalog.all) {
            val row = inflater.inflate(R.layout.item_skin, list, false)
            row.findViewById<PenguinPreviewView>(R.id.preview).skin = skin
            row.findViewById<TextView>(R.id.skinName).text = skin.name
            val button = row.findViewById<Button>(R.id.skinAction)
            when {
                skin.id == progress.selectedSkin -> {
                    button.setText(R.string.wearing)
                    button.isEnabled = false
                    button.alpha = 0.6f
                }
                skin.id in progress.ownedSkins -> {
                    button.setText(R.string.wear)
                    button.setOnClickListener {
                        Sounds.play(GameSounds.TAP)
                        update(progress.select(skin))
                    }
                }
                else -> {
                    button.text = getString(R.string.price_format, skin.price)
                    button.setOnClickListener {
                        val bought = progress.buy(skin)
                        if (bought != null) {
                            Sounds.play(GameSounds.PERFECT)
                            update(bought)
                        } else {
                            Toast.makeText(this, R.string.need_more_fish, Toast.LENGTH_SHORT).show()
                        }
                    }
                }
            }
            list.addView(row)
        }
    }

    private companion object {
        const val FREE_FISH = 40
    }
}
