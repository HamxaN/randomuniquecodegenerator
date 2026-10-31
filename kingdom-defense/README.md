# Kingdom Defense 🏰

A 3D tower defense game for Android in the style of Kingdom Rush, built with **Godot 4.6**.
Skeleton armies march down a winding road towards your castle. Build towers beside it, lead
your knight into the fight, and survive every wave.

## How it plays
| Feature | Details |
|---|---|
| Towers | **Archer Tower** (fast single target), **Catapult** (splash), **Mage Tower** (magic ignores armour and slows), **Gold Mine** (income). Each upgrades to level 3. Sell for 60% back |
| Hero | Your knight. Tap the map to send him; he blocks and fights skeletons on the road, regenerates and respawns at the castle |
| Enemies | Skeletons, fast Bone Runners, armoured Bone Knights, Necromancers and the **Bone Colossus** boss |
| Levels | 12 battles across grassland, sand, snow and ash. Each has its own generated road and 9 to 20 waves. Call waves early for bonus gold, and play at 2× speed |
| Stars | ★★★ for 18+ lives left, ★★ for 10+, ★ for a win |

## Look and feel
KayKit medieval hex islands with a dirt road, forests and mountains, blue castles and
towers that grow when upgraded, and animated skeletons and knight. You get arrows,
boulders with splash rings, magic bolts with a slow tint, gold pop-ups, health bars and
screen shake. The menus are Clash-style, and the build menu shows live 3D tower portraits.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **Keep fighting** after the castle falls (5 lives back, enemies weakened) |
| Banner | On the kingdom map (hidden in battle) |
| Interstitial | After battles, from the third on, at most every 2.5 minutes |

## Build and test
`.github/workflows/kingdom-defense-ci.yml` runs on every push. It imports the assets and runs
the rules tests: every road is continuous and on the island with room for towers, every
level ends with a boss, plus tower values and progress. It then plays levels 1, 8 and 11 by
itself under a virtual display, building and upgrading towers and calling waves, and
publishes screenshots to `screenshots-kingdom-defense`. Finally it exports a debug APK with
AdMob test ads.

## Releasing to Google Play
Package `com.hamxanadeem.kingdomdefense`. Add these secrets: `KINGDOM_KEYSTORE_BASE64`,
`KINGDOM_KEYSTORE_PASSWORD` (same for the key), `KINGDOM_KEY_ALIAS`, `KINGDOM_ADMOB_APP_ID`,
`KINGDOM_ADMOB_BANNER_ID`, `KINGDOM_ADMOB_INTERSTITIAL_ID`, `KINGDOM_ADMOB_REWARDED_ID` and the
shared `PLAY_SERVICE_ACCOUNT_JSON`. Then push a tag such as `kingdom-v1.0.0`.

## Credits
| Asset | Author | Licence |
|---|---|---|
| Medieval Hexagon Pack, Adventurers and Skeletons | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| Sounds and coin sprite | [Kenney](https://kenney.nl) | CC0 |
| Lilita One font | Juan Montoreano | SIL Open Font License |
