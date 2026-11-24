# Device test checklist

CI checks that the code compiles, passes lint and that the clip logic is right.
It can't run the camera-roll, speech, video and Google parts, which need a real
phone. Do this pass before each release. Use at least:

* one Android 14 or newer phone;
* one Android 8 to 10 phone, because minSdk is 26.

Install the debug APK from the CI run's `clipcraft-debug-apk` artifact.

## Videos to keep for testing

| # | Video | Why |
|---|---|---|
| A | 10–20 min landscape talking-head (one person) | Main path, face pan |
| B | Portrait phone recording (9:16) | No reframing should happen |
| C | Podcast with two people side by side | Pan follows the bigger face |
| D | Video with loud background music | Music warning |
| E | Hindi or Urdu speech | Script conversion |
| F | 1-hour video | Long transcription, memory, battery |
| G | Video with no speech | Graceful "no clips" |

## 1. First run

- [ ] App opens with an empty projects screen and a "Pick a video" button.
- [ ] On Android 13+, it asks for notification permission. Denying it still
      lets everything work, just without notifications.
- [ ] The Settings hint says to add a key or server.

## 2. Projects and background work

- [ ] Pick video A. The project opens, the speech model downloads with a
      percentage, then transcription shows a percentage.
- [ ] Press Home during transcription. A "Working on your videos" notification
      shows progress, and the work finishes while you're away.
- [ ] Lock the screen for 2 minutes during transcription. It keeps going.
- [ ] Swipe the app away from recents mid-transcription, then reopen it. The
      project resumes (it starts the transcription again; the model isn't
      downloaded again).
- [ ] Reboot the phone and reopen the app. The project, its clips and its edits
      are still there, and video A still plays in the preview.
- [ ] Share video A from the Gallery or Files app to ClipCraft. A new project
      starts, and it shows "Copying the video" first.
- [ ] Long-press a project and delete it. The project disappears and its files
      are freed (check storage in App info).

## 3. AI and offline picks

- [ ] No key: clips are found offline, and the message says so.
- [ ] With your own key: "Claude found N clips". Titles, hooks and reasons make
      sense, and the clips start and end on whole sentences.
- [ ] A wrong key gives a clear error, and offline picks are shown.
- [ ] With the server (section 9): the same results, with no key in the app.
- [ ] Video G gives "No clips found", not a crash.
- [ ] "Find clips again" asks first, then replaces the clips.

## 4. Editing

- [ ] Edit: change the title and hook, Save, then Make. The hook shows at the top.
- [ ] Trim with Start −1 s and End +1 s. The time label updates, and the
      rendered Short starts and ends there.
- [ ] Captions: fix a misheard word (same word count). The word changes and the
      timing is unchanged.
- [ ] Captions: replace 3 words with 1. The single word stays up for the whole
      caption.
- [ ] Captions: empty one box. That caption disappears from the Short.
- [ ] Editing a clip removes its old rendered Short (the button reads "Make
      Short" again).

## 5. Rendering and the look

- [ ] Make a Short from video A. The output is 1080×1920 and the audio is in
      sync. Check the length matches the clip.
- [ ] Follow the speaker on, with video A: the face stays in frame as the person
      moves, and the pans are smooth.
- [ ] Follow the speaker off: a plain centre crop.
- [ ] Video B is not panned or squashed.
- [ ] Video C keeps the bigger or nearer face in frame.
- [ ] Each caption style (Karaoke, Boxed, Clean) and position (Low, Middle,
      Top) looks right. Top captions don't overlap the hook.
- [ ] Video E with Urdu script: captions are in Urdu letters and read right to
      left.
- [ ] Video E with Roman Urdu: captions are in Latin letters.
- [ ] Save puts the Short in Movies/ClipCraft. Share opens the share sheet, and
      WhatsApp or Instagram accept the file.
- [ ] Make all Shorts renders every clip in turn, with the notification showing
      progress.

## 6. Copyright help

- [ ] Clips from video D show "may contain music". Speech-only clips from A
      don't.
- [ ] Upload stays disabled until both checklist boxes are ticked.

## 7. YouTube

- [ ] The first upload shows Google sign-in and consent, then uploads with a
      percentage.
- [ ] The Short appears on the channel with the right privacy, title, `#shorts`
      and description.
- [ ] Within 5 minutes the card shows that YouTube accepted it, or the reason it
      was rejected.
- [ ] Post all, now: every clip is made if needed, then uploaded.
- [ ] Post all, scheduled: the first post is tomorrow at 18:00, one every
      24 hours. In YouTube Studio the videos are private and scheduled at the
      right local times, and the cards show "Goes public …".
- [ ] A schedule time less than 15 minutes away is refused.
- [ ] Airplane mode during upload gives a clear error on the card, and you can
      try again.

## 8. Stress

- [ ] Video F (1 hour) on the older phone: transcription finishes, with no
      out-of-memory crash and no app-not-responding dialog. Note how long it
      takes.
- [ ] Battery: note the drop for one hour of video. Transcription is the
      expensive part.
- [ ] Rotate the phone on each screen. Nothing is lost or restarted.

## 9. Server

Run the server (see the README) and set its address and token in Settings.

- [ ] Clips are found through the server.
- [ ] Urdu captions work through the server.
- [ ] A wrong token gives "This server needs the app's token" and offline picks.
- [ ] Going over `DAILY_LIMIT` gives "Daily limit reached".

## 10. Release build

- [ ] Install the signed release APK or AAB (via internal testing). Repeat 2, 3,
      5 and 7 briefly. R8 can break the Anthropic SDK, JNA/Vosk or ML Kit, and
      only the release build shows it.
