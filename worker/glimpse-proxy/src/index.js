const GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";
const VOYAGE_EMBEDDINGS_URL = "https://api.voyageai.com/v1/embeddings";
const APP_CHECK_JWKS_URL = "https://firebaseappcheck.googleapis.com/v1/jwks";

const GEMINI_MODELS = new Set(["gemini-2.5-flash", "gemini-2.0-flash-lite"]);
const VOYAGE_MODELS = new Set(["voyage-3-lite"]);

const MAX_GEMINI_BODY_BYTES = 48 * 1024;
const MAX_EMBED_BODY_BYTES = 32 * 1024;
const MAX_EMBED_ITEMS = 32;
const MAX_EMBED_ITEM_CHARS = 3000;
const MAX_GEMINI_OUTPUT_TOKENS = 2048;

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
};

let cachedJwks = null;
let cachedJwksUntil = 0;

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    const url = new URL(request.url);

    try {
      if (url.pathname === "/health") {
        return json({ ok: true }, 200, request);
      }

      if (request.method !== "POST") {
        return json({ error: "method_not_allowed" }, 405, request);
      }

      if (url.pathname === "/internal/gemini") {
        requireInternalSecret(request, env);
        return await handleGemini(request, env, "worker:glimpse-enrichment-backend");
      }

      const appId = await requireAppCheck(request, env);
      const userId = normalizedUserId(request.headers.get("x-user-id"));

      if (url.pathname === "/gemini") {
        await enforceRateLimit(request, env, "gemini", userId, 60, 3600);
        return await handleGemini(request, env, appId);
      }

      if (url.pathname === "/embed" || url.pathname === "/voyage") {
        await enforceRateLimit(request, env, "embed", userId, 240, 86400);
        return await handleEmbedding(request, env, appId);
      }

      return json({ error: "not_found" }, 404, request);
    } catch (error) {
      if (error instanceof ProxyError) {
        return json({ error: error.code }, error.status, request);
      }
      return json(
        { error: "proxy_error", message: safeErrorMessage(error) },
        500,
        request,
      );
    }
  },
};

async function handleGemini(request, env, appId) {
  if (!env.GEMINI_KEY) {
    throw new ProxyError("missing_gemini_key", 500);
  }

  const body = await readJsonWithLimit(request, MAX_GEMINI_BODY_BYTES);
  const model = sanitizeModel(body.model || "gemini-2.5-flash", GEMINI_MODELS);
  delete body.model;
  validateGeminiBody(body);

  const upstream = `${GEMINI_BASE_URL}/models/${model}:generateContent?key=${env.GEMINI_KEY}`;
  const response = await fetch(upstream, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-glimpse-app-id": appId,
    },
    body: JSON.stringify(body),
  });

  return proxyJson(response, request);
}

function requireInternalSecret(request, env) {
  const expected = env.INTERNAL_PROXY_SECRET || env.DEV_SECRET;
  if (!expected) {
    throw new ProxyError("missing_internal_secret", 500);
  }
  const auth = request.headers.get("authorization") || "";
  const header = request.headers.get("x-internal-secret") || "";
  if (auth !== `Bearer ${expected}` && header !== expected) {
    throw new ProxyError("unauthorized", 401);
  }
}

async function handleEmbedding(request, env, appId) {
  if (!env.VOYAGE_KEY) {
    throw new ProxyError("missing_voyage_key", 500);
  }

  const body = await readJsonWithLimit(request, MAX_EMBED_BODY_BYTES);
  const model = sanitizeModel(body.model || "voyage-3-lite", VOYAGE_MODELS);
  body.model = model;
  validateEmbeddingBody(body);

  const response = await fetch(VOYAGE_EMBEDDINGS_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${env.VOYAGE_KEY}`,
      "x-glimpse-app-id": appId,
    },
    body: JSON.stringify(body),
  });

  return proxyJson(response, request);
}

async function requireAppCheck(request, env) {
  if (!env.FIREBASE_PROJECT_NUMBER) {
    throw new ProxyError("missing_app_check_config", 500);
  }

  const token = request.headers.get("x-firebase-appcheck");
  if (!token) {
    throw new ProxyError("missing_app_check", 401);
  }

  const { header, payload, signingInput, signature } = decodeJwt(token);
  if (header.alg !== "RS256" || header.typ !== "JWT") {
    throw new ProxyError("invalid_app_check", 401);
  }

  const jwk = await findJwk(header.kid, env);
  if (!jwk) {
    throw new ProxyError("invalid_app_check", 401);
  }

  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    signature,
    new TextEncoder().encode(signingInput),
  );
  if (!ok) {
    throw new ProxyError("invalid_app_check", 401);
  }

  const now = Math.floor(Date.now() / 1000);
  if (payload.exp <= now) {
    throw new ProxyError("expired_app_check", 401);
  }
  if (payload.iss !== `https://firebaseappcheck.googleapis.com/${env.FIREBASE_PROJECT_NUMBER}`) {
    throw new ProxyError("invalid_app_check_issuer", 401);
  }
  const audience = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  if (!audience.includes(`projects/${env.FIREBASE_PROJECT_NUMBER}`)) {
    throw new ProxyError("invalid_app_check_audience", 401);
  }

  const allowedAppIds = parseAllowedAppIds(env.FIREBASE_APP_IDS);
  if (allowedAppIds.size > 0 && !allowedAppIds.has(payload.sub)) {
    throw new ProxyError("app_not_allowed", 403);
  }

  return payload.sub;
}

