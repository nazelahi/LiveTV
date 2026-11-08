const { getStore } = require("@netlify/blobs");

const siteID = process.env.NETLIFY_SITE_ID || process.env.SITE_ID;
const token = process.env.NETLIFY_AUTH_TOKEN || process.env.NETLIFY_TOKEN || process.env.AUTH_TOKEN;

function getLivetvStore() {
  if (siteID && token) return getStore({ name: "livetv", siteID, token });
  return getStore("livetv");
}

exports.handler = async (event) => {
  if (event.httpMethod !== "GET") {
    return { statusCode: 405, body: "Method not allowed" };
  }
  const adminToken = String(process.env.ADMIN_TOKEN || "").trim();
  if (!adminToken) {
    return { statusCode: 500, body: "ADMIN_TOKEN is not configured on the server" };
  }
  if (String(event.headers["x-admin-token"] || "").trim() !== adminToken) {
    return { statusCode: 401, body: "Unauthorized" };
  }
  try {
    const store = getLivetvStore();
    const history = (await store.get("history", { type: "json" })) || [];
    const slim = history.map(({ m3u, ...rest }) => rest);
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(slim),
    };
  } catch (err) {
    return { statusCode: 500, body: String(err) };
  }
};
