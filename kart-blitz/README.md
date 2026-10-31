# Kart Blitz 🏁

A 3D kart racer for Android in the style of Mario Kart Tour, built with **Godot 4.6**.
Race five rivals over three laps. Drift through bends to charge mini-turbos, and grab
item boxes for rockets, oil slicks, shields and boosts.

## How it plays
| Feature | Details |
|---|---|
| Controls | Auto-throttle. Hold ◀ ▶ to steer and hold **DRIFT** through bends. Let go for a blue mini-turbo, or orange if you drifted long enough. Tap **ITEM** (or the item slot) to use what you're holding |
| Items | Boost, triple boost, a homing rocket at the racer ahead, oil slick, shield. Racers at the back get stronger items |
| Rivals | Five rivals with their own lines and skill. They drift through long bends, use items tactically and keep the race close |
| Tracks | Six circuits: Sunny Meadow, Dusty Canyon, Frosty Pines, Twilight Loop, Palm Island and Lava Ridge. A podium finish unlocks the next one |
| Garage | Five vehicles, from the free Red Rocket up to the Lightning Bike. Engine, tyre and nitro upgrades |
| HUD | Big place readout, lap and timer, live minimap, item roulette, speedo, countdown and a results table with points and coins |

## Look and feel
Smooth procedurally built circuits with asphalt, a centre stripe, red-and-white kerbs, striped
barriers, a chequered start line and the start arch. Forests and mountains change with each
theme (desert, snow, dusk, lava pools). Drift sparks change colour as the turbo charges,
with boost flames, rocket trails, explosions, a speed-reactive camera and screen shake.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **×2 coins** after a race |
| Banner | In the garage (hidden while racing) |
| Interstitial | After races, from the third on, at most every 2.5 minutes |

## Build and test
`.github/workflows/kart-blitz-ci.yml` runs on every push:
1. Imports the assets.
2. Runs the rules tests: tracks are smooth and never overlap themselves, item odds, rewards,
   unlocks and saving.
3. Plays the game by itself under a virtual display: garage, upgrades, grid, countdown,
   racing, a drift, a rocket, results and two more tracks. Screenshots go to the
   `screenshots-kart-blitz` branch.
4. Adds the AdMob plugin (Google test ads) and exports a debug APK.

On desktop: A/D or the arrow keys steer, Space drifts, E uses the item.

## Releasing to Google Play
Package `com.hamxanadeem.kartblitz`. Add these repository secrets:
`KART_KEYSTORE_BASE64`, `KART_KEYSTORE_PASSWORD` (same for the key), `KART_KEY_ALIAS`,
`KART_ADMOB_APP_ID`, `KART_ADMOB_BANNER_ID`, `KART_ADMOB_INTERSTITIAL_ID`, `KART_ADMOB_REWARDED_ID`
and the shared `PLAY_SERVICE_ACCOUNT_JSON`. Then push a tag such as `kart-v1.0.0`.

## Credits
| Asset | Author | Licence |
|---|---|---|
| Vehicles, start arch, sounds | [Kenney](https://kenney.nl) (Starter Kit Racing) | CC0 |
| Trees, rocks and mountains | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| Lilita One font | Juan Montoreano | SIL Open Font License |
