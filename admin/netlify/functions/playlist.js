const { getStore } = require("@netlify/blobs");

const siteID = process.env.NETLIFY_SITE_ID || process.env.SITE_ID;
const token = process.env.NETLIFY_AUTH_TOKEN || process.env.NETLIFY_TOKEN || process.env.AUTH_TOKEN;

function getLivetvStore() {
  if (siteID && token) return getStore({ name: "livetv", siteID, token });
  return getStore("livetv");
}

exports.handler = async () => {
  try {
    const store = getLivetvStore();
    const text = await store.get("playlist");
    if (!text) {
      return { statusCode: 404, body: "No playlist stored yet." };
    }
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/x-mpegURL", "Cache-Control": "no-cache" },
      body: text,
    };
  } catch (err) {
    return { statusCode: 500, body: String(err) };
  }
};
