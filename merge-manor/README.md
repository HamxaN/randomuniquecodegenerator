# Merge Manor 🏡

A 3D merge-and-restore puzzle game for Android, built with **Godot 4.6**. Grandma's old manor
is dusty and empty. Unpack boxes onto the merge board, drag matching pieces together to make
finer furniture, and fill orders for stars. Spend the stars to restore each room, piece by
piece, in a 3D diorama that brightens as you go.

## How it plays
| Feature | Details |
|---|---|
| Board | 7×6 tiles. Drag an item onto its twin to merge, onto an empty tile to move, or onto anything else to swap. Sell what you don't need |
| Chains | Cosy seats (pillow → grand sofa, 7 levels), Books (→ library shelf), Plants, Keepsakes (→ floor lamp), Paintings (→ masterpiece), Rugs (→ grand carpet), Woodwork (stool → dining table, 7 levels), Beds (→ four-poster) and Storage (→ grand dresser) |
| Generators | Moving Box, Sewing Basket and Workbench, each unpacking three chains for 1 energy. A lucky unpack is already level 2 |
| Energy | 60 maximum, refilling one point every 20 seconds (also while the game is closed). Refill with coins or a rewarded ad |
| Orders | Three at a time, asking for higher-level pieces as the manor fills up. They pay stars and coins |
| Rooms | Living Room, Bedroom and Study: 23 renovation steps that place real furniture, clear cobwebs and crates, and brighten the room |

## Look and feel
Every board tile shows a picture of the real KayKit 3D furniture model, rendered in the game.
The room is a warm diorama with wooden floorboards, striped wallpaper, a sunny window and
furniture that drops in with sparkles. Merge targets glow while you drag, merges pop, and
items at the top of their chain get a gold badge.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **+30 energy** |
| Banner | Bottom of the screen |
| Interstitial | After renovation steps, from the third on, at most every 2.5 minutes |

## Build and test
`.github/workflows/merge-manor-ci.yml` runs on every push:
1. Imports the assets.
2. Runs the rules tests: chains and models, merging, moving and swapping, generators (energy,
   nearby tiles, full board), energy refills, orders and rewards, the full renovation of all
   three rooms, and saving.
3. Plays the game by itself under a virtual display: unpacking, merging, delivering orders and
   restoring every room. The screenshots go to the `screenshots-merge-manor` branch. It fails
   on any script error.
4. Adds the AdMob plugin (Google test ads) and exports a debug APK.

## Releasing to Google Play
Package `com.hamxanadeem.mergemanor`. Add these repository secrets:

| Secret | What |
|---|---|
| `MANOR_KEYSTORE_BASE64` | Your upload keystore (`base64 -w0 upload.jks`) |
| `MANOR_KEYSTORE_PASSWORD` | Keystore password (use the same for the key) |
| `MANOR_KEY_ALIAS` | Key alias |
| `MANOR_ADMOB_APP_ID` | AdMob app ID |
| `MANOR_ADMOB_BANNER_ID`, `MANOR_ADMOB_INTERSTITIAL_ID`, `MANOR_ADMOB_REWARDED_ID` | Ad unit IDs |
| `PLAY_SERVICE_ACCOUNT_JSON` | Shared with the other games |

Then push a tag such as `manor-v1.0.0`, or run the release workflow from the Actions tab.

## Credits
| Asset | Author | Licence |
|---|---|---|
| Furniture Bits | [KayKit](https://kaylousberg.com) by Kay Lousberg | CC0 |
| Sounds | [Kenney](https://kenney.nl) | CC0 |
| Lilita One font | Juan Montoreano | SIL Open Font License (see `assets/fonts`) |
