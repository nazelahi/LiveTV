const { getStore } = require("@netlify/blobs");

const siteID = process.env.NETLIFY_SITE_ID || process.env.SITE_ID;
const token = process.env.NETLIFY_AUTH_TOKEN || process.env.NETLIFY_TOKEN || process.env.AUTH_TOKEN;

function getLivetvStore() {
  if (siteID && token) return getStore({ name: "livetv", siteID, token });
  return getStore("livetv");
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: CORS_HEADERS, body: '' };
  }
  try {
    const store = getLivetvStore();
    const defaultPlaylistUrl = "https://raw.githubusercontent.com/saeidrahmanbd/BDIX-IPTV/main/International-Playlist.m3u";
    const config = (await store.get("config", { type: "json" })) || {
      playlistUrls: [defaultPlaylistUrl],
      playlistUrl: defaultPlaylistUrl,
      version: 0,
      updatedAt: null,
      channelCount: 0,
      groupCount: 0,
      androidDownloadEnabled: true,
      androidDownloadTitle: "Get the Android app",
      androidDownloadSubtitle: "Download the native app for smoother playback.",
      androidDownloadButton: "Download",
      androidDownloadUrl: "",
      androidDownloadVersion: "",
    };
    if (!config.playlistUrl) {
      config.playlistUrl = defaultPlaylistUrl;
    }
    if (!Array.isArray(config.playlistUrls) || config.playlistUrls.length === 0) {
      config.playlistUrls = [config.playlistUrl];
    }
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
        ...CORS_HEADERS,
      },
      body: JSON.stringify(config),
    };
  } catch (err) {
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      body: JSON.stringify({ error: String(err), siteID: !!siteID, token: !!token }),
    };
  }
};
