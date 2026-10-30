# Squad Strike 🎯

A 3D squad survival shooter for Android, built with **Godot 4.6**. You lead a squad of three
operators against ever-bigger waves of the undead across three arenas. It plays like the
top-down modes of COD Mobile or Brawl Stars: move with one thumb, and your operator aims
and fires automatically.

## How it plays
| Feature | Details |
|---|---|
| Controls | Floating thumbstick (left). Auto-aim and auto-fire at the nearest enemy you can see. GRENADE, DASH, AIRSTRIKE and RELOAD buttons (right) |
| Squad | You plus two AI teammates who follow you, shoot, and get back up after each wave |
| Enemies | Skeletons (rush you), Bone Archers (crossbows), Bone Knights (tough, with axes), Necromancers (magic orbs) and the **Bone Colossus** boss every fifth wave |
| Waves | Endless, growing bigger and tougher. A perk choice every second wave |
| Perks | 9 perks: more damage, fire rate, health, faster reload, bigger mags, speed, stronger grenades, squad revive, faster airstrike |
| Scorestreak | Kills charge an **airstrike** that shells up to 7 targets |
| Arenas | Hollow Graves (night cemetery), Raven Village (houses and market) and Iron Keep (castle walls at sunset). The last two unlock at levels 5 and 10 |
| Operators | GHOST (fast), BULWARK (armoured), BRUTE (extra damage) and ARCANE (fast grenades), each with its own model and perk |
| Armory | 5 weapons: assault rifle, SMG, shotgun, marksman rifle (pierces) and LMG. Each upgrades to level 10 |
| Progress | Coins and XP from every match, player levels, best wave per arena |

## Look and feel
- Real 3D: animated characters, lighting, shadows, fog and glow. Each arena has its own
  time of day.
- The lobby works like a modern shooter's: your squad poses on a lit stage, with the
  profile and XP bar at the top, menus on the side and a big START button.
- In matches you get damage numbers, hit markers, a kill feed, muzzle flashes, tracers,
  explosions, screen shake, a damage vignette and a boss health bar.
- The HUD has slanted military-style buttons and a stencil font for headings.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **Revive** when you go down; **x2 rewards** after a match |
| Banner | In the lobby (hidden during matches) |
| Interstitial | After matches, from the third one on, at most every 2.5 minutes |

The game talks to AdMob through the [Poing Studios Godot AdMob plugin](https://github.com/poingstudios/godot-admob-plugin).
Builds without the plugin (desktop, CI) still run: rewarded ads simply grant their reward.

## Build and test
CI (`.github/workflows/squad-strike-ci.yml`) does it all on every push:
1. Imports the assets and parses every script.
2. Runs the rules tests: `godot --headless --path squad-strike -s res://tests/run_tests.gd`.
3. Plays the game by itself under a virtual display (`-- --shots=<dir>`). It goes through the lobby,
   menus, three arenas, grenades, an airstrike, perks, the boss, going down and the results screen.
   It saves a screenshot at each step and fails if any script error occurs.
4. Exports a debug APK (artifact `squad-strike-debug-apk`).

The screenshots are published to the `screenshots-squad-strike` branch.

To run it locally, open the `squad-strike` folder in Godot 4.6, or run
`godot --path squad-strike`. On desktop: WASD to move, Space to dash, G for a grenade,
F for the airstrike.

## Releasing to Google Play
Package `com.hamxanadeem.squadstrike`. Add these repository secrets:

| Secret | What |
|---|---|
| `SQUAD_KEYSTORE_BASE64` | Your upload keystore (`base64 -w0 upload.jks`) |
| `SQUAD_KEYSTORE_PASSWORD` | Keystore password. Use the same password for the key itself |
| `SQUAD_KEY_ALIAS` | Key alias |
| `SQUAD_ADMOB_APP_ID` | AdMob app ID (`ca-app-pub-…~…`) |
| `SQUAD_ADMOB_BANNER_ID`, `SQUAD_ADMOB_INTERSTITIAL_ID`, `SQUAD_ADMOB_REWARDED_ID` | AdMob ad unit IDs |
| `PLAY_SERVICE_ACCOUNT_JSON` | Shared with the other games |

Then push a tag such as `squad-v1.0.0`, or run **Release** from the Actions tab. The workflow
tests the game, adds the AdMob plugin with your IDs, builds a signed `.aab` with Gradle and
uploads it to the internal track as a draft.

## Credits
| Asset | Author | Licence |
|---|---|---|
| Characters, skeletons, medieval and Halloween props | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| Blasters, sounds, muzzle flash | [Kenney](https://kenney.nl) | CC0 |
| Teko and Black Ops One fonts | Indian Type Foundry; James Grieshaber and Eben Sorkin | SIL Open Font License (see `assets/fonts`) |
