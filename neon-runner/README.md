# Neon Runner ⚡

A futuristic endless runner. Ride a hover board down a synthwave highway, swipe to
dodge, and grab glowing energy orbs. Runs last a minute or two and get faster the
further you go, which suits ad breaks between rounds.

## How it plays
| Feature | Details |
|---|---|
| Controls | Swipe ← → to change lanes, ↑ (or tap) to jump, ↓ to slide |
| Obstacles | Amber **barriers** (jump), red **laser beams** (slide under), magenta **energy walls** (change lanes) |
| Fair tracks | Every row leaves a lane free, and a free lane is always next to the last one, so you never need to cross two lanes in a hurry. Rows spread out as you speed up |
| Speed | Starts at 16 m/s and climbs to 42 m/s |
| Orbs | Lines of orbs lead past obstacles; high ones need a jump. Each is worth 5 points and is banked for skins |
| Power-ups | **Magnet** pulls in orbs from every lane, **Shield** takes one hit, **Boost** rockets you forward untouchable |
| Skins | Six neon riders, from Cyan Volt to Golden Ghost, bought with orbs |

## Graphics and feel
- A striped neon sun, stars and mountains over a glowing perspective grid that rushes
  towards you; dashed lane lines, glowing track edges and distance fog.
- Obstacles glow and flicker; orbs bob and sparkle; the rider leaves a light trail and
  tumbles when you crash, with screen shake and sparks.
- Orbitron typeface, cut-corner glass buttons, synthesised sounds and haptics.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **Keep running** after a crash (once per run) |
| Banner | Bottom of the menu |
| Interstitial | Between runs, paced by `AdPolicy` (not in the first rounds, at most one every few runs) |

## Build and test
```bash
./gradlew -p neon-runner coreTest            # track generation, controls, power-ups, revive, and a 5-minute autopilot run
./gradlew -p neon-runner :app:assembleDebug  # APK in neon-runner/app/build/outputs/apk/debug/
```

## Releasing
Package `com.hamxanadeem.neonrunner`. Add the secrets `RUNNER_KEYSTORE_BASE64`,
`RUNNER_KEYSTORE_PASSWORD`, `RUNNER_KEY_ALIAS`, `RUNNER_KEY_PASSWORD`, `RUNNER_ADMOB_APP_ID`,
`RUNNER_ADMOB_BANNER_ID`, `RUNNER_ADMOB_INTERSTITIAL_ID` and `RUNNER_ADMOB_REWARDED_ID`, plus the
shared `PLAY_SERVICE_ACCOUNT_JSON`. Then push a tag such as `runner-v1.0.0`. The full steps
are in `docs/PLAY_STORE_RELEASE.md` at the repository root. Upload the first bundle by hand.

The Orbitron font is bundled under the SIL Open Font License (`third_party/orbitron/OFL.txt`).
