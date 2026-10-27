# Tidy Room 🧸

A relaxing organising puzzle. Each room is a mess: books, mugs, shoes, pillows, toys
and towels are scattered across the floor. Drag every item onto its outline and
watch the room come together. Calm, satisfying, and quick to pick up, which suits
short sessions and rewarded ads.

## How it plays
| Feature | Details |
|---|---|
| Controls | Drag an item; drop it on a matching outline and it snaps into place with sparkles |
| Rooms | Bedroom, Kitchen, Bathroom, Living Room and Playroom, in turn, each with its own furniture |
| Items | 16 kinds: books, mugs, plants, shoes, pillows, teddies, lamps, clocks, plates, bottles, towels, rubber ducks, picture frames, vases, gamepads and socks |
| Levels | Endless. Rooms start with 4 items and fill up to 12 |
| Stars | 3 stars for no wrong guesses, 2 for a couple, otherwise 1 |
| Hints | Highlights an item and where it goes: 25 coins, or free with a rewarded ad |

## Graphics and feel
- Every item is painted in code in a cosy cartoon style; its outline on the shelf or
  bed is a soft silhouette of the same shape, so you can tell what goes where.
- Lifted items grow and cast a shadow; placed ones pop and sparkle; wrong guesses
  wiggle. A progress bar fills as the room gets tidier, and the whole room sparkles
  when it's done.
- Sounds are synthesised in code, with haptic feedback.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **Free hint**; **double coins** after a room |
| Banner | Bottom of the screen |
| Interstitial | Between rooms, paced by `AdPolicy` |

## Build and test
```bash
./gradlew -p tidy-room coreTest            # rooms, snapping, wrong guesses, hints and stars
./gradlew -p tidy-room :app:assembleDebug  # APK in tidy-room/app/build/outputs/apk/debug/
```

## Releasing
Package `com.hamxanadeem.tidyroom`. Add the secrets `TIDY_KEYSTORE_BASE64`,
`TIDY_KEYSTORE_PASSWORD`, `TIDY_KEY_ALIAS`, `TIDY_KEY_PASSWORD`, `TIDY_ADMOB_APP_ID`,
`TIDY_ADMOB_BANNER_ID`, `TIDY_ADMOB_INTERSTITIAL_ID` and `TIDY_ADMOB_REWARDED_ID`, plus the
shared `PLAY_SERVICE_ACCOUNT_JSON`. Then push a tag such as `tidy-v1.0.0`. The full steps
are in `docs/PLAY_STORE_RELEASE.md` at the repository root. Upload the first bundle by hand.
