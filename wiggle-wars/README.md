# Wiggle Wars 🪱💥

A turn-based artillery battle in the spirit of the PC classic *Worms*. Teams of
googly-eyed worms take turns on a destructible island, blasting craters into the
land, knocking each other into the sea, and using the wind to curve their shots.

## Game modes
| Mode | Players |
|---|---|
| **vs Computer** | You against 1–3 computer teams (Easy / Normal / Hard) |
| **Pass & Play** | 2–4 friends sharing one phone |
| **Play Online with Friends** | 2–4 friends on their own phones, anywhere: by room code, or by inviting from your friends list |

### Friends
- Every player gets a **friend code** like `KTR-WMP`, which they can share in one tap.
- **Add a friend** by typing their code. You both appear in each other's lists.
- The **friends list** shows who has the game's online screen open right now, with
  online friends at the top.
- **Invite** sends a friend straight into your room. It creates one for you if
  you're not in one yet. They get a "Battle invite! Join now?" pop-up.
- Long-press a friend to remove them.

## Features
- **Destructible terrain:** every explosion carves the map pixel by pixel, with
  scorched edges.
- **10 arenas**, each with its own land shape, look and rules. Pick one in the
  setup screen (with a live preview), or leave it on Random:

  | Arena | What's special |
  |---|---|
  | Green Hills | Rolling meadows, caves and floating ledges |
  | Dune Canyon | Flat-topped mesas and a deep canyon into the sea |
  | Tropical Islands | A chain of islands with open sea between them |
  | Castle Clash | Two castles with halls and towers, a moat and a thin bridge |
  | Crystal Caverns | A rock roof: no air strikes from the sky, crates appear inside the cave |
  | Sky Islands | Floating islands high above the water |
  | Frozen Peaks | Jagged mountains and stronger wind |
  | Lava Peak | A huge volcano over a glowing lava lake |
  | Moon Base | Half gravity, no wind, stars and the Earth in the sky |
  | Candy Land | Bubbly sweets and floating lollipops |
- **Physics:**
  - Worms walk, climb small slopes, jump and backflip.
  - They take fall damage, get knocked flying by blasts and drown in the sea.
  - Wind changes every turn; the drifting clouds show its direction.
- **15 weapons in 4 groups,** chosen in the Armory picker (picture tiles, ammo
  badges, and a card with each weapon's description and power, blast and range
  ratings):
  - **Explosives:** Bazooka (affected by the wind), Grenade (3-second fuse,
    bounces), Cluster Bomb, Banana Bomb (a super weapon, earned with a rewarded
    ad), Mega Grenade (a huge blast), Dynamite, Land Mine (arms after a few
    seconds and blows up the next worm to come close).
  - **Guns:** Shotgun, Uzi (ten bullets, great for pushing worms off ledges),
    Sniper Rifle (long range, hits hard).
  - **Strikes:** Air Strike (tap the map), Wild Sheep (waddles along, hops over
    bumps and explodes on contact).
  - **Tools:** Baseball Bat, Teleport, Girder (build a steel beam; your turn
    goes on).
- **Weapon sets:** Standard, Heavy Artillery, Sharpshooter (guns and tools only)
  or Mayhem (everything unlimited).
- **Sudden death:** after 10 rounds the sea rises every turn, so every battle
  ends.
- **Mini map:** the whole battlefield in the corner. Tap it to look anywhere.
- **Supply crates:** health and weapon crates parachute in during the match.
- **Turns:** 45 seconds to act, then 3 seconds to run for cover.
- **Computer opponents:** the AI plans each shot with the real physics, trying
  hundreds of angles and powers against the wind. It never aims at its own team.
  Difficulty changes how much aiming error it has.
- **Juice:** fireballs, shockwaves, smoke that drifts with the wind, flying dirt,
  splashes, screen shake, comic "KABOOM!" text, damage numbers, gravestones and
  animated waves.
- **Sounds:** explosions, shots, "ouch"es and fanfares, all synthesised in code.

