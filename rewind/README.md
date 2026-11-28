# Rewind Defense

A tower defense game for Android where **time is your weapon**.

## The idea

Once every wave you can **rewind 10 seconds**. The battle jumps back, and purple
**ghosts** replay what was about to happen: where each enemy was heading, and how
many lives you were about to lose. Now you know the future. Sell the tower in the
wrong place, build where the ghosts slipped through, then face the same 10
seconds again.

The simulation is fully deterministic. If you change nothing, the ghosts and the
real enemies move together exactly, so any difference is caused by your new
choices. I don't know of another game built around this mechanic.

## Playing

* **8 maps**, from Meadow to The Gauntlet, with 10–17 waves each. Each map's road
  is drawn in miniature on the map picker.
* **5 towers**, each with three levels. Towers can be upgraded and sold for 70% of
  what you spent.

  | Tower | What it does | Unlocks |
  |---|---|---|
  | Bolt | Fast single shots, hits air | From the start |
  | Cannon | Splash damage, can't hit air | From the start |
  | Frost | Slows enemies by half | After the first map |
  | Tesla | Lightning that chains to 3+ enemies | After two maps |
  | Sniper | Long range, aims at the toughest enemy | After four maps |

* **8 enemy types:** Scouts, Grunts, Swarms, Flyers, armoured Tanks, Splitters
  (which burst into swarms), Wardens (which regenerate), and the Colossus boss.
* **Stars and crystals.** You earn up to 3 stars per map, based on lives left.
  Stars give crystals, which you spend on **Research**: tower damage, starting
  gold, and a second rewind per wave.
* **Speed and help:** play at 1×, 2× or 3× speed. A how-to-play screen appears the
  first time, and the title screen shows a live demo battle.
* **No downloads:** all art is drawn in code and every sound is synthesised on the
  phone, so the APK stays small.

## Ads and the "Remove ads" purchase

The ads follow a rewarded-first model with strict limits. The rules live in one
place, `app/src/main/java/com/hamxanadeem/rewind/ads/Ads.kt`.

* **Consent first.** Google's User Messaging Platform shows the GDPR/US-states
  consent form where required, and no ad is requested until consent allows it.
  Where the law requires it, a "Ad privacy choices" button appears in Settings.
* **Rewarded videos are always the player's choice:**
  * one extra rewind per wave, once your free one is used;
  * a revive with 10 lives, once per map;
  * double crystals after a win.
* **Interstitials** appear only between maps, never during a battle. They are
  never shown:
  * in a player's first two games;
  * more than once per two finished maps;
  * more than once per 3 minutes;
  * right after the player chose to watch a video.
* **Banners** appear only on the menus, never over the game.
* **Remove ads** is a one-time Google Play purchase (`remove_ads`). It removes
  banners and interstitials; videos stay available as an option. Play restores
  it after a reinstall, and Settings has a Restore button.

Debug builds always use **Google's test ad units**, so you can't get your AdMob
account flagged while testing. Release builds use your real IDs, read from
secrets.

### Setting up AdMob (once)

1. In [AdMob](https://admob.google.com), add an Android app, then create three ad
   units: **Banner**, **Interstitial** and **Rewarded**.
2. In AdMob, go to **Privacy & messaging** and create a **GDPR** message and a
   **US states** message for the app. The consent form uses these.
3. Add these repository secrets:
   * `REWIND_ADMOB_APP_ID` (looks like `ca-app-pub-…~…`)
   * `REWIND_ADMOB_BANNER_ID`
   * `REWIND_ADMOB_INTERSTITIAL_ID`
   * `REWIND_ADMOB_REWARDED_ID`
4. Publish an `app-ads.txt` file on your developer website, with the line AdMob
   gives you, and put the same website on the Play store listing.
5. In Play Console:
   * under **Monetize → In-app products**, create the managed product
     `remove_ads` and set its price;
   * fill in the **Data safety** form: the app uses the advertising ID and the ads
     SDK collects device data for ads;
   * answer **Contains ads: Yes**.

## Project layout

```
rewind/
  core/  Pure Kotlin, unit-tested, no Android. Covers:
         - levels and waves;
         - the deterministic simulation;
         - rewind with ghosts;
         - progress and research;
         - a bot player used for balance tests.
  app/   The Android app:
         - SurfaceView renderer and effects;
         - menus, level select and game screen;
         - synthesised sound;
         - AdMob with UMP consent, and Play Billing.
```

## Build and test

```bash
./gradlew -p rewind coreTest                 # rules, rewind and balance tests
./gradlew -p rewind :app:lintDebug :app:assembleDebug
```

The balance test has a simple bot play every map with only the towers unlocked so
far:

* it must win maps 1–7;
* the final map must need a little research to beat.

CI (`.github/workflows/rewind-ci.yml`) runs everything and uploads a debug APK.

To release to Play, push a tag such as `rewind-v1.0.0`. This needs these secrets:

* `REWIND_KEYSTORE_BASE64`
* `REWIND_KEYSTORE_PASSWORD`
* `REWIND_KEY_ALIAS`
* `REWIND_KEY_PASSWORD`
* the four `REWIND_ADMOB_*` IDs
* `PLAY_SERVICE_ACCOUNT_JSON`
