const { getStore } = require("@netlify/blobs");

const siteID = process.env.NETLIFY_SITE_ID || process.env.SITE_ID;
const token = process.env.NETLIFY_AUTH_TOKEN || process.env.NETLIFY_TOKEN || process.env.AUTH_TOKEN;

function getLivetvStore() {
  if (siteID && token) return getStore({ name: "livetv", siteID, token });
  return getStore("livetv");
}

function json(statusCode, payload) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  };
}

const MAX_PLAYLIST_BYTES = 4 * 1024 * 1024;

function normalizeText(text) {
  let out = String(text || "");
  // A UTF-16 file decoded as UTF-8 leaves NUL bytes between ASCII characters.
  const sample = out.slice(0, 2000);
  const nuls = (sample.match(/\u0000/g) || []).length;
  if (nuls > sample.length * 0.1) out = out.replace(/\u0000/g, "");
  return out.replace(/^\uFEFF/, "");
}

function analyze(m3u) {
  const lines = normalizeText(m3u).split(/\r\n|\r|\n/);
  let channels = 0;
  const groups = new Set();
  let currentGroup = "";
  for (const raw of lines) {
    const line = raw.trim().replace(/^\uFEFF/, "");
    if (/^#EXTINF\b/i.test(line)) {
      channels++;
      const m = line.match(/group-title="([^"]*)"/i);
      if (m && m[1]) currentGroup = m[1];
      else currentGroup = currentGroup || "Uncategorised";
      groups.add(currentGroup);
    } else if (/^#EXTGRP:/i.test(line)) {
      currentGroup = line.slice(8).trim();
    }
  }
  if (channels === 0) return null;
  return { channels, groups: groups.size || 1, lines: lines.length };
}

async function readConfig(store) {
  const current = (await store.get("config", { type: "json" })) || {};
  const version =
    current && typeof current === "object" ? Number(current.version) || 0 : 0;
  return { current, version };
}

