// Relays media URLs for the web build. Browsers block plain http:// streams
// (mixed content) and fetches to hosts without CORS headers, so the app sends
// the target URL here and plays the response from this same HTTPS origin.
//
// Usage: /.netlify/functions/proxy?url=<URL-encoded target>
// Intended for short-lived media requests (HLS segments, playlists, small
// sidecar files), not for unbounded downloads.

const MAX_RESPONSE_BYTES = 12 * 1024 * 1024; // segment-sized cap
const TIMEOUT_MS = 8000; // stay under the default 10s function timeout

function allowedTarget(raw) {
  let target;
  try {
    target = new URL(raw);
  } catch {
    return null;
  }
  if (target.protocol !== "http:" && target.protocol !== "https:") return null;
  // Block loopback / private / link-local addresses so the function cannot be
  // used to reach internal network services.
  if (
    /^(localhost|127\.|10\.|192\.168\.|169\.254\.|0\.0\.0\.0)/i.test(target.hostname) ||
    /^\[?(::1|fc|fd)/i.test(target.hostname)
  ) {
    return null;
  }
  return target;
}

function text(statusCode, message) {
  return { statusCode, headers: { "Content-Type": "text/plain" }, body: message };
}

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
  if (event.httpMethod !== "GET" && event.httpMethod !== "HEAD") {
    return text(405, "Method not allowed");
  }

  const raw = (event.queryStringParameters || {}).url;
  if (!raw) {
    return text(400, "Missing ?url= parameter");
  }
  const target = allowedTarget(raw);
  if (!target) {
    return text(400, "Blocked target URL");
  }

  let upstream;
  try {
    upstream = await fetch(target, {
      headers: { "User-Agent": "LiveTV-Web/1.0", Accept: "*/*" },
      redirect: "follow",
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (err) {
    return text(502, "Upstream request failed: " + (err && err.message ? err.message : String(err)));
  }

  const contentType = upstream.headers.get("content-type") || "application/octet-stream";
  const declared = Number(upstream.headers.get("content-length"));
  if (Number.isFinite(declared) && declared > MAX_RESPONSE_BYTES) {
    return text(502, "Upstream response too large");
  }

  const buffer = await upstream.arrayBuffer();
  if (buffer.byteLength > MAX_RESPONSE_BYTES) {
    return text(502, "Upstream response too large");
  }

  return {
    statusCode: upstream.status,
    headers: {
      "Content-Type": contentType,
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": "*",
    },
    body: Buffer.from(buffer).toString("base64"),
    isBase64Encoded: true,
  };
};
