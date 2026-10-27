# Idle Bakery 🧁

A cozy idle tycoon. Tap the oven to bake cookies, sell them, and reinvest. Unlock
cupcakes, donuts, croissants, pies, layer cakes, macarons and wedding cakes. Hire
bakers to run each counter by themselves, so the bakery keeps earning while you're
away. Idle games bring players back every day and have some of the highest ad
earnings per player of any genre.

## How it plays
| Feature | Details |
|---|---|
| 8 stations | Each one costs more and earns more, from Cookies (0.6 s batches) to Wedding Cakes (25 min batches) |
| Upgrades | Prices grow exponentially. Buy ×1, ×10, ×100 or MAX |
| Milestones | Levels 25, 50, 100, 200, 300, 400 and 500 each **double** a station's profit |
| Bakers (managers) | Hire one to run a station automatically forever |
| Offline earnings | Managed stations keep baking for up to 4 hours while the app is closed: "Welcome back! You earned…" |
| Franchise (prestige) | Start over in a new city for ⭐ stars, each worth +5% income forever |

## Graphics and feel
- Hand-painted pastries for every station, all drawn in code: chocolate-chip cookies,
  a swirl-frosted cupcake with a cherry, sprinkle donuts, a flaky croissant, a lattice
  pie, a layer cake with a flickering candle, a macaron stack and a three-tier
  wedding cake.
- A striped shop awning, warm cream and cocoa colours, and progress bars that fill
  as each batch bakes.
- Pastries bounce when a batch comes out, "+amount" floats up, and gold coins fly to
  the money counter, which bumps as they land.
- A chef with a tall hat waves a whisk at each managed station. A pulsing "TAP!" shows
  new players what to do.
- Sounds are synthesised in code, with haptic feedback.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **2× income for 30 minutes** (stacks up to 4 hours); **double offline earnings** on "Welcome back" |
| Banner | Bottom of the screen |
| Interstitial | None. Idle players stay longer without them, and rewarded ads earn more here |

## Build and test
```bash
./gradlew -p idle-bakery coreTest            # economy tests: costs, milestones, managers, offline, franchise, saves
./gradlew -p idle-bakery :app:assembleDebug  # APK in idle-bakery/app/build/outputs/apk/debug/
```

## Releasing
Package `com.hamxanadeem.idlebakery`. Add the secrets `BAKERY_KEYSTORE_BASE64`,
`BAKERY_KEYSTORE_PASSWORD`, `BAKERY_KEY_ALIAS`, `BAKERY_KEY_PASSWORD`, `BAKERY_ADMOB_APP_ID`,
`BAKERY_ADMOB_BANNER_ID`, `BAKERY_ADMOB_INTERSTITIAL_ID` and `BAKERY_ADMOB_REWARDED_ID` (the release
check requires all of them; the interstitial ID can be any valid unit), plus the shared
`PLAY_SERVICE_ACCOUNT_JSON`. Then push a tag such as `bakery-v1.0.0`. The full steps are
in `docs/PLAY_STORE_RELEASE.md` at the repository root. Upload the first bundle by hand.
