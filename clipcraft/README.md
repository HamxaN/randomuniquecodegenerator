# ClipCraft AI

An Android app that turns long videos into **YouTube Shorts**. It finds the most
viral moments with AI, cuts them into vertical clips with animated captions, and
posts them straight to your channel.

## How it works

1. **Pick a video** from your phone, share one to ClipCraft from the gallery, or
   **add it from a link**. Links can be:
   * Dropbox;
   * Google Drive, shared with "Anyone with the link";
   * a direct `.mp4` link.

   You can paste the link or share it to the app. ClipCraft downloads the file
   into the project first. YouTube, TikTok, Instagram and other platform links
   are refused with an explanation. Those sites don't allow downloading, and
   re-posting other people's videos gets channels copyright strikes. For your
   own YouTube videos, download the original from YouTube Studio.
2. **Transcribe on the phone.** The soundtrack is decoded and transcribed offline
   with word timings, using [Vosk](https://alphacephei.com/vosk/). The first time
   you use a language, its speech model (about 40 MB) downloads once. Languages:
   English, Hindi/Urdu (Hindi script), Spanish, French, German and Portuguese.
3. **AI picks the clips.** The timestamped transcript goes to **Claude Haiku 5.5**
   (`claude-haiku-5-5`) with a short-form editor brief and a strict JSON schema.
   For each clip it returns:
   * start and end times;
   * a curiosity-driven title and an on-screen hook line;
   * a description and hashtags;
   * a 1–100 viral score and the reason it works.

   The app then snaps each clip to whole sentences, keeps it 15–60 seconds long
   and removes overlaps. Without an API key, an offline picker scores sections by
   pace, questions, strong words and the opening line.
4. **Make the Short.** Media3 Transformer trims the clip, crops it to **9:16 at
   1080×1920**, and burns in word-by-word captions (the spoken word is
   highlighted) plus an optional hook title at the top.
5. **Post it.**
   * **Save** to the gallery (Movies/ClipCraft).
   * **Share** to TikTok, Instagram or WhatsApp.
   * **Upload to YouTube** as a Short. This uses Google sign-in with the
     `youtube.upload` scope (and `youtube.readonly` to check processing status) and the YouTube Data API's resumable upload. It
     uploads as private, unlisted or public, with `#shorts` in the title and
     description.

Before making a clip you can:

* preview it in the player;
* edit its title, hook and description;
* **trim** it a second at a time at either end;
* **fix the captions** word by word. If you change the number of words, the new
  words share that caption's time evenly.

## With or without Claude: the AI page

Each user picks how clips are found on the **AI page**. Open it from the line
under "Pick a video", or from Settings → AI clip finder. The choice is saved on
that phone, so every user decides for themselves:

| Mode | What happens |
|---|---|
| **Without Claude (offline)** | Nothing leaves the phone and it's free. Clips are scored by pace, questions, strong words and the opening line. Captions, editing, reframing and posting all still work. |
| **Claude, with my own API key** | The transcript text (never the video) goes to Claude Haiku. You get smarter picks, titles, hooks and hashtags. |
| **Claude, through a ClipCraft server** | The same as above, but the server holds the key (see below). |

**Test Claude** sends a tiny sample transcript to check that the key or server
works. If Claude can't be reached during real use, the app falls back to offline
picks and says so. Urdu and Roman Urdu captions need Claude.

## Projects and background work

Every video becomes a **saved project** on the home screen. Its clips, edits,
rendered Shorts and YouTube status are kept, so you can close the app and come
back later. Videos picked in the app keep their read permission. Videos shared
from another app are copied into the project, because shared permission ends
when the app closes. Long-press a project to delete it.

Transcribing, rendering and uploading run in a **foreground service** with a
progress notification, so they keep going when you leave the app or lock the
screen. Jobs run one at a time in order. If the phone restarts mid-job, the
project picks up again the next time you open ClipCraft, and the finished
transcript is reused.

## Smarter Shorts

* **Follow the speaker.** When the video is wider than 9:16, ClipCraft looks at
  about one frame a second with ML Kit's on-device face detector. It then pans
  the crop smoothly to keep the biggest face in frame. Small movements are
  ignored so the shot doesn't wobble, and the crop never leaves the picture.
  You can turn this off in Settings.
* **Caption styles.**
  * Styles: Karaoke (dark band, spoken word coloured), Boxed (spoken word in a
    coloured box) or Clean (big words, no band).
  * Positions: low, middle or top.
* **Urdu and Roman Urdu captions.** Vosk's Hindi/Urdu model writes in Hindi
  script. With a caption writing setting of *Urdu script* or *Roman Urdu*,
  Claude rewrites each word and the timings stay the same. This needs the AI to
  be set up.
* **Sound cues.** Claude sees more than words:
  * lines said noticeably louder than the speaker's normal level;
  * gaps with sound but no speech (laughter, a reaction, music);
  * plain pauses.

  This helps it find punchlines and reactions.

## Batch posting and scheduling

From the project menu:

* **Make all Shorts** renders every clip.
* **Post all to YouTube** makes any missing clips and uploads them all, after
  one copyright checklist for the whole batch.

Turn on **Schedule** to pick the first post time and the hours between posts
(for example tomorrow at 18:00, then one every 24 hours). Scheduled Shorts
upload right away as private, with YouTube's `publishAt` time. YouTube makes
each one public at its time, even if your phone is off.

## Optional ClipCraft server

By default each user pastes their own Anthropic API key. If you'd rather hold
one key for everybody, run the small server in `server/`. It accepts only the
app's two jobs, finding clips and converting caption script. It can require a
shared app token, limits each device to a number of requests a day, and never
sees the video, only the transcript.

```bash
# Run it directly
ANTHROPIC_API_KEY=... APP_TOKEN=some-shared-secret DAILY_LIMIT=20 \
  ./gradlew -p clipcraft/server run

# Or with Docker (from the clipcraft folder)
docker build -f server/Dockerfile -t clipcraft-server .
docker run -p 8080:8080 -e ANTHROPIC_API_KEY=... -e APP_TOKEN=... clipcraft-server
```

Put it behind HTTPS on any host that runs containers: Cloud Run, Fly.io,
Railway or a VPS with Caddy. Then, on the app's AI page, choose **Claude, through
a ClipCraft server** and enter its address and token. The endpoints are:

* `GET /health`
* `POST /v1/clips`
* `POST /v1/script`

Errors come back as JSON with an `error` field. The app token stops casual
abuse, but anyone who unpacks the APK can find it. For a public app, add real
sign-in or Play Integrity checks before relying on it.

## Copyright help

ClipCraft can't check a video against YouTube's copyright database. Only YouTube
can, with Content ID, after upload. What it does:

* **Music warning.** While transcribing, it measures the soundtrack's loudness
  every half second. A clip with loud sound where nobody is speaking, which is
  usually background music, gets a "may contain music" warning on its card. Music
  is the most common cause of Shorts copyright claims. Claude is also told to
  prefer moments carried by the speaker's own words.
* **Checklist before upload.** Upload stays disabled until you confirm that you
  made the video (or have permission) and that any music is yours, licensed or
  free to use.
* **Status after upload.** The app checks YouTube's processing status for up to
  5 minutes. It tells you if the video was rejected, for copyright, as a
  duplicate or for a rules breach. Claims that leave the video up aren't exposed
  in YouTube's public API, so check those in YouTube Studio.

## Costs and privacy

* **Transcription** runs on the phone, and the video never leaves the device for it.
* **Claude** gets only the transcript text. Claude Haiku 5.5 costs $0.10 per
  million input tokens, so a one-hour video (about 15k tokens) costs a fraction
  of a cent.
* **Your API key** is stored only on the phone and left out of backups. The app
  has no ads and no account.

## Setting up YouTube upload (one time)

Google needs to know the app before it can upload for you:

1. In [Google Cloud Console](https://console.cloud.google.com/), create a project
   and **enable the YouTube Data API v3**.
2. Configure the **OAuth consent screen**: External, add the scopes `.../auth/youtube.readonly` and
   `.../auth/youtube.upload`, and add yourself as a test user.
3. Create an **OAuth client ID** of type **Android**:
   * package `com.hamxanadeem.clipcraft` (or `com.hamxanadeem.clipcraft.debug`
     for debug builds);
   * the **SHA-1** of the key the APK is signed with
     (`keytool -list -v -keystore <keystore>`).

There are no client secrets to put in the app. Google matches it by package and
signature.

While the consent screen is in **Testing**, only the test users you list (up to
100) can sign in. To let anyone use it, Google must verify the app; see
[docs/google-verification.md](docs/google-verification.md). The YouTube API's
default quota allows about 6 uploads a day for the whole project, shared by all
users. To get more, see [docs/youtube-quota.md](docs/youtube-quota.md).

## Project layout

```
clipcraft/
  core/    Pure Kotlin, unit-tested. Covers:
           - transcript parsing and sentence splitting;
           - caption grouping and editing;
           - clip tidying and trimming;
           - the offline picker and sound cues;
           - music detection;
           - face-pan paths;
           - saved projects;
           - scheduling and YouTube metadata;
           - ClipAdvisor (Claude via the official Anthropic Java SDK) and
             ServerClipSource.
  app/     The Android app:
           - audio decoding and Vosk transcription;
           - ML Kit face tracking and Media3 rendering;
           - the background Engine and foreground service;
           - Google sign-in and upload;
           - the screens.
  server/  Optional server that holds the Claude key, plus its Dockerfile.
  docs/    Device test checklist, Google verification, YouTube quota.
```

## Build and test

```bash
./gradlew -p clipcraft coreTest
./gradlew -p clipcraft/server test
./gradlew -p clipcraft :app:lintDebug :app:assembleDebug
```

CI (`.github/workflows/clipcraft-ci.yml`) runs all of these, builds the server's
Docker image, and uploads the debug APK. Before a release, go through
[docs/device-test-checklist.md](docs/device-test-checklist.md) on a real phone.
Rendering, face tracking, speech and Google sign-in can't be tested in CI.
To release to Play, push a tag such as `clipcraft-v1.0.0`; it needs the
`CLIPCRAFT_*` signing secrets and `PLAY_SERVICE_ACCOUNT_JSON`.
