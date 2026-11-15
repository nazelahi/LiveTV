// Shared helpers for the LiveTV Netlify functions.
const crypto = require("crypto");
const { getStore } = require("@netlify/blobs");

const siteID = process.env.NETLIFY_SITE_ID || process.env.SITE_ID;
const token = process.env.NETLIFY_AUTH_TOKEN || process.env.NETLIFY_TOKEN || process.env.AUTH_TOKEN;

function getLivetvStore() {
  if (siteID && token) return getStore({ name: "livetv", siteID, token });
  return getStore("livetv");
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, x-admin-token",
};

function preflight(event) {
  if (event.httpMethod === "OPTIONS") {
    return { statusCode: 204, headers: CORS_HEADERS, body: "" };
  }
  return null;
}

function timingSafeEqual(a, b) {
  const bufA = Buffer.from(String(a == null ? "" : a));
  const bufB = Buffer.from(String(b == null ? "" : b));
  if (bufA.length !== bufB.length) {
    // Burn a comparison of identical length so the timing does not reveal
    // how much of the token matched.
    crypto.timingSafeEqual(bufA, bufA);
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}

// Returns true when the request carries the correct admin token.
function adminTokenOk(event) {
  const adminToken = String(process.env.ADMIN_TOKEN || "").trim();
  if (!adminToken) return false;
  return timingSafeEqual(
    String(event.headers["x-admin-token"] || "").trim(),
    adminToken,
  );
}

function unauthorized() {
  return { statusCode: 401, headers: CORS_HEADERS, body: "Unauthorized" };
}

function missingAdminToken() {
  return {
    statusCode: 500,
    headers: CORS_HEADERS,
    body: "ADMIN_TOKEN is not configured on the server",
  };
}

// Convenience: run the standard method/auth gate for an admin endpoint.
// Returns a response to send immediately, or null to continue.
function adminGate(event, allowedMethod) {
  const options = preflight(event);
  if (options) return options;
  if (allowedMethod && event.httpMethod !== allowedMethod) {
    return { statusCode: 405, headers: CORS_HEADERS, body: "Method not allowed" };
  }
  const adminToken = String(process.env.ADMIN_TOKEN || "").trim();
  if (!adminToken) return missingAdminToken();
  if (!adminTokenOk(event)) return unauthorized();
  return null;
}

module.exports = {
  siteID,
  token,
  getLivetvStore,
  CORS_HEADERS,
  preflight,
  timingSafeEqual,
  adminTokenOk,
  unauthorized,
  missingAdminToken,
  adminGate,
};
