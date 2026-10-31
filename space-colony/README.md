# Space Colony 🚀

A 3D Mars base-building game for Android, built with **Godot 4.6**. You start with a lone
Command Hub on the red plain and grow it into a busy colony. You lay out solar arrays,
habitats, greenhouses and ore drills, keep the power and oxygen flowing, and watch rockets
land with new colonists. When meteor showers come, you blast the meteors out of the sky.

## How it plays
| Feature | Details |
|---|---|
| Controls | Drag to look around, pinch to zoom. Tap **Build**, pick a building and tap a tile. Tap a building to upgrade, rush or repair it |
| Resources | **Credits** from working colonists, **ore** from drills on ore deposits (capped by storage), rare **crystals** from meteors, crystal veins and missions |
| Balance | **Power** (solar, wind and the Hub) runs everything; short of power, the whole colony slows down. **Oxygen** from greenhouses and **homes** from habitats decide how many colonists can live there |
| Buildings | Solar Array, Habitat, Ore Drill, Greenhouse, Wind Turbine, Landing Pad, Cargo Depot, Rover Bay, Research Lab and Crystal Extractor. Each upgrades to level 5 |
| Command Hub | 5 levels that unlock new buildings and raise how many of each you can have |
| Colonists | Rockets land every so often while there is room and air; a landing pad doubles the rate |
| Events | **Meteor showers**: tap meteors for crystals before they hit (a hit knocks a building out until repaired). **Dust storms** halve solar power |
| Missions | 21 guided goals, from your first solar array to 120 colonists, each paying credits and crystals |
| Idle | The colony keeps earning while the game is closed (up to 2 hours), with a welcome-back screen |

## Look and feel
KayKit Space Base modules on a red plain ringed with cliffs and distant mesas, under a
dusky Martian sky. It has glowing crystal veins, spinning turbines, bobbing drills, rovers
hauling ore, rockets with flame trails, burning meteors with target rings, and dust-storm fog.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **x2 Boost** (double production for 3 minutes); double the welcome-back earnings |
| Banner | Bottom of the screen |
| Interstitial | After claiming missions, from the third on, at most every 2.5 minutes |

## Build and test
`.github/workflows/space-colony-ci.yml` runs on every push:
1. Imports the assets.
2. Runs the rules tests: placement and deposits, Hub limits, costs, credits and ore, power
   efficiency and storms, oxygen and housing, rockets, construction, upgrades, rushing,
   repairs, missions, offline earnings and saving.
3. Builds a colony by itself under a virtual display and saves screenshots to the
   `screenshots-space-colony` branch. It fails on any script error.
4. Adds the AdMob plugin (Google test ads) and exports a debug APK.

## Releasing to Google Play
Package `com.hamxanadeem.spacecolony`. Add these repository secrets:

| Secret | What |
|---|---|
| `COLONY_KEYSTORE_BASE64` | Your upload keystore (`base64 -w0 upload.jks`) |
| `COLONY_KEYSTORE_PASSWORD` | Keystore password (use the same for the key) |
| `COLONY_KEY_ALIAS` | Key alias |
| `COLONY_ADMOB_APP_ID` | AdMob app ID |
| `COLONY_ADMOB_BANNER_ID`, `COLONY_ADMOB_INTERSTITIAL_ID`, `COLONY_ADMOB_REWARDED_ID` | Ad unit IDs |
| `PLAY_SERVICE_ACCOUNT_JSON` | Shared with the other games |

Then push a tag such as `colony-v1.0.0`, or run the release workflow from the Actions tab.

## Credits
| Asset | Author | Licence |
|---|---|---|
| Space Base Bits | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| Sounds | [Kenney](https://kenney.nl) | CC0 |
| Lilita One font | Juan Montoreano | SIL Open Font License (see `assets/fonts`) |
