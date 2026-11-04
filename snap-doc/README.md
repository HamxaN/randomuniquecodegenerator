# SnapDoc Scanner 📄

A document scanner app for Android in the style of CamScanner, built in Kotlin. You can scan
paper documents, receipts, IDs and notes with the camera, or import photos. The app finds the
edges automatically and turns the scans into clean, shareable PDFs. It can also read the text
on them.

**Ads: banner only.** One adaptive banner sits at the bottom of the library and document
screens. There are no interstitials, no rewarded ads and nothing full-screen.

## Features
| Feature | Details |
|---|---|
| Scanning | Google's on-device ML Kit Document Scanner: automatic edge detection, crop and perspective correction, rotate, clean-up filters (colour, greyscale, black & white) and removal of stains and fingers. Up to 50 pages per scan, from the camera or gallery |
| Library | Documents with thumbnails, page count and date, newest first. Search by name **and by the text inside** (after text recognition). Rename, delete, share |
| Document view | Page grid; long-press and drag to reorder. Add more pages to an existing document |
| Page viewer | Full screen, swipe between pages, rotate left/right, read text, delete a page |
| PDF | Built by the app's own PDF writer, which embeds the scanned JPEGs as they are (no re-compression), so pages stay sharp and files stay small. Pages keep their shape at A4 width. Share it, or save it anywhere with *Save PDF* |
| Text (OCR) | On-device text recognition (ML Kit) for one page or the whole document. Copy or share the text; the document's text is saved for search |
| Privacy | Everything stays on the device in the app's private storage. Google's consent form is shown where required (EEA/UK), with a privacy options button |

No camera or storage permission is needed: the scanner, *Save PDF* and sharing all go through
system screens.

## Project layout
- `core/`: pure Kotlin, tested without Android.
  - `PdfWriter`: multi-page PDF with embedded JPEGs and a correct cross-reference table.
  - `JpegInfo`: reads image size and colour type from the JPEG header.
  - `Library`: documents, naming, search, page editing and saving.
- `app/`: the Android app. ML Kit document scanner and text recognition, AdMob banner and UMP consent.

## Build and test
`.github/workflows/snap-doc-ci.yml` runs on every push:
1. **Unit tests:**
   - the PDF structure, with every cross-reference offset checked and images embedded byte for byte;
   - JPEG header parsing;
   - library naming, search, page editing and saving.
2. Android lint.
3. A debug APK (Google's test banner) and a release bundle.

```bash
./gradlew -p snap-doc coreTest            # unit tests (no Android SDK needed)
./gradlew -p snap-doc :app:assembleDebug  # debug APK
```

## Releasing to Google Play
Package `com.hamxanadeem.snapdoc`. Add these repository secrets:

| Secret | What |
|---|---|
| `SNAPDOC_KEYSTORE_BASE64` | Your upload keystore (`base64 -w0 upload.jks`) |
| `SNAPDOC_KEYSTORE_PASSWORD`, `SNAPDOC_KEY_PASSWORD` | Keystore and key passwords |
| `SNAPDOC_KEY_ALIAS` | Key alias |
| `SNAPDOC_ADMOB_APP_ID` | AdMob app ID |
| `SNAPDOC_ADMOB_BANNER_ID` | The banner ad unit ID (the only ad unit this app uses) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Shared with the other apps |

Then push a tag such as `snapdoc-v1.0.0`, or run the release workflow from the Actions tab.

In the Play Console's Data safety form, declare the data the AdMob SDK collects for ads. Scanned
documents never leave the device unless the user shares them.
