# Dungeon Raiders 🗡️

A 3D action RPG dungeon crawler for Android, built with **Godot 4.6**. It plays like Archero,
Soul Knight or a small mobile Diablo. You raid endless dungeon floors, rooms lock until every
monster is dead, gold and gear drop, and a boss guards each floor.

## How it plays
| Feature | Details |
|---|---|
| Controls | Floating thumbstick. Your hero attacks the nearest foe automatically. Buttons for the hero's **skill** and a **potion** |
| Heroes | Sir Aldric the Knight (Whirlwind), Grunhild the Barbarian (Ground Slam), Vex the Ranger (Volley of 7 bolts) and Ilyra the Sorceress (Frost Nova that freezes) |
| Floors | Randomly generated rooms and corridors with a minimap. Gates slam shut while you fight. There are treasure rooms with gold chests, and a boss room with the Bone King or the Lich. A portal takes you deeper |
| Monsters | Skeletons, Bone Archers, Bone Knights and Necromancers. They rise from the floor and get tougher on every floor |
| Loot | Gold coins fly to you. Weapons, armour and amulets drop in 4 rarities (Common, Rare, Epic, Legendary) with light beams. Better gear is equipped automatically; weaker pieces are sold |
| Level-ups | Every level in a run offers a choice of 3 blessings: attack, attack speed, health, crit, speed, life steal, skill cooldown, cleave, greed |
| Camp | Spend gold on 4 permanent talents and unlock heroes. See your gear and deepest floor |

## Look and feel
KayKit dungeon pieces and animated characters, flickering torchlight, a lantern glow around
the hero, fog, glowing loot beams, damage numbers, crits, screen shake and a boss health bar.
The menus use stone-and-bronze panels with Cinzel headings.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **Rise again** when you fall; **double gold** after a run |
| Banner | At camp (hidden in the dungeon) |
| Interstitial | After runs, from the third on, at most every 2.5 minutes |

## Build and test
`.github/workflows/dungeon-raiders-ci.yml` runs on every push:
1. Imports the assets.
2. Runs the rules tests: every floor is connected with the boss in the farthest room, loot
   rarities, boons, gear and saving.
3. Plays the game by itself under a virtual display: camp, menus, rooms, a skill, loot, a
   level-up, the boss, the portal, floor 2 and the results. It fails on any script error, and
   the screenshots go to the `screenshots-dungeon-raiders` branch.
4. Adds the AdMob plugin (Google test ads) and exports a debug APK.

On desktop: WASD to move, Space for the skill, Q for a potion.

## Releasing to Google Play
Package `com.hamxanadeem.dungeonraiders`. Add these repository secrets:

| Secret | What |
|---|---|
| `RAIDER_KEYSTORE_BASE64` | Your upload keystore (`base64 -w0 upload.jks`) |
| `RAIDER_KEYSTORE_PASSWORD` | Keystore password (use the same for the key) |
| `RAIDER_KEY_ALIAS` | Key alias |
| `RAIDER_ADMOB_APP_ID` | AdMob app ID |
| `RAIDER_ADMOB_BANNER_ID`, `RAIDER_ADMOB_INTERSTITIAL_ID`, `RAIDER_ADMOB_REWARDED_ID` | Ad unit IDs |
| `PLAY_SERVICE_ACCOUNT_JSON` | Shared with the other games |

Then push a tag such as `raider-v1.0.0`, or run the release workflow from the Actions tab.

## Credits
| Asset | Author | Licence |
|---|---|---|
| Dungeon Remastered, Adventurers and Skeletons | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| Sounds and muzzle flash | [Kenney](https://kenney.nl) | CC0 |
| Cinzel and Teko fonts | Natanael Gama; Indian Type Foundry | SIL Open Font License (see `assets/fonts`) |
