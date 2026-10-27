# Car Parking Jam 🚗

A satisfying traffic puzzle. The lot is packed: tap a car and it drives out the way
it's facing, if nothing's in the way. Get the order wrong and it bumps into another
car with a honk. Clear the lot in as few bumps as possible. Parking-jam puzzles are
one of the most-downloaded casual genres and suit short ad breaks between levels.

## How it plays
| Feature | Details |
|---|---|
| Controls | Tap a car. It drives forward until it leaves the lot, or bumps whatever blocks it |
| Cars and trucks | Cars take 2 bays, trucks 3. An arrow on each roof shows its way out |
| Stars | 3 stars with no bumps, 2 with one or two, otherwise 1 |
| Levels | Endless, generated from the level number: the lot grows from 5×7 to 8×11 and fills up with more cars and trucks |
| Always solvable | Each car is placed with a clear way out past the cars already there, so leaving in reverse order always works; the generator then keeps the most tangled of several lots. Tests clear the first 200 levels |
| Hints | Highlights a car that can leave: 30 coins, or free with a rewarded ad |
| Coins | Earned for every cleared lot, more for stars |

## Graphics and feel
- Top-down cartoon cars and trucks with windscreens, headlights and tail lights, on an
  asphalt lot with painted bays and a road round the edge.
- Cars pop in at the start, zoom away when they leave, and roll forward, bump and
  bounce back with a "BEEP!" when blocked; the blocker wobbles.
- Confetti and an overshooting "Lot cleared!" card; cars circling a roundabout on the
  title screen. Sounds are synthesised in code, with haptic feedback.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **Free hint**; **double coins** after a level |
| Banner | Bottom of the screen |
| Interstitial | Between levels, paced by `AdPolicy` |

## Build and test
```bash
./gradlew -p parking-jam coreTest            # tapping, bumping, stars, and that every level can be cleared
./gradlew -p parking-jam :app:assembleDebug  # APK in parking-jam/app/build/outputs/apk/debug/
```

## Releasing
Package `com.hamxanadeem.parkingjam`. Add the secrets `PARKING_KEYSTORE_BASE64`,
`PARKING_KEYSTORE_PASSWORD`, `PARKING_KEY_ALIAS`, `PARKING_KEY_PASSWORD`, `PARKING_ADMOB_APP_ID`,
`PARKING_ADMOB_BANNER_ID`, `PARKING_ADMOB_INTERSTITIAL_ID` and `PARKING_ADMOB_REWARDED_ID`, plus the
shared `PLAY_SERVICE_ACCOUNT_JSON`. Then push a tag such as `parking-v1.0.0`. The full steps
are in `docs/PLAY_STORE_RELEASE.md` at the repository root. Upload the first bundle by hand.
