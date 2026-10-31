# Burger Rush 🍔

A 3D burger restaurant rush game for Android, built with **Godot 4.6**. It plays like the
cooking and time-management hits on mobile. Customers walk in and order at the counter. You
tap the crates, grill, fryer and drinks machine, and your chef runs between them to grill
patties, stack burgers and hand everything over before patience runs out.

## How it plays
| Feature | Details |
|---|---|
| Controls | Tap a station to queue a job; numbered markers show the chef's next jobs. Tap a burger (or the customer) to serve it |
| Cooking | Patties cook on the grill and **burn** if left too long. Buns and toppings stack on plates in any order. Fries fry in batches and drinks pour into cups. The bin clears a wrong burger |
| Customers | Knights, mages, rogues, barbarians and skeletons, each with an order bubble and a patience bar. Happy customers tip more, then sit down to eat |
| Days | 30 days across 3 restaurants: Main Street Diner, Sunny Beach Shack and Spooky Night Grill. Cheese, drinks, lettuce, fries and tomato join the menu over the first week. 1–3 stars per day from coin goals; combos for serving in a row |
| Kitchen upgrades | Bigger grill, hotter flames, extra plate, running shoes, cosy decor, tip jar and a big fryer |
| Chefs | Big Bruno, Sir Lance, Mira the Wise, Quick Quinn and Hooded Robin |
| Tutorial | Day 1 points at each step: patty, bun, flip, serve |

## Look and feel
KayKit restaurant pieces and animated characters, a checkered diner floor, pendant lamps,
food flying over the counter, cooking timers, floating coin pops and chunky cartoon menus.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **Double coins** after a day |
| Banner | On the menu (hidden during service) |
| Interstitial | After days, from the third on, at most every 2.5 minutes |

## Build and test
`.github/workflows/burger-rush-ci.yml` runs on every push:
1. Imports the assets.
2. Runs the rules tests: menu unlocks, day plans and star goals, burger matching, the grill
   (cooking and burning), plates, fries, drinks, prices and tips, upgrades and saving.
3. Plays the game by itself under a virtual display: menus, day 1 with the tutorial, a busy
   day, the beach shack and the night grill. It fails on any script error, and the
   screenshots go to the `screenshots-burger-rush` branch.
4. Adds the AdMob plugin (Google test ads) and exports a debug APK.

## Releasing to Google Play
Package `com.hamxanadeem.burgerrush`. Add these repository secrets:

| Secret | What |
|---|---|
| `BURGER_KEYSTORE_BASE64` | Your upload keystore (`base64 -w0 upload.jks`) |
| `BURGER_KEYSTORE_PASSWORD` | Keystore password (use the same for the key) |
| `BURGER_KEY_ALIAS` | Key alias |
| `BURGER_ADMOB_APP_ID` | AdMob app ID |
| `BURGER_ADMOB_BANNER_ID`, `BURGER_ADMOB_INTERSTITIAL_ID`, `BURGER_ADMOB_REWARDED_ID` | Ad unit IDs |
| `PLAY_SERVICE_ACCOUNT_JSON` | Shared with the other games |

Then push a tag such as `burger-v1.0.0`, or run the release workflow from the Actions tab.

## Credits
| Asset | Author | Licence |
|---|---|---|
| Restaurant Bits, Adventurers and Skeletons | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| Sounds | [Kenney](https://kenney.nl) | CC0 |
| Lilita One font | Juan Montoreano | SIL Open Font License (see `assets/fonts`) |
