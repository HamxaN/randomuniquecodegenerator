# Scam Radar

A free Android app that tells you whether an SMS, WhatsApp message or link is a
scam, and **explains why** in English or Urdu. It works fully **offline**: messages
never leave the phone, there are no ads and no account, and the app has no
internet permission.

## How people use it

* **Share to it:** long-press a message in WhatsApp or Messages, tap Share, and
  pick *Check for scams*. Screenshots work too.
* **Select text** anywhere and choose *Check for scam* from the text menu.
* **Paste** a message, or **scan a screenshot**. The text is read on the
  phone with ML Kit.
* Add the sender's number if you have it. A "bank" message from an ordinary
  mobile number is a red flag.

The result shows:
* a verdict: **Likely a scam / Suspicious / Looks safe**;
* a 0–100 risk score;
* the scam type;
* every warning sign it found, in plain words;
* the links it found and what's wrong with them;
* what to do next.

**Share warning** makes a picture card plus text for WhatsApp groups and
status, with the scam link removed so it can't spread. People forward warnings
to family, and that is how the app gets around.

Other screens:
* **Know the scams:** a guide to the common scams, with an example of each.
* **History:** past checks, which you can tap to re-check.

## What it detects

The detector (`core/`, pure Kotlin, unit-tested) scores weighted warning signs.
They work in **English, Roman Urdu and Urdu script**, and it isn't fooled by
Urdu digits or hidden characters.

| Scam | Example signs |
|---|---|
| "Sent by mistake" money trick | *galti se bhej diye, wapas kar dein* plus a number or amount |
| Fake BISP / Ehsaas payments | BISP/Ehsaas plus a link, phone number or fee (genuine 8171 info is left alone) |
| Code / PIN theft | Asks to share an OTP, PIN or password (ignores normal "do not share your OTP" texts) |
| Fake prizes | Won a lucky draw, claim now (an "Eid Mubarak" greeting doesn't trigger it) |
| Bank / PTA / FIA impersonation | Threatens to block your SIM or account, plus a number or link |
| "New number, send money" | Family member on a new number asking for money urgently |
| Easy-money jobs, investment | Rs X daily for liking videos, guaranteed profit, USDT |
| Fake deliveries | Parcel on hold, pay a small fee at a link |
| Dangerous links | Shorteners, risky endings (.xyz, .top…), raw IP addresses, look-alike letters, `@` tricks, and fake brand domains such as *hbl-secure-login.com* (checked against ~30 real Pakistani and global brand domains) |

These are warning signs, not proof. The app says so and always advises
checking with the real bank or person.

## Build and test

```bash
./gradlew -p scam-radar coreTest                         # detector tests (no Android SDK needed)
./gradlew -p scam-radar :app:lintDebug :app:assembleDebug
```

CI (`.github/workflows/scam-radar-ci.yml`) runs the tests and lint, and builds
the debug APK and release bundle.

## Releasing to Google Play

`.github/workflows/scam-radar-release.yml` publishes a signed bundle when you
push a tag such as `scamradar-v1.0.0`. It needs these secrets:

* `SCAMRADAR_KEYSTORE_BASE64`
* `SCAMRADAR_KEYSTORE_PASSWORD`
* `SCAMRADAR_KEY_ALIAS`
* `SCAMRADAR_KEY_PASSWORD`
* `PLAY_SERVICE_ACCOUNT_JSON`

In the Play data-safety form you can state that no data is collected or shared.
