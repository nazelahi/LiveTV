const { getStore } = require("@netlify/blobs");

const siteID = process.env.NETLIFY_SITE_ID || process.env.SITE_ID;
const token = process.env.NETLIFY_AUTH_TOKEN || process.env.NETLIFY_TOKEN || process.env.AUTH_TOKEN;

function getLivetvStore() {
  if (siteID && token) return getStore({ name: "livetv", siteID, token });
  return getStore("livetv");
}

function mask(value) {
  if (!value) return null;
  return value.slice(0, 4) + "..." + "(" + value.length + " chars)";
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

  const report = {
    env: {
      siteID: mask(siteID),
      token: mask(token),
      URL: process.env.URL || null,
      url: process.env.DEPLOY_URL || null,
      adminTokenLen: (process.env.ADMIN_TOKEN || "").length,
    },
    read: null,
    write: null,
  };

  let store;
  try {
    store = getLivetvStore();
    report.read = { ok: true, value: await store.get("config", { type: "json" }) };
  } catch (err) {
    report.read = { ok: false, error: String(err), stack: err && err.stack };
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(report, null, 2),
    };
  }

  try {
    const probe = "debug-" + Date.now();
    await store.set("debug-probe", probe);
    const readBack = await store.get("debug-probe");
    report.write = { ok: readBack === probe, wrote: probe, readBack };
    await store.delete("debug-probe");
  } catch (err) {
    report.write = { ok: false, error: String(err), message: err && err.message, stack: err && err.stack };
  }

  return {
    statusCode: 200,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(report, null, 2),
  };
};
