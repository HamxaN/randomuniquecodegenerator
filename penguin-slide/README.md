# Penguin Slide 🐧

A one-touch slide-and-fly game, in the spirit of the classic *Tiny Wings*. A little
penguin in a scarf belly-slides down endless snowy hills. Hold to dive into the valleys
and pick up speed, let go on the uphills to launch into the sky, and hold in the air to
do backflips. Land parallel to the slope for a speed boost. Reach checkpoints before
the sun sets.

## Gameplay
| Action | How |
|---|---|
| Dive | Hold while sliding downhill: more speed |
| Fly | Let go on an uphill: the penguin launches off the crest |
| Flip | Hold in the air: backflips worth +100 each; land upright or wipe out |
| Perfect landing | Touch down parallel to the slope: speed boost and +25 |
| Fever | 3 perfect landings in a row: faster top speed and a rainbow trail |
| Fish | Arcs of fish over the hills: points, and the currency for outfits |
| Sunset clock | 45 s to start. Each checkpoint (every 500 m) adds time; the sky turns to sunset as time runs out |

**Outfits:** six looks to buy with fish (beanie, party hat, DJ headphones, top hat, crown).

## Graphics and feel
- Everything is drawn in code, with no image files: a sky that fades from day to sunset
  to dusk with stars, a sinking sun, two layers of parallax mountains, clouds, and
  smooth snowy hills with a layered edge.
- The penguin flaps its flippers in the air, flattens when diving, blinks, its scarf
  streams in the wind, and it goes dizzy after a wipeout.
- Snow spray, landing puffs, gold sparkles, speed lines, a fever trail, and a camera
  that zooms out for big jumps.
- The menu shows an autopilot penguin sliding behind the buttons.
- Sounds are synthesised in code, and landings give haptic feedback.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **+15 seconds** after time runs out (once per run), **double fish** after a run, **+40 fish** in the outfit shop |
| Interstitial | Between runs only, at most every 2 runs and 2 minutes, never in the first 2 |
| Banner | Menu only |

## Build and test
```bash
./gradlew -p penguin-slide coreTest            # physics and rules tests, no Android SDK needed
./gradlew -p penguin-slide :app:assembleDebug  # APK in penguin-slide/app/build/outputs/apk/debug/
```

`core/` holds the physics: terrain generation, the penguin's sliding, launching, flips
and landings, the run's clock, checkpoints, fish and scoring, and outfits. It is unit
tested, including simulated runs. `app/` holds the rendering and the screens.

## Releasing
Same as the other games: create the AdMob app and ad units, the Play Console app
`com.hamxanadeem.penguinslide`, and a signing key. Add the secrets `PENGUIN_KEYSTORE_BASE64`,
`PENGUIN_KEYSTORE_PASSWORD`, `PENGUIN_KEY_ALIAS`, `PENGUIN_KEY_PASSWORD`, `PENGUIN_ADMOB_APP_ID`,
`PENGUIN_ADMOB_BANNER_ID`, `PENGUIN_ADMOB_INTERSTITIAL_ID` and `PENGUIN_ADMOB_REWARDED_ID`, plus the
shared `PLAY_SERVICE_ACCOUNT_JSON`. Then push a tag such as `penguin-v1.0.0`. The full
walkthrough is in `docs/PLAY_STORE_RELEASE.md` at the repository root. Upload the first
bundle by hand.