async function findJwk(kid, env) {
  const jwks = await getJwks(env);
  return (jwks.keys || []).find((key) => key.kid === kid);
}

async function getJwks(env) {
  const now = Date.now();
  if (cachedJwks && cachedJwksUntil > now) {
    return cachedJwks;
  }

  const response = await fetch(APP_CHECK_JWKS_URL);
  if (!response.ok) {
    throw new ProxyError("app_check_jwks_unavailable", 503);
  }

  cachedJwks = await response.json();
  const maxAge = parseMaxAge(response.headers.get("cache-control")) || 21600;
  cachedJwksUntil = now + maxAge * 1000;
  return cachedJwks;
}

async function enforceRateLimit(request, env, route, userId, max, windowSeconds) {
  if (!env.RATE_LIMITS) return;

  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const windowId = Math.floor(Date.now() / (windowSeconds * 1000));
  const key = `rl:${route}:${userId}:${ip}:${windowId}`;
  const current = Number((await env.RATE_LIMITS.get(key)) || "0");
  if (current >= max) {
    throw new ProxyError("rate_limited", 429);
  }
  await env.RATE_LIMITS.put(key, String(current + 1), {
    expirationTtl: windowSeconds + 60,
  });
}

async function readJsonWithLimit(request, maxBytes) {
  const contentType = request.headers.get("content-type") || "";
  if (!contentType.toLowerCase().includes("application/json")) {
    throw new ProxyError("expected_json", 415);
  }

  const text = await request.text();
  if (new TextEncoder().encode(text).length > maxBytes) {
    throw new ProxyError("request_too_large", 413);
  }

  try {
    return JSON.parse(text);
  } catch {
    throw new ProxyError("malformed_json", 400);
  }
}

function validateGeminiBody(body) {
  if (!Array.isArray(body.contents) || body.contents.length === 0) {
    throw new ProxyError("invalid_gemini_body", 400);
  }

  const generationConfig = body.generationConfig || {};
  const maxOutputTokens = Number(generationConfig.maxOutputTokens || MAX_GEMINI_OUTPUT_TOKENS);
  generationConfig.maxOutputTokens = Math.min(maxOutputTokens, MAX_GEMINI_OUTPUT_TOKENS);
  body.generationConfig = generationConfig;
}

function validateEmbeddingBody(body) {
  const input = body.input;
  const items = Array.isArray(input) ? input : [input];
  if (items.length === 0 || items.length > MAX_EMBED_ITEMS) {
    throw new ProxyError("invalid_embedding_batch", 400);
  }
  for (const item of items) {
    if (typeof item !== "string" || item.length > MAX_EMBED_ITEM_CHARS) {
      throw new ProxyError("invalid_embedding_input", 400);
    }
  }
}

function sanitizeModel(model, allowlist) {
  const value = String(model || "").trim();
  if (!allowlist.has(value)) {
    throw new ProxyError("model_not_allowed", 400);
  }
  return value;
}

async function proxyJson(response, request) {
  const text = await response.text();
  return new Response(text, {
    status: response.status,
    headers: {
      ...JSON_HEADERS,
      ...corsHeaders(request),
    },
  });
}

function json(payload, status, request) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...JSON_HEADERS,
      ...corsHeaders(request),
    },
  });
}

function decodeJwt(token) {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new ProxyError("invalid_app_check", 401);
  }
  return {
    header: JSON.parse(base64UrlDecodeText(parts[0])),
    payload: JSON.parse(base64UrlDecodeText(parts[1])),
    signingInput: `${parts[0]}.${parts[1]}`,
    signature: base64UrlDecodeBytes(parts[2]),
  };
}

function base64UrlDecodeText(value) {
  return new TextDecoder().decode(base64UrlDecodeBytes(value));
}

function base64UrlDecodeBytes(value) {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function parseAllowedAppIds(raw) {
  return new Set(
    String(raw || "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

function normalizedUserId(raw) {
  const value = String(raw || "anonymous").trim();
  if (!/^[A-Za-z0-9._:-]{1,128}$/.test(value)) return "anonymous";
  return value;
}

function parseMaxAge(cacheControl) {
  const match = /max-age=(\d+)/i.exec(cacheControl || "");
  return match ? Number(match[1]) : null;
}

function corsHeaders(request) {
  const origin = request.headers.get("origin") || "*";
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "POST, OPTIONS",
    "access-control-allow-headers": "content-type, x-user-id, x-firebase-appcheck",
    vary: "Origin",
  };
}

function safeErrorMessage(error) {
  const message = error && error.message ? String(error.message) : "unknown";
  return message.slice(0, 160);
}

class ProxyError extends Error {
  constructor(code, status) {
    super(code);
    this.code = code;
    this.status = status;
  }
}
