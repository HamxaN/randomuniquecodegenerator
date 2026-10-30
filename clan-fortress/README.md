# Clan Fortress 🏰

A 3D village builder with raids, in the style of Clash of Clans, built with **Godot 4.6**.
Build up a village on a hex island, dig gold and cut wood, train an army, and raid 20
goblin villages for loot and stars.

## How it plays
| Feature | Details |
|---|---|
| Village | Hex island with 11 building types: Town Hall, Gold Mine, Lumber Mill, Barracks, Army Camp, Archer Tower, Catapult, Blacksmith, Market, Well and Windmill. Each goes up to level 5 |
| Economy | Mines and mills produce over real time (even while the game is closed). Tap the bubble to collect |
| Builders | Two builders. Builds take real time. Finish early with gems, or free with a rewarded ad |
| Army | Barbarians, Archers, Knights (go for towers) and Wizards (splash damage). Train them with wood; housing comes from Army Camps |
| Blacksmith | Upgrades troops to level 5: more health and damage |
| Raids | 20 campaign villages, harder each time. Deploy troops outside the red zone (tap, or hold to deploy a stream). Archer towers and catapults fight back |
| Stars | ★ for 50% destroyed, ★ for the Town Hall, ★ for 100%. Loot depends on how much you destroy |
| Guidance | Coach tips for the first steps: collect, build, attack |

## Look and feel
- Real 3D KayKit models: the medieval hexagon set for the island and buildings (blue for you,
  red for the enemy) and animated adventurers for the troops.
- The HUD is laid out like Clash: level and XP badge, a builders counter, gold/wood/gem
  bars, round ATTACK!/SHOP/ARMY buttons, parchment panels, the Lilita One font and
  outlined white text.
- The shop and army cards show real 3D portraits rendered at run time.
- Scaffolding with countdowns, resource bubbles, coins flying to the counters, dust,
  sparkles, troops wandering around the village, health bars, projectiles, screen shake
  and pop-in stars.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | Finish a build for free; train the whole queue instantly; double the loot after a raid |
| Banner | In the village (hidden in raids) |
| Interstitial | After raids, from the third one on, at most every 2.5 minutes |

Ads use the [Poing Studios Godot AdMob plugin](https://github.com/poingstudios/godot-admob-plugin).
Builds without it (desktop, CI) still run, and rewarded ads simply grant their reward.

## Build and test
`.github/workflows/clan-fortress-ci.yml` runs on every push:
1. Imports the assets.
2. Runs the rules tests: hex maths, building data and models, production, stars, all 20
   campaign layouts, and building, training and saving.
3. Plays the game by itself under a virtual display (`-- --shots=<dir>`): the village, the
   shop, placing a building, the army, the campaign map, a full raid and the results. It
   fails on any script error and publishes screenshots to the `screenshots-clan-fortress` branch.
4. Exports a debug APK (artifact `clan-fortress-debug-apk`).

## Credits
| Asset | Author | Licence |
|---|---|---|
| Medieval Hexagon Pack, Adventurers and Skeletons | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| Sounds and coin sprite | [Kenney](https://kenney.nl) | CC0 |
| Lilita One font | Juan Montoreano | SIL Open Font License (see `assets/fonts`) |
