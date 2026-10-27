# Screw Puzzle 🔩

A "nuts and bolts" sorting puzzle, one of the most downloaded puzzle types on Google
Play. See-through acrylic plates are screwed to a wooden board. Tap a screw that no
plate covers to unscrew it: it flies into the box of its colour, or into the holding
tray if no box matches. Plates with no screws left fall away. Fill boxes to send them
off, and clear the board before the tray fills up.

## Why it works
- **Always solvable:** the generator plans a valid order for removing every screw
  first, and only then assigns colours, so each level can be cleared without using
  the tray at all. Tests check this for 200 levels.
- **Endless levels:** levels are generated from their number, with more plates and
  more colours as you progress.
- **Satisfying feel:** screws spin out, then fly in an arc. Covered screws shake and
  the plate on top flashes red. Plates tumble away, full boxes slide out and new ones
  slide in, and confetti falls when you win. Plates are translucent acrylic over a
  wood-grain board. Every sound is synthesised in code, and there is haptic feedback.
- **Attract mode:** the home screen shows a puzzle solving itself, which teaches how
  to play without a tutorial.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **+1 tray slot** (the dashed "+" hole, or the "Out of space" screen), once per level; **double coins** after a win |
| Interstitial | Between levels only, at most every 2 levels and 2 minutes, never in the first 2 |
| Banner | Home screen only |

## Build and test
```bash
./gradlew -p screw-puzzle coreTest            # rules and level generator tests
./gradlew -p screw-puzzle :app:assembleDebug  # APK in screw-puzzle/app/build/outputs/apk/debug/
```

## Releasing
Package `com.hamxanadeem.screwpuzzle`. Add the secrets `SCREW_KEYSTORE_BASE64`,
`SCREW_KEYSTORE_PASSWORD`, `SCREW_KEY_ALIAS`, `SCREW_KEY_PASSWORD`, `SCREW_ADMOB_APP_ID`,
`SCREW_ADMOB_BANNER_ID`, `SCREW_ADMOB_INTERSTITIAL_ID` and `SCREW_ADMOB_REWARDED_ID`, plus the shared
`PLAY_SERVICE_ACCOUNT_JSON`. Then push a tag such as `screw-v1.0.0`. The full steps are
in `docs/PLAY_STORE_RELEASE.md` at the repository root. Upload the first bundle by hand.
