# ClipCraft AI

An Android app that turns long videos into **YouTube Shorts**. It finds the most
viral moments with AI, cuts them into vertical clips with animated captions, and
posts them straight to your channel.

## How it works

1. **Pick a video** from your phone, or share one to ClipCraft from the gallery.
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

You can preview any clip in the player, and edit its title, hook and description
before making it.

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
signature. The YouTube API's default quota allows about 6 uploads a day per
project; request more in Cloud Console if you need it.

## Project layout

```
clipcraft/
  core/   Pure Kotlin, unit-tested: transcript parsing and sentence splitting,
          caption grouping, clip tidying, the offline picker, YouTube metadata,
          and ClipAdvisor (the Claude request via the official Anthropic Java SDK).
  app/    The Android app: audio decoding, Vosk transcription, Media3 rendering,
          the ExoPlayer preview, Google sign-in and upload, and the screens.
```

## Build and test

```bash
./gradlew -p clipcraft coreTest
./gradlew -p clipcraft :app:lintDebug :app:assembleDebug
```

CI (`.github/workflows/clipcraft-ci.yml`) runs both and uploads the debug APK.
To release to Play, push a tag such as `clipcraft-v1.0.0`; it needs the
`CLIPCRAFT_*` signing secrets and `PLAY_SERVICE_ACCOUNT_JSON`.
