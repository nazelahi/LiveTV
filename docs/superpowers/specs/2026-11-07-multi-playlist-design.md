# Multi-playlist support design

Date: 2026-11-07
Status: approved approach (Approach A)

## Intent

Allow an admin to configure more than one M3U playlist through the existing
admin panel + config endpoint. The app downloads all configured playlists,
merges them into one channel list, and removes duplicate channels by
**name + group** (first configured playlist wins). The result stays
source-agnostic: users never see which playlist a channel came from.

## Why

Today the app supports a single `playlistUrl`. Admins who want to combine
regional/international sources must concatenate files manually before
uploading. Native multi-playlist support lets the admin point at several
hosted playlists and lets the app handle merging and deduplication.

## Goals

- Config endpoint can return a list of playlist URLs (`playlistUrls`).
- App fetches every URL, parses each independently, merges, dedups by
  case-insensitive `name + group`.
- Group list is the union of all playlists' groups, in first-appearance
  order, with duplicates collapsed case-insensitively (first spelling kept).
- First playlist in config order has precedence for duplicate channels
  (its `id`, `url`, `logo`, etc. are kept).
- Backward compatible with old config (`playlistUrl` only) and old cached
  data.
- Offline cache still works for the merged result.
- Admin panel can add/remove/reorder playlist URLs.

## Non-goals

- No per-playlist tabs or source labels in the app UI.
- No user-managed playlists inside the app.
- No smart quality-based dedup (e.g. picking HD over SD); precedence is
  config order only.
- No partial-failure UI beyond the existing refresh error/snackbar.

## Constraints

- Existing parser (`parseM3u`) dedups by `id` within one playlist; do not
  change that behavior. Cross-playlist dedup happens after parsing.
- Cache format must remain readable by current code paths or be versioned.
- Remote config version is a single integer; bumping it refreshes all.
- Admin auth and storage (Netlify Blobs) unchanged.

## Approach A: multi-URL config + client-side merge

Chosen over server-side merging so dedup is testable in Dart and the app
keeps working offline from cache.

## Data model / config contract

App config response (new fields optional):

```json
{
  "playlistUrls": ["https://.../a.m3u", "https://.../b.m3u"],
  "playlistUrl": "https://.../a.m3u",
  "version": 12,
  ...
}
```

- `playlistUrls`: array of http(s) URLs. If present and non-empty, use it.
  An empty array is treated as missing.
- `playlistUrl`: legacy single URL. If `playlistUrls` missing, fall back to
  `[playlistUrl]`. If both missing, use `AppConfig.playlistUrl`.
- Keep `playlistUrl` in responses for old clients.

## App changes

### `PlaylistRepository`

- Add `mergePlaylists(List<ParsedPlaylist>) -> ParsedPlaylist` (static,
  testable): dedup by lowercased `name|group`; preserve channel and group
  order; first occurrence wins.
- `_fetchConfig`: parse `playlistUrls` array or `playlistUrl` string into
  `List<String> urls` inside `_RemoteConfig` (add `urls` field; keep
  `url` as first for compat).
- `fetch()`:
  - Resolve url list from config/cached/default.
  - For each url: GET, parse with `compute(parseM3u, raw)`. On success with
    non-empty channels, collect `(raw, parsed)`. On failure of one url,
    skip it and continue. If none succeed, throw `PlaylistException`.
  - Merge collected parsed parts with `mergePlaylists`.
  - Cache raw as a JSON-encoded list of individual raw playlist strings under
    `playlistRawKey` (preserves per-playlist `id` dedup scope on fallback
    re-parse), plus merged parsed + url list + version.
- `readCache` / `readCacheSync`: if parsed cache missing, decode raw cache as
  a JSON string list when possible (legacy single string treated as one
  item), parse each item with `parseM3u`, merge with `mergePlaylists`.
- URL cache: store JSON array of urls under `playlistUrlKey`. Read helper
  `_cachedUrls()` returns `List<String>?`, handling legacy single-string
  values (empty array treated as missing).
- `playlistSourceUrlProvider`: if one url, return it; if multiple, return
  `Multiple playlists (N)`.

### `PlaylistState` / codec

No shape change. `channels`/`groups` already represent the merged result.

### Providers

`PlaylistNotifier` unchanged; it calls `fetch()`/`fetchIfUpdated()`.

## Admin panel + functions

### `config.js`

- Default config gains `playlistUrls: [defaultUrl]` while keeping
  `playlistUrl`.
- No other change needed (just serves stored config).

### `update.js`

- Accept `body.playlistUrls` (array) OR `body.playlistUrl` (string).
- Validate each URL is http(s).
- If array: store `playlistUrls`, `playlistUrl = first`, fetch stats per URL
  (sum channel/group counts), bump version.
- If single URL: store both `playlistUrl` and `playlistUrls: [url]`.
- Upload mode: store `playlistUrls: [hostedUrl]`.

### Admin UI (`index.html`)

- Replace single external URL input with a textarea (one URL per line) or
  dynamic list. Keep "Load into editor" for the first URL (optional).
- Show per-URL validation results.

## Cache migration

- `playlistUrlKey` may contain a legacy single URL string. `_cachedUrls()`
  handles both.
- Combined raw cache uses the same key; old single-raw caches parse fine.
- `_cacheVersion` in codec unchanged (shape unchanged).

## Failure handling

- Partial success: skip failed/empty playlists; succeed if at least one
  non-empty playlist.
- Total failure: throw `PlaylistException` with a message listing failed
  URLs.
- `refresh()` keeps previous cached state on throw (existing behavior).

## Testing

- Unit test `mergePlaylists`:
  - dedups by name+group case-insensitively
  - first playlist wins
  - groups merged/ordered, duplicates collapsed
  - empty inputs
- Repository cache tests updated for url-list cache.
- Parser tests unchanged.

## Resolved open questions (builder check)

1. Empty playlist (HTTP 200, zero channels): treated as a failed URL, skipped,
   and included in the `PlaylistException` message as "no channels". Success
   requires at least one non-empty playlist.
2. Cached URL list scope: cache the full resolved URL list (including URLs
   that failed this fetch), so the next refresh retries them. Raw cache may
   contain fewer items.
3. Admin precedence: if both `playlistUrls` and `playlistUrl` are present,
   `playlistUrls` wins when non-empty.
4. Empty `playlistUrls` array in admin: rejected with HTTP 400.
5. Admin response contract: response includes `playlistUrls`, `playlistUrl`,
   `version`, `channelCount` (sum over successful fetches), `groupCount`
   (sum over successful fetches), and `results: [{ url, channelCount,
   groupCount, warning? }]`. Top-level `warning` is set if any URL failed.
6. Legacy config normalization: `config.js` adds `playlistUrls` to older
   stored configs on read, falling back to `[playlistUrl]`.

Builder may still choose textarea vs dynamic list in admin UI.

Let's write.<|end|><|start|> fileList to=assistant<|channel|>analysis <|constrain|>xml<|message|><rfl:parameter name="path">
/Users/sabbir/Downloads/LiveTV/docs/superpowers/specs/2026-11-07-multi-playlist-design.md