## Controls
- **Aim:** drag on the battlefield.
- **Walk:** hold ◀ ▶. **Jump:** ⤴. **Backflip:** ↶.
- **Fire:** hold FIRE to charge the power, then release. It fires automatically at
  full power.
- **Weapon button:** opens the Armory picker. Tap a weapon to read about it, tap it
  again (or Equip) to take it. Air Strike, Teleport and Girder: tap the map.
- **Camera:** two fingers pan and zoom. It follows the action otherwise.

## How online play works
Both phones run the exact same simulation. The physics uses fixed time steps,
seeded randomness and `StrictMath`, so it gives bit-for-bit identical results on
every device. That means only button presses travel over the internet, each stamped
with the physics step it happened on.

The player whose turn it is "drives" the clock. Everyone else replays their inputs
at exactly the same steps. `core/Online.kt` holds this lockstep logic. Its tests run
complete 2- and 4-player matches over a simulated network with random delays and
check that every phone ends identical.

The rooms and the button presses go through a **Firebase Realtime Database**, which
is free for this kind of use.

### Setting up online play (one time, about 10 minutes)
1. Go to <https://console.firebase.google.com>, create a project, and add an
   **Android app** with package name `com.hamxanadeem.wigglewars`.
2. In **Build → Realtime Database**, create a database and set these rules (open
   rooms, which is fine for a game):
   ```json
   {
     "rules": {
       "rooms":       { "$code": { ".read": true, ".write": true } },
       "users":       { "$id":   { ".read": true, ".write": true } },
       "friendCodes": { "$code": { ".read": true, ".write": true } },
       "friends":     { "$id":   { ".read": true, ".write": true } },
       "invites":     { "$id":   { ".read": true, ".write": true } }
     }
   }
   ```
   These open rules are fine for testing with friends. Before a big launch, turn on
   Firebase **Anonymous Authentication** and lock each `users`, `friends` and
   `invites` entry to its owner.
3. From **Project settings** copy the **Web API key**, **App ID** and **Project ID**,
   and from the Realtime Database page copy the **database URL**.
4. Add them as GitHub secrets: `WIGGLE_FIREBASE_API_KEY`, `WIGGLE_FIREBASE_APP_ID`,
   `WIGGLE_FIREBASE_PROJECT_ID` and `WIGGLE_FIREBASE_DB_URL`. For local builds, put
   them in `~/.gradle/gradle.properties` as `FIREBASE_API_KEY=…` and so on.

Without these keys the game still builds and plays. The online button explains that
online play isn't set up yet.

## Ads (AdMob)
| Type | Where |
|---|---|
| Rewarded | **+2 Banana Bombs** for your next match (on the setup screen) |
| Interstitial | Between matches only, at most every 2 matches and 2 minutes, never in the first 2 |
| Banner | Main menu only, never during battles |

## Build and test
```bash
./gradlew -p wiggle-wars coreTest            # physics, weapons, turns, AI and online-sync tests
./gradlew -p wiggle-wars :app:assembleDebug  # APK in wiggle-wars/app/build/outputs/apk/debug/
```

## Releasing
Package `com.hamxanadeem.wigglewars`. Add the secrets `WIGGLE_KEYSTORE_BASE64`,
`WIGGLE_KEYSTORE_PASSWORD`, `WIGGLE_KEY_ALIAS`, `WIGGLE_KEY_PASSWORD`, `WIGGLE_ADMOB_APP_ID`,
`WIGGLE_ADMOB_BANNER_ID`, `WIGGLE_ADMOB_INTERSTITIAL_ID` and `WIGGLE_ADMOB_REWARDED_ID` (plus the
optional Firebase ones above, and the shared `PLAY_SERVICE_ACCOUNT_JSON`). Then push a
tag such as `wiggle-v1.0.0`. The full steps are in `docs/PLAY_STORE_RELEASE.md` at the
repository root.

The name "Worms" is a trademark of Team17, so this game uses its own name, art and
characters.
