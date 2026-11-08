const { getStore } = require("@netlify/blobs");

const siteID = process.env.NETLIFY_SITE_ID || process.env.SITE_ID;
const token = process.env.NETLIFY_AUTH_TOKEN || process.env.NETLIFY_TOKEN || process.env.AUTH_TOKEN;

function getLivetvStore() {
  if (siteID && token) return getStore({ name: "livetv", siteID, token });
  return getStore("livetv");
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

  let body;
  try {
    body = JSON.parse(event.body || "{}");
  } catch {
    return { statusCode: 400, body: "Invalid JSON" };
  }
  const targetVersion = Number(body.version);
  if (!targetVersion) {
    return { statusCode: 400, body: "Missing version" };
  }

  try {
    const store = getLivetvStore();
    const history = (await store.get("history", { type: "json" })) || [];
    const list = Array.isArray(history) ? history : [];
    const entry = list.find((h) => h.version === targetVersion);
    if (!entry) {
      return { statusCode: 404, body: "Version not found" };
    }

    // Newer saves keep each playlist in its own blob; older entries embed it.
    const playlistText = entry.m3u || (await store.get(`history/${targetVersion}`));
    if (!playlistText) {
      return { statusCode: 404, body: "Playlist content for that version is missing" };
    }

    await store.set("playlist", playlistText);

    const current = (await store.get("config", { type: "json" })) || { version: 0 };
    const next = {
      playlistUrl: `${process.env.URL || ""}/.netlify/functions/playlist`,
      version: (current.version || 0) + 1,
      updatedAt: new Date().toISOString(),
      channelCount: entry.channelCount,
      groupCount: entry.groupCount,
      restoredFrom: targetVersion,
    };
    await store.setJSON("config", next);

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(next),
    };
  } catch (err) {
    return { statusCode: 500, body: String(err) };
  }
};
