# Spendwise: a smart, private expense manager

An Android app for tracking spending and income by category. It does most of
the thinking for you, and it has **no ads, no account and no analytics**. All
data stays on the phone.

## What it does

| | |
|---|---|
| **Plain-words quick add** | Type `coffee 4.50`, `uber 12 yesterday`, `rent 1,200 last monday`, `salary 3000 on 1st` or `+50 refund`. The amount, date, type and category are worked out, with a live preview before saving. |
| **Learning categories** | A small on-device classifier (naive Bayes over your notes plus per-category keywords) suggests the category as you type. It learns from every choice you make. |
| **Receipt scanning** | Take or pick a photo and on-device text recognition (ML Kit) fills in the total, date and shop. |
| **Budgets with rollover** | A monthly budget per category, with an optional envelope-style rollover of what's left (or overspent). It suggests a budget from your last three months. |
| **Safe to spend** | How much you can spend per day for the rest of the month and stay on budget (or within income if you have no budgets). |
| **Forecast** | Where the month is heading: spending so far, plus repeating payments still due, plus your usual daily pace. |
| **Subscription detection** | Finds weekly, monthly and yearly payments in your history (regular gaps, similar amounts), with the yearly cost. |
| **Unusual spending** | Flags payments far above your normal spend in a category, using a median/MAD outlier test. |
| **Insight cards** | The home screen ranks the most useful tips: budget warnings, trends against the same days last month, savings rate and more. |
| **Repeating transactions** | Bills, salary and subscriptions are added automatically when due. |
| **Charts** | A category donut, daily bars against your budget pace, and six months of income against spending. |
| **Budget alerts** | An optional notification when a budget passes 80% or runs out. |
| **App lock** | Fingerprint, face or screen lock. While it's on, the app is hidden in the recent-apps view. |
| **Your data** | CSV export (spreadsheet-safe), plus a backup and restore file you keep yourself. App data is excluded from cloud backup. |
| **Any currency** | Uses your locale's currency by default. Amounts are stored as whole minor units, so there are no rounding errors. |

Light and dark themes follow the system.

## Project layout

```
spendwise/
  core/   Pure Kotlin, no Android: models, money parsing, ledger storage,
          categoriser, quick-add parser, budgets, insights, receipt reader, CSV.
          Unit-tested with JUnit 5.
  app/    The Android app (Kotlin, Material 3, minSdk 26, targetSdk 36).
```

## Build and test

From the repository root:

```bash
./gradlew -p spendwise coreTest                         # unit tests (no Android SDK needed)
./gradlew -p spendwise :app:lintDebug :app:assembleDebug
```

CI runs both on every push (`.github/workflows/spendwise-ci.yml`) and uploads
the debug APK as a build artifact.

## Releasing to Google Play

`.github/workflows/spendwise-release.yml` builds a signed bundle and uploads it
to Play. It runs when you push a tag such as `spendwise-v1.0.0`, or you can start
it by hand and choose the track. Add these repository secrets:

| Secret | What it is |
|---|---|
| `SPENDWISE_KEYSTORE_BASE64` | Your upload keystore, base64-encoded (`base64 -w0 upload.jks`) |
| `SPENDWISE_KEYSTORE_PASSWORD` | Keystore password |
| `SPENDWISE_KEY_ALIAS` | Key alias |
| `SPENDWISE_KEY_PASSWORD` | Key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | Service account JSON with release access in Play Console (shared by all apps) |

The first upload of a new app has to be done by hand in Play Console. After
that, the workflow can publish. In the Play data-safety form you can state that
no data is collected or shared.
