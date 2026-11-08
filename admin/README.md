# LiveTV Admin (Netlify)

Full-featured admin panel:
- Current playlist info (version, channel/group counts, updated time, URL)
- M3U editor with file picker + drag & drop
- Client + server validation
- Save to Netlify Blobs (bumps version)
- History list with restore

## Environment variables
Set these in Netlify (Site settings → Environment variables):
- `ADMIN_TOKEN` — password for admin panel
- `NETLIFY_SITE_ID` — from Site settings → General → Site details
- `NETLIFY_AUTH_TOKEN` — Netlify personal access token (User settings → Applications)


## App config
Set in `lib/core/constants.dart`:
```dart
static const String configUrl = 'https://YOUR-SITE.netlify.app/.netlify/functions/config';
```

## Local dev
```bash
cd admin
npm install
npx netlify dev
```

## Two ways to change the playlist
1. **Upload contents** — paste or drag an M3U file into the editor, then Save. It is stored
   in Netlify Blobs and served from `/.netlify/functions/playlist`.
2. **External URL** — enter a playlist URL and click *Use this URL*. Nothing is uploaded;
   the app is pointed straight at that URL.

Both bump `version`, so installed apps re-download on their next refresh.
A single URL pasted into the editor is rejected with a pointer to the external-URL box.

## Troubleshooting "save playlist error"
1. Open the site, enter the admin token, click **Run diagnostics**.
2. The panel prints a JSON report:
   - `env.siteID` / `env.token` — must not be `null`.
   - `read.ok` / `write.ok` — `write.ok` must be `true`.
   - If `write.ok` is false, `write.error` contains the exact Blobs error.
3. Saving now also returns the server error text (status code + message).
