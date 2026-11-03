# Night Survivors 🌙

A 3D horde-survival game for Android, built with **Godot 4.6**. You are alone in a haunted
graveyard at midnight. You only steer: your weapons fire by themselves while the undead
pour in from every side. Collect soul gems to level up, pick a new weapon or relic each
time, and stay alive until dawn.

## How it plays
| Feature | Details |
|---|---|
| Controls | One floating thumbstick anywhere on the screen. Everything else is automatic |
| Weapons | Magic Bolt (homing), Spinning Axes (orbit), Throwing Daggers, Holy Ring (aura), Storm Call (lightning) and Pumpkin Bomb (lobbed fire). Each upgrades to level 5; carry up to 6 |
| Relics | Ember Heart (damage), Hourglass (fire rate), Wind Boots, Troll Blood (health), Lodestone (pickup range), Moon Charm (regeneration) and Giant's Ring (area) |
| The horde | Glowing wisp swarms (hundreds at once, drawn in one batch), skeleton minions, rogues, warriors and necromancers, growing in number and toughness all night. The Bone Colossus rises at 3, 6 and 9 minutes |
| Pickups | Soul gems (XP), gold coins, pumpkins that heal, and treasure coffins with a free upgrade |
| Goal | Survive 10 minutes until dawn. Gold carries over |
| Heroes | Sir Aldric (axes, armour), Ilyra (bolts, faster casting), Vex (daggers, speed) and Grunhild (holy ring, health) |
| Power-ups | Permanent Might, Armour, Max Health, Swiftness, Attraction, Greed and Second Wind (a free revive) |
| Maps | Haunted Graveyard and Pumpkin Patch (unlocked by surviving 5 minutes) |

## Look and feel
KayKit Halloween graveyard pieces under moonlight and fog, with flickering jack-o'-lanterns
and candles, a lantern glow around the hero, and animated skeletons. You get glowing wisps
and soul gems, lightning strikes, fire bursts, spinning axes, damage numbers and screen
shake. The menus are dusky violet, and the camp has a campfire and live 3D hero portraits.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **Revive** after falling (once per run); **x2 gold** on the results screen |
| Banner | At camp (hidden during the night) |
| Interstitial | After runs, from the third on, at most every 2.5 minutes |

## Build and test
`.github/workflows/night-survivors-ci.yml` runs on every push:
1. Imports the assets.
2. Runs the rules tests: weapon and relic levels, the horde's growth, spawn weights, XP and
   level-ups, level-up choices (no duplicates, slot limits, gold when everything is maxed),
   stats, power-ups and saving.
3. Plays a night by itself under a virtual display: the camp, menus, the horde, a level-up,
   a full arsenal, a wisp swarm, the boss, the Pumpkin Patch and dawn. The screenshots go to
   the `screenshots-night-survivors` branch. It fails on any script error.
4. Adds the AdMob plugin (Google test ads) and exports a debug APK.

On desktop, drag with the mouse to steer.

## Releasing to Google Play
Package `com.hamxanadeem.nightsurvivors`. Add these repository secrets:

| Secret | What |
|---|---|
| `NIGHT_KEYSTORE_BASE64` | Your upload keystore (`base64 -w0 upload.jks`) |
| `NIGHT_KEYSTORE_PASSWORD` | Keystore password (use the same for the key) |
| `NIGHT_KEY_ALIAS` | Key alias |
| `NIGHT_ADMOB_APP_ID` | AdMob app ID |
| `NIGHT_ADMOB_BANNER_ID`, `NIGHT_ADMOB_INTERSTITIAL_ID`, `NIGHT_ADMOB_REWARDED_ID` | Ad unit IDs |
| `PLAY_SERVICE_ACCOUNT_JSON` | Shared with the other games |

Then push a tag such as `night-v1.0.0`, or run the release workflow from the Actions tab.

## Credits
| Asset | Author | Licence |
|---|---|---|
| Halloween Bits, Adventurers and Skeletons | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| Sounds | [Kenney](https://kenney.nl) | CC0 |
| Lilita One font | Juan Montoreano | SIL Open Font License (see `assets/fonts`) |
