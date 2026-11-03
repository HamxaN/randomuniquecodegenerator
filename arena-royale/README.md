# Arena Royale 👑

A 3D real-time card battler for Android, built with **Godot 4.6**. Your heroes face the Bone
Army across a river with three bridges. Spend mana to drop troops, buildings and spells from
a hand of four cards, push the lanes, and knock down the enemy's guard towers and keep.

## How it plays
| Feature | Details |
|---|---|
| Controls | Tap a card, then tap your side of the field (spells go anywhere). The next card waits in the corner |
| Mana | Fills one point every 2.8 seconds up to 10, twice as fast in the last minute |
| Cards | Knight, Archers, Bone Swarm, Rogue, Mage (splash), Barbarian (splash), Catapult (a building), Bone Golem (only hits buildings), Fireball, Frost Nova and Healing Rune |
| Battles | 3 minutes. Each guard tower is a crown and the keep is all three. A crown lead wins at the bell; otherwise overtime, where the first crown wins |
| The Bone Army | Mirrors your cards as skeletons. It defends when you cross the river, fireballs crowds and pushes its weakest lane |
| Progression | Trophies take you through Training Meadow, Bone Canyon and Frost Keep, each unlocking cards. Wins open a chest of card shards and gold. Upgrade cards to level 10 |
| Deck | Pick 8 of your cards; the screen shows your average mana cost |

## Look and feel
KayKit blue and red castles and towers on a mown pitch, with a river, wooden bridges, tents and
flags. Animated heroes face skeletons. Arrows, mage fire and catapult boulders arc across the
field, and you get a falling fireball, frost and healing rings, crumbling ruins and crown pops.
The card faces show live 3D portraits, framed by rarity.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **x2 gold** after a battle |
| Banner | On the home screen (hidden in battle) |
| Interstitial | After battles, from the third on, at most every 2.5 minutes |

## Build and test
`.github/workflows/arena-royale-ci.yml` runs on every push:
1. Imports the assets.
2. Runs the rules tests: card data, deploy zones, mana, the hand and deck cycle, bridges only
   (a knight is tracked over the river), spells against towers, full AI-against-AI battles
   that always end with a sensible winner, chests, unlocks, upgrades and saving.
3. Plays battles by itself under a virtual display (an AI on your side too). The screenshots go
   to the `screenshots-arena-royale` branch. It fails on any script error.
4. Adds the AdMob plugin (Google test ads) and exports a debug APK.

## Releasing to Google Play
Package `com.hamxanadeem.arenaroyale`. Add these repository secrets:

| Secret | What |
|---|---|
| `ARENA_KEYSTORE_BASE64` | Your upload keystore (`base64 -w0 upload.jks`) |
| `ARENA_KEYSTORE_PASSWORD` | Keystore password (use the same for the key) |
| `ARENA_KEY_ALIAS` | Key alias |
| `ARENA_ADMOB_APP_ID` | AdMob app ID |
| `ARENA_ADMOB_BANNER_ID`, `ARENA_ADMOB_INTERSTITIAL_ID`, `ARENA_ADMOB_REWARDED_ID` | Ad unit IDs |
| `PLAY_SERVICE_ACCOUNT_JSON` | Shared with the other games |

Then push a tag such as `arena-v1.0.0`, or run the release workflow from the Actions tab.

## Credits
| Asset | Author | Licence |
|---|---|---|
| Medieval Hexagon, Adventurers and Skeletons | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| Sounds | [Kenney](https://kenney.nl) | CC0 |
| Lilita One font | Juan Montoreano | SIL Open Font License (see `assets/fonts`) |
