# Publishing to Google Play

Maintainer runbook for the `publish-play.yml` workflow. This file is internal
only. Do not link it from public docs.

## What the workflow does

Builds the `release` flavor of `android` (AAB by default, APK
optional), signs it with the release keystore, and uploads it to the
configured Play Store track using
[`r0adkll/upload-google-play@v1`](https://github.com/marketplace/actions/upload-android-release-to-play-store).
The run is manual (`workflow_dispatch`) with inputs for `track`, `format`,
`status`, `userFraction`, and `mappingFile`.

## Required GitHub secrets

Configure these under the repository's *Settings &gt; Secrets and variables &gt; Actions*.

| Secret | What it is | Where to get it |
| --- | --- | --- |
| `ANDROID_KEYSTORE_FILE` | Base64-encoded release keystore (`.jks` / `.keystore`) | `base64 -w0 release.jks \| pbcopy` on the host that holds the keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Password for the keystore store | Your keystore generator |
| `ANDROID_KEY_ALIAS` | Alias of the signing key inside the keystore | `keytool -list -v -keystore release.jks` |
| `ANDROID_KEY_PASSWORD` | Password for the signing key | Your keystore generator |
| `PLAY_STORE_SERVICE_ACCOUNT_JSON` | Google Cloud service account JSON key with access to the Google Play Android Developer API | See *Play Console setup* below |

The workflow writes the four keystore properties into
`$GRADLE_USER_HOME/gradle.properties` so that the existing signing config in
`android/app/build.gradle.kts` picks them up
(`OPENCLAW_ANDROID_STORE_FILE`, `OPENCLAW_ANDROID_STORE_PASSWORD`,
`OPENCLAW_ANDROID_KEY_ALIAS`, `OPENCLAW_ANDROID_KEY_PASSWORD`).

## Play Console setup

1. **Create the app listing in Play Console first.** The first upload to a
   brand-new package requires a manual `.aab` or `.apk` upload through the
   console. After that, the API can take over.
2. **Enable the Google Play Android Developer API** in the Google Cloud
   project that owns the Play Console.
3. **Create a service account** in that Google Cloud project. No GCP IAM
   roles are required. Download the JSON key.
4. **Invite the service account in the Play Console.** Go to
   *Users and permissions*, invite the service account email, and grant
   *App access* for the target app. The role *Release manager* (or higher)
   is required to upload releases.
5. **Add the JSON key as `PLAY_STORE_SERVICE_ACCOUNT_JSON`** in the GitHub
   repo secrets. Paste the full file contents.

See
[Google's docs on service accounts for the Play Developer API](https://developers.google.com/android-publisher/service_accounts)
for the authoritative walkthrough.

## First-time run on the `internal` track

The `internal` track is the safest first target. It does not require Google
review and is gated only to the testers you explicitly add in the Play
Console.

1. Verify all five secrets are present (the *Decode release keystore* step
   will fail loudly if the keystore is empty; the *Upload to Google Play*
   step will fail with a 401/403 if the service account is not invited).
2. From the repository's *Actions* tab, select *Publish to Google Play*,
   then *Run workflow*. Keep the defaults: `track=internal`, `format=aab`,
   `status=draft`, `userFraction` blank.
3. The workflow uploads the AAB and creates a draft on the `internal` track.
   `changesNotSentForReview: true` blocks auto-submission, so the draft sits
   in the console until a maintainer reviews it.
4. In the Play Console, open *Testing &gt; Internal testing*, inspect the
   draft, attach release notes from `.github/play-whatsnew/`, then click
   *Review and roll out*.

## Promoting to other tracks

Tracks are ordered: `internal` &rarr; `alpha` &rarr; `beta` &rarr; `production`.
For a brand-new listing Google may reject a direct push to `production` with
*"Precondition check failed"*. If that happens, promote through
`internal` first.

For staged production rollouts, set `status=inProgress` and
`userFraction=0.1` (or 0.05 for very conservative rollouts). Increase the
fraction in the Play Console rather than re-running the workflow with a
higher `userFraction` -- re-running creates a new release, not an update of
the existing one.

## Release notes (whatsnew)

The workflow reads release notes from `.github/play-whatsnew/`. Create one
`.txt` file per locale Play Console expects. The default set:

```
.github/play-whatsnew/
  en-US/default.txt
  de-DE/default.txt
  ...
```

Each file is plain text, no markdown, no header. Example:

```
Fixes rare crash when pairing a new gateway.
Improves background reconnect reliability.
```

If the directory is empty the action simply omits the `whatsNewDirectory`
input and Play Console falls back to the previous release's notes.

## Keystore rotation

The `androidComponents.onVariants` block in
`android/app/build.gradle.kts` customizes the output filename. After a
keystore rotation, bump `versionCode` (and `versionName` if you also want a
visible bump) in the same file. The Play Console treats a new signing key as
a new app, so the first upload with a rotated key must go through manual
review even on `internal`.

## Local equivalent

You can reproduce the workflow locally:

```bash
cd android
echo "OPENCLAW_ANDROID_STORE_FILE=$HOME/keys/release.jks" >> ~/.gradle/gradle.properties
echo "OPENCLAW_ANDROID_STORE_PASSWORD=..."              >> ~/.gradle/gradle.properties
echo "OPENCLAW_ANDROID_KEY_ALIAS=..."                   >> ~/.gradle/gradle.properties
echo "OPENCLAW_ANDROID_KEY_PASSWORD=..."                >> ~/.gradle/gradle.properties
./gradlew :app:bundleRelease
```

The Play upload itself has no local equivalent that does not also require the
service account JSON, so prefer running the workflow for that step.
