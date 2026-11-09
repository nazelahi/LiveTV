# Configurable Web Android Download Banner — Design

## Intent

Make the web-only Android download banner fully configurable instead of
hardcoded. Admins should be able to enable/disable it and override its
download URL, version, title, subtitle and button label from the existing
remote-config endpoint, while the app keeps the current GitHub-releases
auto-fetch and built-in constants as fallbacks.

## Goals

- Banner content is driven by remote config when present.
- Remote config fields are optional; missing/empty values fall back to
  the existing behavior (GitHub releases API, then `AppConfig` constants).
- Admin panel exposes the new fields so they can be edited without a rebuild.
- No regression for existing installs: when the config endpoint omits the
  new fields, behavior is unchanged.

## Non-goals

- No new backend service; reuse `/.netlify/functions/config`.
- No changes to the Android in-app update flow (`UpdateNotice`).
- No localization/i18n work beyond the existing strings.

## Constraints

- Remote config is already fetched by `PlaylistRepository._fetchConfig()`
  and cached via Hive; reuse that path rather than adding a second fetch.
- `kIsWeb` gating stays: banner only renders on web.
- Remote `androidDownloadEnabled` is only consulted on web; non-web builds always shrink the banner (native in-app update flow untouched).
- Must keep working offline/cached: cached config values should be usable
  if the network is unavailable (best-effort, same as playlist).

## Approaches considered

1. **Extend existing remote config (chosen).** Add optional fields to the
   config blob and parse them in `_RemoteConfig`. Single source of truth,
   matches admin workflow.
2. Constants + single remote URL override. Smaller but leaves text/enabled
   build-time only.
3. Separate download-config endpoint. Clean separation but duplicates infra.

Chosen: 1.

## Design

### Remote config schema (additive)

```json
{
  "androidDownloadEnabled": true,
  "androidDownloadUrl": "https://github.com/.../releases/latest",
  "androidDownloadVersion": "1.0.1",
  "androidDownloadTitle": "Get the Android app",
  "androidDownloadSubtitle": "Download the native app for smoother playback.",
  "androidDownloadButton": "Download"
}
```

All fields optional. Types: enabled boolean (also accept string "true"/"false"
for safety), others strings. Empty strings are treated as "not set".

### Title composition

When a version is available (remote `androidDownloadVersion` or GitHub
release version), render `"<title> (v<version>)"`. The remote title is the
base; the version is appended automatically so the version field stays
meaningful. With no version, render the title verbatim.

### AppConfig constants (defaults)

Add to `AppConfig`:

- `androidDownloadEnabled` (bool, default `true`)
- `androidDownloadTitle` (String)
- `androidDownloadSubtitle` (String)
- `androidDownloadButton` (String, default `'Download'`)
- `androidDownloadUrl` (String, default `''` meaning "use GitHub releases")

Existing `appReleaseUrl` remains the GitHub releases endpoint.

### Flutter data flow

1. Extend `_RemoteConfig` with the new fields and parse them in
   `_fetchConfig()`.
2. Expose a provider `androidDownloadConfigProvider` (FutureProvider) that:
   - reads remote config (reuse fetch; if null, treat as empty)
   - if remote `androidDownloadUrl` is non-empty use it, else fall back to
     `latestReleaseProvider` (GitHub) then `AppConfig.androidDownloadUrl`
     then the existing hardcoded GitHub releases URL
   - version: remote version → GitHub release version → null
   - enabled: remote enabled → `AppConfig.androidDownloadEnabled`
   - title/subtitle/button: remote → `AppConfig` default
3. `AndroidDownloadBanner` becomes a `ConsumerWidget` watching
   `androidDownloadConfigProvider` and renders `SizedBox.shrink()` when
   disabled or (on non-web) always.

### Caching

Remote config is fetched each build of the provider; reuse the existing
Hive cache? `_fetchConfig` is not cached beyond the FutureProvider. To
keep parity with playlist, cache the parsed config in Hive under a new key
`android_download_config` is not required for v1; the provider's
autoDispose/keepAlive can cache in memory. Keep it simple: FutureProvider
with default, no new Hive keys. (Offline fallback = constants + last
GitHub result if available.)

### Admin panel

- `config.js`: include the new fields in the default config object.
- `update.js`: preserve the new fields when saving playlist config (spread
  existing config values instead of replacing wholesale). Currently
  `readConfig` returns `{ current, version }`; build `next` from a copy of
  `current` so non-playlist fields survive. Apply to both modes.
- `index.html`: add an "Android download banner" card with inputs for
  enabled/url/version/title/subtitle/button and a Save button that POSTs
  `{ androidDownload... }` to a new lightweight handler or reuses update.js
  with a new mode. Simplest: extend update.js to accept these fields in the
  POST body and merge into config, bumping version. Add a "Save banner"
  button in the admin UI.

### Tests

- Unit tests for `_RemoteConfig` parsing of new fields (null/empty/typed).
- Widget test for banner: disabled → shrink; remote override URL used;
  fallback to GitHub URL.
- Admin: manual smoke (not automated).

## Open questions for builder

- Whether to bump config `version` when only banner fields change (yes,
  so apps refresh).
- Whether button label default should remain "Download".

## Calls made by design author

- Version bump on banner-only saves: yes.
- Default enabled: `AppConfig.androidDownloadEnabled` (true).
- No new Hive cache keys in v1.