async function fetchPlaylistStats(url) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "LiveTV-Admin/1.0" },
      signal: controller.signal,
    });
    if (!res.ok) {
      return { warning: "The URL returned HTTP " + res.status + "." };
    }
    const text = await res.text();
    const stats = analyze(text);
    if (!stats) {
      return { warning: "The URL responded, but no #EXTINF lines were found in it." };
    }
    return { stats };
  } catch (err) {
    return {
      warning:
        "The URL could not be fetched from the server (" +
        (err && err.message ? err.message : String(err)) +
        "). It was saved anyway; the app will fetch it directly.",
    };
  } finally {
    clearTimeout(timer);
  }
}

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return { statusCode: 405, body: "Method not allowed" };
  }
  const adminToken = String(process.env.ADMIN_TOKEN || "").trim();
  if (!adminToken) {
    return { statusCode: 500, body: "ADMIN_TOKEN is not configured on the server" };
  }
  if (String(event.headers["x-admin-token"] || "").trim() !== adminToken) {
    return { statusCode: 401, body: "Unauthorized" };
  }

  const rawBody = event.body || "";
  const bodyBytes = Buffer.byteLength(rawBody, "utf8");

  let body;
  try {
    body = JSON.parse(rawBody || "{}");
  } catch (err) {
    return json(400, {
      stage: "parse-body",
      error: "Invalid JSON request body",
      message: err && err.message,
      bodyBytes,
    });
  }

  let externalUrls = [];
  if (Array.isArray(body.playlistUrls)) {
    externalUrls = body.playlistUrls
      .map((value) => String(value == null ? "" : value).trim())
      .filter(Boolean);
    if (body.playlistUrls.length > 0 && externalUrls.length === 0) {
      return json(400, {
        stage: "validate-url",
        error: "Empty playlist URL list",
        message: "playlistUrls was provided but contained no usable URLs.",
        bodyBytes,
      });
    }
  } else if (typeof body.playlistUrl === "string" && body.playlistUrl.trim()) {
    externalUrls = [body.playlistUrl.trim()];
  }

  let store;
  try {
    store = getLivetvStore();
  } catch (err) {
    return json(500, {
      stage: "get-store",
      error: "Could not open the storage bucket",
      message: err && err.message,
    });
  }

  // Mode 1: point the app at one or more externally hosted playlists.
  if (externalUrls.length > 0) {
    const invalid = externalUrls.find((url) => !/^https?:\/\//i.test(url));
    if (invalid) {
      return json(400, {
        stage: "validate-url",
        error: "Invalid URL",
        message: "Every playlist URL must start with http:// or https://",
        playlistUrl: invalid,
      });
    }

    try {
      const { version } = await readConfig(store);
      const results = await Promise.all(
        externalUrls.map(async (url) => {
          const outcome = await fetchPlaylistStats(url);
          return { url, ...outcome };
        }),
      );
      const warnings = results
        .filter((result) => result.warning)
        .map((result) => result.url + ": " + result.warning);
      const totalChannels = results.reduce(
        (sum, result) => sum + (result.stats ? result.stats.channels : 0),
        0,
      );
      const totalGroups = results.reduce(
        (sum, result) => sum + (result.stats ? result.stats.groups : 0),
        0,
      );
      const hasStats = results.some((result) => result.stats);

      const next = {
        playlistUrls: externalUrls,
        playlistUrl: externalUrls[0],
        version: version + 1,
        updatedAt: new Date().toISOString(),
        channelCount: hasStats ? totalChannels : null,
        groupCount: hasStats ? totalGroups : null,
        source: "external",
        results: results.map((result) => ({
          url: result.url,
          channelCount: result.stats ? result.stats.channels : null,
          groupCount: result.stats ? result.stats.groups : null,
          warning: result.warning || null,
        })),
      };
      if (warnings.length > 0) next.warning = warnings.join(" | ");
      await store.setJSON("config", next);
      return json(200, next);
    } catch (err) {
      return json(500, {
        stage: "set-config",
        error: "Save failed at set-config",
        message: err && err.message,
        stack: err && err.stack,
      });
    }
  }

  // Mode 2: upload playlist contents, hosted by this site.
  const m3u = normalizeText(body.m3u || "").trim();
  if (!m3u) {
    return json(400, {
      stage: "validate",
      error: "Empty playlist",
      message: "Paste or load an M3U file before saving.",
      bodyBytes,
    });
  }

  const singleUrl = m3u.match(/^[a-z]+:\/\/\S+$/i);
  if (singleUrl && !/#EXTINF/i.test(m3u)) {
    return json(400, {
      stage: "validate",
      error: "This is a single URL, not playlist contents",
      message:
        "Use the external playlist URL option instead of pasting the URL into the editor.",
      playlistUrl: m3u,
      bodyBytes,
    });
  }

  const playlistBytes = Buffer.byteLength(m3u, "utf8");
  if (playlistBytes > MAX_PLAYLIST_BYTES) {
    return json(413, {
      stage: "validate",
      error: "Playlist too large",
      message:
        "Playlist is " + playlistBytes + " bytes; the limit is " + MAX_PLAYLIST_BYTES + " bytes.",
      bodyBytes,
      playlistBytes,
    });
  }

  const stats = analyze(m3u);
  if (!stats) {
    return json(400, {
      stage: "validate",
      error: "Invalid playlist: no #EXTINF channels found",
      message: "No lines starting with #EXTINF were found in the submitted text.",
      bodyBytes,
      playlistBytes,
      firstLines: m3u.split(/\r\n|\r|\n/).slice(0, 3),
      looksLikeHtml: /^\s*<(!doctype|html)/i.test(m3u),
    });
  }

  let stage = "get-config";
  try {
    stage = "set-playlist";
    await store.set("playlist", m3u);

    stage = "get-config";
    const { version } = await readConfig(store);
    const nextVersion = version + 1;
    const hostedUrl = `${process.env.URL || ""}/.netlify/functions/playlist`;
    const next = {
      playlistUrls: [hostedUrl],
      playlistUrl: hostedUrl,
      version: nextVersion,
      updatedAt: new Date().toISOString(),
      channelCount: stats.channels,
      groupCount: stats.groups,
      source: "upload",
    };

    stage = "set-config";
    await store.setJSON("config", next);

    stage = "get-history";
    const history = (await store.get("history", { type: "json" })) || [];
    const list = Array.isArray(history) ? history : [];

    // Each playlist version is its own blob. Keeping every full M3U inside the
    // single "history" JSON object would rewrite megabytes on every save.
    stage = "set-history";
    await store.set(`history/${nextVersion}`, m3u);
    const meta = list
      .filter((entry) => entry && entry.version !== nextVersion)
      .map((entry) => ({
        version: entry.version,
        updatedAt: entry.updatedAt,
        channelCount: entry.channelCount,
        groupCount: entry.groupCount,
        restoredFrom: entry.restoredFrom,
      }));
    meta.unshift({
      version: nextVersion,
      updatedAt: next.updatedAt,
      channelCount: stats.channels,
      groupCount: stats.groups,
    });
    await store.setJSON("history", meta.slice(0, 10));

    return json(200, next);
  } catch (err) {
    return json(500, {
      stage,
      error: "Save failed at " + stage,
      message: err && err.message,
      stack: err && err.stack,
      bodyBytes,
      playlistBytes,
      channels: stats.channels,
    });
  }
};
