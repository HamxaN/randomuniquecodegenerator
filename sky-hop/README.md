# Sky Hop ☁️

A 3D platformer for Android in the spirit of Super Mario 3D Land, built with **Godot 4.6**.
Run, jump and double-jump across floating sky courses, collect coins and three hidden stars
per level, bump coin blocks and reach the goal flag.

## How it plays
| Feature | Details |
|---|---|
| Controls | Thumbstick to run and a big **JUMP** button (tap again in the air for a double jump). Coyote time and jump buffering make jumps forgiving on a touchscreen |
| Courses | 20 levels across 4 worlds: Meadow Isles, Sunset Bay, Frost Peaks and Starry Night. Each mixes hops, little stepping platforms, sliding platforms, lifts, crumbling tiles, bounce pads and coin blocks |
| Goals | Three stars hidden in each level, a coin trail, checkpoints and a goal flag. You get stars and coins at the end |
| Skins | Six colour skins bought with coins |

The level generator is tested so that every gap and step is within jump range and every
bounce pad reaches its platform.

## Look and feel
Kenney's chunky platformer pieces, the animated hopper with squash-and-stretch, clouds,
grass tufts and trees, and a sky per world (blue, sunset, snow, starry). There are dust puffs,
spinning coins, glowing stars, springy bounce pads, wobbling crumbling tiles, a
course-progress bar and Clash-style menus.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **×2 coins** after a level |
| Banner | On the world map (hidden in levels) |
| Interstitial | After levels, from the third on, at most every 2.5 minutes |

## Build and test
`.github/workflows/sky-hop-ci.yml` runs on every push:
1. Imports the assets.
2. Runs the rules tests: every jump in all 20 levels is possible, plus stars, coins,
   checkpoints and saving.
3. Plays it under a virtual display (map, levels, skins, a jump, moving and crumbling
   platforms, a bounce pad, three worlds and the goal) and publishes screenshots to
   `screenshots-sky-hop`.
4. Exports a debug APK with AdMob test ads.

On desktop: WASD or the arrow keys to move, Space to jump.

## Releasing to Google Play
Package `com.hamxanadeem.skyhop`. Add these secrets: `HOP_KEYSTORE_BASE64`,
`HOP_KEYSTORE_PASSWORD` (same for the key), `HOP_KEY_ALIAS`, `HOP_ADMOB_APP_ID`,
`HOP_ADMOB_BANNER_ID`, `HOP_ADMOB_INTERSTITIAL_ID`, `HOP_ADMOB_REWARDED_ID` and the shared
`PLAY_SERVICE_ACCOUNT_JSON`. Then push a tag such as `hop-v1.0.0`.

## Credits
| Asset | Author | Licence |
|---|---|---|
| Character, platforms, coins, sounds | [Kenney](https://kenney.nl) (Starter Kit 3D Platformer) | CC0 |
| Trees | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| Lilita One font | Juan Montoreano | SIL Open Font License |
