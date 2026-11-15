const { getLivetvStore } = require("./_lib");

exports.handler = async (event) => {
  if (event.httpMethod === "OPTIONS") {
    return {
      statusCode: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
      },
      body: "",
    };
  }
  try {
    const store = getLivetvStore();
    const text = await store.get("playlist");
    if (!text) {
      return { statusCode: 404, body: "No playlist stored yet." };
    }
    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/x-mpegURL",
        "Cache-Control": "no-cache",
        "Access-Control-Allow-Origin": "*",
      },
      body: text,
    };
  } catch (err) {
    return { statusCode: 500, body: String(err) };
  }
};
