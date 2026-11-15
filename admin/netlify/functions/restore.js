const { getLivetvStore, adminGate, CORS_HEADERS } = require("./_lib");

const hostedPlaylistUrl = () =>
  `${process.env.URL || ""}/.netlify/functions/playlist`;

exports.handler = async (event) => {
  const gate = adminGate(event, "POST");
  if (gate) return gate;

  let body;
  try {
    body = JSON.parse(event.body || "{}");
  } catch {
    return { statusCode: 400, headers: CORS_HEADERS, body: "Invalid JSON" };
  }
  const targetVersion = Number(body.version);
  if (!targetVersion) {
    return { statusCode: 400, headers: CORS_HEADERS, body: "Missing version" };
  }

  try {
    const store = getLivetvStore();
    const history = (await store.get("history", { type: "json" })) || [];
    const list = Array.isArray(history) ? history : [];
    const entry = list.find((h) => h.version === targetVersion);
    if (!entry) {
      return { statusCode: 404, headers: CORS_HEADERS, body: "Version not found" };
    }

    // Newer saves keep each playlist in its own blob; older entries embed it.
    const playlistText = entry.m3u || (await store.get(`history/${targetVersion}`));
    if (!playlistText) {
      return {
        statusCode: 404,
        headers: CORS_HEADERS,
        body: "Playlist content for that version is missing",
      };
    }

    await store.set("playlist", playlistText);

    const current = (await store.get("config", { type: "json" })) || {};
    // Spread the existing config so unrelated fields the admin set elsewhere
    // (Android download banner overrides, source metadata, ...) survive the
    // restore instead of being wiped.
    const next = {
      ...(current && typeof current === "object" ? current : {}),
      playlistUrls: [hostedPlaylistUrl()],
      playlistUrl: hostedPlaylistUrl(),
      source: "upload",
      restoredFrom: targetVersion,
      version: (Number(current.version) || 0) + 1,
      updatedAt: new Date().toISOString(),
      channelCount: entry.channelCount,
      groupCount: entry.groupCount,
    };
    await store.setJSON("config", next);

    // Record the restore as its own history entry so the panel lists it and
    // future saves can prune it like any other version.
    const slim = list
      .filter((e) => e && e.version !== next.version)
      .map(({ m3u, ...rest }) => rest);
    slim.unshift({
      version: next.version,
      updatedAt: next.updatedAt,
      channelCount: next.channelCount,
      groupCount: next.groupCount,
      restoredFrom: targetVersion,
    });
    const keptMeta = slim.slice(0, 10);
    await store.setJSON("history", keptMeta);
    // Drop blobs for versions that fell out of the kept window.
    const keptVersions = new Set(keptMeta.map((e) => e.version));
    await Promise.all(
      list
        .filter((e) => e && !keptVersions.has(e.version))
        .map((e) => store.delete(`history/${e.version}`).catch(() => {})),
    );

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      body: JSON.stringify(next),
    };
  } catch (err) {
    return { statusCode: 500, headers: CORS_HEADERS, body: String(err) };
  }
};
