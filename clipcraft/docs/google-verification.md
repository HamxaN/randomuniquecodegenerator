# Getting Google to verify the app (YouTube sign-in for everyone)

While your OAuth consent screen is in **Testing**:

* only test users you list can sign in, up to 100;
* their sign-in expires after 7 days.

To let any YouTube user post from ClipCraft, publish the consent screen and pass
Google's **sensitive scope verification**. The app asks for:

* `youtube.upload`, to post Shorts;
* `youtube.readonly`, to check processing status.

Both are sensitive scopes, not restricted ones, so you don't need a paid
security assessment. Expect a few days to a few weeks.

## What you need first

1. **A home page** on a domain you own, for example `clipcraft.app` or a GitHub
   Pages site on your own domain. It should say what the app does and link to
   the privacy policy.
2. **A privacy policy** on the same domain. It must say:
   * what Google data you access (upload videos to the user's channel, read
     their upload status) and why;
   * that transcripts are sent to Anthropic (Claude) only to pick clips, and the
     video never leaves the phone except when uploading to YouTube;
   * that nothing is stored on your servers (or, if you run the ClipCraft
     server, that it keeps no transcripts);
   * how to revoke access: <https://myaccount.google.com/permissions>.
   * A line saying the app's use of Google user data follows the
     [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy),
     including the Limited Use requirements.
   * Because it uses the YouTube API, a link to the
     [YouTube Terms of Service](https://www.youtube.com/t/terms) and to
     [Google's Privacy Policy](https://policies.google.com/privacy).
3. **Domain ownership.** Verify the domain in
   [Google Search Console](https://search.google.com/search-console) with the
   same Google account that owns the Cloud project.
4. **An app logo** (120×120 PNG). Uploading a logo also triggers brand
   verification.

## Fill in the consent screen

In Google Cloud Console, go to **APIs & Services → OAuth consent screen**
(called "Google Auth Platform" in newer consoles):

* **App name:** ClipCraft AI. Don't use "YouTube" or "Google" in the name or logo.
* **User support email** and **developer contact email**.
* **App home page**, **privacy policy** and, optionally, **terms of service**
  links on your verified domain.
* **Authorised domains:** your domain.
* **Scopes:** `.../auth/youtube.upload` and `.../auth/youtube.readonly`, and
  nothing else.
* **Publishing status:** select **Publish app**. Google then asks you to submit
  for verification.

## The verification submission

Google asks for:

1. **A justification for each scope.** For example:
   * `youtube.upload`: "ClipCraft turns a user's long video into Shorts on
     their phone and, when the user taps Upload, posts the Short to their own
     channel."
   * `youtube.readonly`: "After uploading, we read that video's processing and
     rejection status (videos.list part=status) to tell the user whether
     YouTube accepted it."
2. **A demo video** (unlisted YouTube link), 2–5 minutes, in English, on a real
   phone. It must show:
   * the app's name and the OAuth client ID on the consent screen (zoom in so
     the client ID in the URL or screen is readable);
   * the full sign-in and consent screen with both scopes;
   * using each scope: an upload finishing and appearing on the channel, then
     the "accepted by YouTube" status.
3. Answers to Google's follow-up emails. Reply in the same thread, usually
   within a few days. Typical asks:
   * a clearer video;
   * a privacy policy wording fix;
   * removing an unused scope.

## Also needed for YouTube specifically

* A **YouTube API Services compliance audit** is separate from OAuth
  verification. It's required for a quota increase (see
  [youtube-quota.md](youtube-quota.md)), and the YouTube team may contact you
  for one anyway.
* Follow the
  [YouTube API Services Developer Policies](https://developers.google.com/youtube/terms/developer-policies).
  Key rules:
  * Don't change uploads without the user's action. ClipCraft only uploads
    when the user taps Upload.
  * Show what will be posted. The upload dialog shows the title and privacy.
  * Let users revoke access.
  * Delete stored API data on request. ClipCraft stores only video IDs, on the
    phone.

## While you wait

* Keep adding testers (up to 100) under **Audience → Test users**.
* The "Google hasn't verified this app" screen appears once Testing mode is
  over. Users can continue past it, but it hurts trust and has a user cap.
