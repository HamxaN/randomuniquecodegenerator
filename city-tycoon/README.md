# City Tycoon 🏙️

A 3D city-building game for Android, built with **Godot 4.6**. You are the mayor of
Brookvale. Lay roads, zone homes, shops, factories and offices, and add parks and plazas.
Your town grows into a bustling metropolis, with traffic on the streets and lights coming on
at night.

## How it plays
| Feature | Details |
|---|---|
| Controls | Drag to pan, pinch to zoom. Pick a tool from the toolbar and tap tiles; inspect any tile to see how it's doing |
| Roads | Auto-join into straights, corners, T-junctions and crossroads. Lots only grow next to a road |
| Zones | Homes (residents), Shops, Factories and Offices (jobs). Each grows through three levels into taller buildings |
| Happiness | Parks and plazas nearby make homes happier, shops nearby help, and factories next door hurt. Homes need happiness to grow taller |
| Demand | Homes, shops and industry meters show what the city needs |
| Budget | Every day residents pay taxes and businesses pay their share; roads, parks and plazas cost upkeep |
| Milestones | Village → Town → City → Metropolis → Megacity, each with a cash reward. Offices and plazas unlock at Town |
| Life | Cars (sedans, taxis, police) drive the streets. Day turns to night with lit-up buildings, streetlights and headlights |

## Look and feel
KayKit city blocks, roads, street furniture and cars with Kenney parks and fountains on green
countryside. Buildings pop up and grow, and you get build dust, a sky that changes with the
time of day, and floating budget numbers.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **City grant**: +$1,000 |
| Banner | Bottom of the screen |
| Interstitial | On reaching milestones, from the third on, at most every 2.5 minutes |

## Build and test
`.github/workflows/city-tycoon-ci.yml` runs on every push:
1. Imports the assets.
2. Runs the rules tests: every road shape gets the right piece and turn, building and
   bulldozing, growth (only with roads), happiness, the daily budget, milestones and their
   unlocks, and saving.
3. Builds a city by itself under a virtual display (roads, zones, growth, offices and a
   plaza, street level, night and a milestone). The screenshots go to the
   `screenshots-city-tycoon` branch. It fails on any script error.
4. Adds the AdMob plugin (Google test ads) and exports a debug APK.

## Releasing to Google Play
Package `com.hamxanadeem.citytycoon`. Add these repository secrets:

| Secret | What |
|---|---|
| `CITY_KEYSTORE_BASE64` | Your upload keystore (`base64 -w0 upload.jks`) |
| `CITY_KEYSTORE_PASSWORD` | Keystore password (use the same for the key) |
| `CITY_KEY_ALIAS` | Key alias |
| `CITY_ADMOB_APP_ID` | AdMob app ID |
| `CITY_ADMOB_BANNER_ID`, `CITY_ADMOB_INTERSTITIAL_ID`, `CITY_ADMOB_REWARDED_ID` | Ad unit IDs |
| `PLAY_SERVICE_ACCOUNT_JSON` | Shared with the other games |

Then push a tag such as `city-v1.0.0`, or run the release workflow from the Actions tab.

## Credits
| Asset | Author | Licence |
|---|---|---|
| City Builder Bits | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| City Builder starter kit (parks, fountain, garage) | [Kenney](https://kenney.nl) | CC0 |
| Sounds | [Kenney](https://kenney.nl) | CC0 |
| Lilita One font | Juan Montoreano | SIL Open Font License (see `assets/fonts`) |
