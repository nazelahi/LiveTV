# Changelog

## Unreleased

- Web: replaced the dead corsproxy.io relay (now returns 403 for anonymous
  requests) with a self-hosted proxy function on the admin Netlify site
  (`admin/netlify/functions/proxy.js`); plain http:// streams and the GitHub
  checksum sidecar are relayed through it again.
- Web: removed the 4-second boot-overlay timeout that left a blank white page
  on slow connections; the page background now matches the app theme.
- Admin API: playlist restore no longer wipes the Android download banner
  settings and other config fields; restores are recorded in history.
- Admin API: banner-only saves no longer bump the playlist version, so clients
  no longer re-download the full playlist for a banner text change.
- Admin API: superseded playlist history blobs are pruned; admin token checks
  are timing-safe; OPTIONS preflights are answered.
- EPG icons and M3U logos are upgraded http:// → https:// at parse time.

## 1.0.0

- Initial release.
- Auto-loads and caches the BDIX-IPTV playlist; refreshes when stale.
- In-app playback via media_kit (HLS, MPEG-TS, DASH, FLV).
- Favourites, search, categories, adult-section toggle.
- Desktop 3-pane shell and mobile layout.
- Optional EPG download for now/next info.
- In-app update check via GitHub releases.