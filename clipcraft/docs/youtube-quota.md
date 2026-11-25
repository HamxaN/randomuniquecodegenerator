# Raising the YouTube upload quota

The YouTube Data API gives each Google Cloud project **10,000 quota units a
day**, shared by all of its users. Each upload (`videos.insert`) costs **about
1,600 units**, so the default allows about **6 uploads a day for everyone
together**. Other calls are cheap:

* the status check (`videos.list`) costs 1 unit per call;
* ClipCraft makes up to 15 status checks per upload.

The quota resets at midnight Pacific time. When it's used up, uploads fail with
`quotaExceeded`, and ClipCraft shows that on the clip's card.

## Check your usage

Go to **Google Cloud Console → APIs & Services → YouTube Data API v3 →
Quotas**. Look at "Queries per day" and its usage graph.

## Ask for more

Quota increases go through the YouTube API team, not the normal Cloud quota
button:

1. Make sure the app follows the
   [YouTube API Services Developer Policies](https://developers.google.com/youtube/terms/developer-policies)
   and your OAuth verification is done or underway (see
   [google-verification.md](google-verification.md)).
2. Fill in the **YouTube API Services – Audit and Quota Extension Form**:
   <https://support.google.com/youtube/contact/yt_api_form>.
   Choose that you are requesting a quota extension for an existing project.
3. Have this ready:
   * **Cloud project number** (Console home page).
   * **What the app does.** For example: "Android app that turns a creator's
     own long video into Shorts on the device and uploads them to the
     creator's own channel when they tap Upload or schedule a batch."
   * **Which API calls you make and why:**
     * `videos.insert` (resumable) to upload;
     * `videos.list?part=status` to tell the user whether the upload was
       accepted or rejected.

     No other data is read.
   * **Quota requested, with the maths.** For example: "500 active creators ×
     avg 3 Shorts/day × 1,600 units = 2.4M units/day, plus status checks
     (≤15 units per upload) ≈ 2.43M. We request 2,500,000 units/day."
     Start with a realistic number; you can ask again as you grow.
   * **Screenshots or a screen recording** of the upload flow, including the
     copyright checklist and how users see results.
   * **Privacy policy and home page** links (the same as for OAuth
     verification).
   * **How users' data is stored and deleted.** Everything stays on the phone.
     The only thing kept is the video ID. Deleting a project removes it, and
     uninstalling removes everything.
4. Google usually replies by email within a couple of weeks. They may run an
   **audit**: they review the app against the policies and may ask for a test
   account or build. Fix anything they flag, then reply in the same thread.

## Until then

* Batch scheduling helps creators use their uploads well, but the daily cap
  still applies to the whole project.
* For a handful of creators, a separate Cloud project per creator (each with its
  own 10,000 units) is allowed for personal use. It doesn't scale and isn't a
  substitute for an increase in a public app.
