const { getLivetvStore, adminGate, CORS_HEADERS } = require("./_lib");

exports.handler = async (event) => {
  const gate = adminGate(event, "GET");
  if (gate) return gate;
  try {
    const store = getLivetvStore();
    const history = (await store.get("history", { type: "json" })) || [];
    const slim = history.map(({ m3u, ...rest }) => rest);
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      body: JSON.stringify(slim),
    };
  } catch (err) {
    return { statusCode: 500, headers: CORS_HEADERS, body: String(err) };
  }
};
