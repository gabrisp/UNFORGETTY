import { Client, Databases } from "node-appwrite";

// APPWRITE_FUNCTION_API_ENDPOINT is misconfigured on this self-hosted instance (see
// activity-scheduler/social), so the SDK client is pointed at the real endpoint directly.
const APPWRITE_ENDPOINT = "https://appwrite.repzet.app/v1";

export default async ({ req, res, log, error }) => {
  if (req.method !== "POST") {
    return res.json({ ok: true, spotify: "ready" });
  }

  try {
    const payload = parsePayload(req);
    if (!payload || typeof payload.action !== "string") throw new Error("missing_action");
    if (typeof payload.userID !== "string" || payload.userID.length === 0) throw new Error("missing_userID");

    const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.SPOTIFY_STATIC_API_KEY;
    if (!apiKey) throw new Error("missing_api_key");
    const client = new Client().setEndpoint(APPWRITE_ENDPOINT).setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID).setKey(apiKey);
    const databases = new Databases(client);

    const result = await handleAction(databases, payload, log);
    return res.json({ ok: true, ...result });
  } catch (caught) {
    const message = caught instanceof Error ? caught.message : "unknown_error";
    error(`Rejected spotify request: ${message}`);
    return res.json({ ok: false, error: message }, 400);
  }
};

async function handleAction(databases, payload, log) {
  switch (payload.action) {
    case "spotifyStatus":
      return spotifyStatus(databases, payload);
    case "exchangeSpotifyCode":
      return exchangeSpotifyCode(databases, payload, log);
    case "disconnectSpotify":
      return disconnectSpotify(databases, payload);
    case "searchTracks":
      return searchTracks(payload, log);
    case "currentlyPlaying":
      return currentlyPlaying(databases, payload, log);
    default:
      throw new Error("unknown_action");
  }
}

async function findAccount(databases, userID) {
  try {
    return await databases.getDocument(process.env.SCHEDULER_DATABASE_ID, process.env.SPOTIFY_ACCOUNTS_COLLECTION_ID, userID);
  } catch {
    return null;
  }
}

async function spotifyStatus(databases, payload) {
  const account = await findAccount(databases, payload.userID);
  return { connected: !!account };
}

async function disconnectSpotify(databases, payload) {
  const account = await findAccount(databases, payload.userID);
  if (account) {
    await databases.deleteDocument(process.env.SCHEDULER_DATABASE_ID, process.env.SPOTIFY_ACCOUNTS_COLLECTION_ID, payload.userID);
  }
  return { disconnected: true };
}

function basicAuthHeader() {
  const clientID = process.env.SPOTIFY_CLIENT_ID;
  const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;
  if (!clientID || !clientSecret) throw new Error("missing_spotify_credentials");
  return `Basic ${Buffer.from(`${clientID}:${clientSecret}`).toString("base64")}`;
}

async function exchangeSpotifyCode(databases, payload, log) {
  if (typeof payload.code !== "string" || !payload.code) throw new Error("missing_code");
  if (typeof payload.codeVerifier !== "string" || !payload.codeVerifier) throw new Error("missing_codeVerifier");
  if (typeof payload.redirectURI !== "string" || !payload.redirectURI) throw new Error("missing_redirectURI");
  if (payload.redirectURI !== process.env.SPOTIFY_REDIRECT_URI) throw new Error("redirect_uri_mismatch");

  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code: payload.code,
    redirect_uri: payload.redirectURI,
    code_verifier: payload.codeVerifier
  });

  const response = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Authorization: basicAuthHeader() },
    body
  });
  const json = await response.json();
  if (!response.ok) {
    log(`Spotify token exchange failed: ${JSON.stringify(json)}`);
    throw new Error("spotify_token_exchange_failed");
  }

  const existing = await findAccount(databases, payload.userID);
  const expiresAt = Math.floor(Date.now() / 1000) + (json.expires_in ?? 3600);
  const data = {
    userID: payload.userID,
    accessToken: json.access_token,
    refreshToken: json.refresh_token ?? existing?.refreshToken,
    expiresAt,
    connectedAt: new Date().toISOString()
  };

  if (existing) {
    await databases.updateDocument(process.env.SCHEDULER_DATABASE_ID, process.env.SPOTIFY_ACCOUNTS_COLLECTION_ID, payload.userID, data);
  } else {
    await databases.createDocument(process.env.SCHEDULER_DATABASE_ID, process.env.SPOTIFY_ACCOUNTS_COLLECTION_ID, payload.userID, data);
  }

  return { connected: true };
}

