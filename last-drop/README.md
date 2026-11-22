# Last Drop

An original island **battle royale** for Android, built with Godot 4. Twenty
players drop from a plane, loot weapons and gear, and fight inside a shrinking
zone until one player or squad is left. Play **offline against bots** or
**online**, either on a dedicated server or on a friend's phone over Wi-Fi.

## Features

| | |
|---|---|
| **The drop** | A plane crosses the island on a random line. Jump when you like, dive in freefall (push forward to fall faster), then open your parachute and steer to land. AI squadmates jump with you. |
| **The island** | Generated from the match seed: hills, beaches and sea, 7 named towns, forests, rocks, about 300 loot spots and 12+ parked vehicles. Every match is different, and every device builds the same island from the same seed. |
| **Weapons** | Pistol, SMG, assault rifle, shotgun, marksman rifle and a sniper (airdrop only). Each has its own damage, fire rate, spread, recoil, range falloff and headshot multiplier. |
| **Attachments** | Red dot, 2x, 4x and 8x scopes, extended mags, grips, compensators and suppressors. They show on the 3D gun, change its numbers, and are fitted automatically. Spares move to your next gun. |
| **Gear** | Level 1–3 vests and helmets, bandages, medkits, energy drinks (heal over time), frag grenades, and four ammo types. Ammo, heals and upgrades are picked up as you walk over them. |
| **Vehicles** | Sedans, taxis, wagons, police cars, trucks and motorbikes with arcade handling. Drive, ride as a passenger, run enemies over, and wreck them with gunfire. Your squad hops in when you drive. |
| **Squads** | Squads of 4 or solo. When you're knocked down you can crawl, and teammates can revive you. AI teammates follow you, fight, loot and revive you. |
| **The zone** | Six shrinking circles with rising damage, and a striped wall you can see from a distance. |
| **Airdrop** | Mid-match, a crate parachutes in with red smoke. It holds a sniper, level 3 armour and an 8x scope. |
| **Bots** | Pick a landing spot, loot, fight with skill-based aim and reaction time, strafe, heal, run from the zone, and revive teammates. |
| **Controls** | Twin-stick touch: a floating joystick, drag anywhere on the right to look, and two fire buttons you can drag to aim. Also an aim (scope) button, gentle aim assist, jump/parachute, reload, grenade, a quick-heal menu, and a context button (pick up / drive / revive / get out). |
| **HUD** | Minimap and full map, zone timer, alive and kill counts, compass, kill feed, squad health, hit markers, damage numbers, damage-direction arrows, a scope overlay, and heal and revive progress. |
| **Progress** | Coins and XP per match, 5 characters to unlock, and career stats. |

## Online play

The same match code runs in four roles:

* **Offline:** this phone is the authority and runs all the bots.
* **Host:** this phone runs the match and plays in it. Friends on the same
  Wi-Fi tap *Play online*, type the address shown in the waiting room, and join.
* **Dedicated server:** a headless Godot process that runs matches back to
  back. Matches start 30 seconds after the first player joins, and bots fill
  the empty slots.
* **Client:** sends its own movement, shots and actions. It predicts its own
  player and smoothly follows everyone else from 15 Hz snapshots.

The server decides hits, damage, loot, revives and the zone. It checks that
reported shots start near the shooter and that pickups are in reach. If a
player leaves mid-match, a bot takes over their character.

### Running a dedicated server

With Docker (from this folder):

```bash
docker build -f server/Dockerfile -t last-drop-server .
docker run -d -p 7777:7777/udp -e MODE=squad last-drop-server
```

Or with the Godot 4.6 editor binary:

```bash
godot --headless --path last-drop -- --server --port=7777 --mode=squad
```

Open UDP port 7777 on the machine's firewall. Players type its public address
in *Play online* (add `:port` for a different port). A small cloud VM, such as
1 vCPU and 1 GB of memory, runs one 20-player match.

## Build and test

```bash
godot --headless --path last-drop --import
godot --headless --path last-drop -s res://tests/run_tests.gd       # game rules
godot --headless --path last-drop -- --server --countdown=3 &         # online test:
godot --headless --path last-drop -- --nettest=127.0.0.1              # a client plays through the server
godot --path last-drop -- --shots=/tmp/shots                          # self-playing screenshot tour
```

CI (`.github/workflows/last-drop-ci.yml`) runs:
* the unit tests;
* the online test (a dedicated server and a client that drops, loots and fires);
* the screenshot tour;
* a debug APK build;
* a build of the server Docker image.

Screenshots are published to the `screenshots-last-drop` branch.

## Releasing to Google Play

`.github/workflows/last-drop-release.yml` builds a signed bundle and uploads it
when you push a tag such as `lastdrop-v1.0.0`. You can also run it by hand.
Add these repository secrets:

| Secret | What it is |
|---|---|
| `LASTDROP_KEYSTORE_BASE64` | Upload keystore, base64-encoded |
| `LASTDROP_KEYSTORE_PASSWORD` | Keystore and key password |
| `LASTDROP_KEY_ALIAS` | Key alias |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play service account (shared by all apps) |

## Credits

The game, code and design are original. Assets used under CC0:
* characters, city buildings, cars and nature props: [KayKit](https://kaylousberg.com) by Kay Lousberg;
* trucks, motorbike and sound effects: [Kenney](https://kenney.nl).

Fonts are under the SIL Open Font License (see `assets/fonts`).