async function accessTokenForUser(databases, userID) {
  const account = await findAccount(databases, userID);
  if (!account) throw new Error("not_connected");

  const now = Math.floor(Date.now() / 1000);
  if (account.expiresAt - now > 60) return account.accessToken;

  const body = new URLSearchParams({ grant_type: "refresh_token", refresh_token: account.refreshToken });
  const response = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Authorization: basicAuthHeader() },
    body
  });
  const json = await response.json();
  if (!response.ok) throw new Error("spotify_refresh_failed");

  const expiresAt = Math.floor(Date.now() / 1000) + (json.expires_in ?? 3600);
  await databases.updateDocument(process.env.SCHEDULER_DATABASE_ID, process.env.SPOTIFY_ACCOUNTS_COLLECTION_ID, userID, {
    accessToken: json.access_token,
    refreshToken: json.refresh_token ?? account.refreshToken,
    expiresAt
  });

  return json.access_token;
}

// App-level client-credentials token (no user auth) — used for search only, cached per warm
// container. Concurrent cold starts each fetching their own token is expected, not a bug.
let cachedAppToken = null;
let cachedAppTokenExpiresAt = 0;

async function appAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAppToken && cachedAppTokenExpiresAt - now > 60) return cachedAppToken;

  const body = new URLSearchParams({ grant_type: "client_credentials" });
  const response = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Authorization: basicAuthHeader() },
    body
  });
  const json = await response.json();
  if (!response.ok) throw new Error("spotify_client_credentials_failed");

  cachedAppToken = json.access_token;
  cachedAppTokenExpiresAt = now + (json.expires_in ?? 3600);
  return cachedAppToken;
}

function trackShape(track) {
  return {
    id: track.id,
    name: track.name,
    artist: (track.artists || []).map((artist) => artist.name).join(", "),
    album: track.album?.name ?? "",
    albumArtURL: track.album?.images?.[0]?.url ?? null,
    spotifyURL: track.external_urls?.spotify ?? null
  };
}

async function searchTracks(payload, log) {
  if (typeof payload.query !== "string" || payload.query.trim().length === 0) throw new Error("missing_query");
  const token = await appAccessToken();
  // This app's Spotify quota (Development Mode, no extended access yet) rejects limit > 10 with
  // a 400 "Invalid limit" — verified empirically, not documented anywhere obvious.
  const url = `https://api.spotify.com/v1/search?type=track&limit=10&q=${encodeURIComponent(payload.query.trim())}`;
  const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  const json = await response.json();
  if (!response.ok) {
    log(`Spotify search failed: ${JSON.stringify(json)}`);
    throw new Error("spotify_search_failed");
  }
  const tracks = (json.tracks?.items || []).map(trackShape);
  return { tracks };
}

async function currentlyPlaying(databases, payload, log) {
  const token = await accessTokenForUser(databases, payload.userID);
  const response = await fetch("https://api.spotify.com/v1/me/player/currently-playing", {
    headers: { Authorization: `Bearer ${token}` }
  });

  if (response.status === 204) return { playing: false };
  const json = await response.json();
  if (!response.ok) {
    log(`Spotify currently-playing failed: ${JSON.stringify(json)}`);
    throw new Error("spotify_currently_playing_failed");
  }
  if (!json.item) return { playing: false };
  return { playing: true, track: trackShape(json.item) };
}

function parsePayload(req) {
  const candidateGetters = [() => req.bodyJson, () => req.bodyText, () => req.bodyRaw, () => req.body];
  for (const getter of candidateGetters) {
    let candidate;
    try {
      candidate = getter();
    } catch {
      continue;
    }
    if (candidate == null || candidate === "") continue;

    let value = candidate;
    if (typeof value === "string") {
      if (value.trim().length === 0) continue;
      try {
        value = JSON.parse(value);
      } catch {
        continue;
      }
    }
    if (value && typeof value === "object" && typeof value.body === "string") {
      try {
        value = JSON.parse(value.body);
      } catch {
        continue;
      }
    }
    if (value && typeof value === "object" && !Array.isArray(value)) return value;
  }
  return null;
}
