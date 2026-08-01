import { Client, Databases, ID, Query } from "node-appwrite";
import crypto from "node:crypto";
import http2 from "node:http2";

// APPWRITE_FUNCTION_API_ENDPOINT is misconfigured on this self-hosted instance (see
// activity-scheduler), so the SDK client is pointed at the real endpoint directly.
const APPWRITE_ENDPOINT = "https://appwrite.repzet.app/v1";
const USERNAME_PATTERN = /^[a-z0-9_]{3,20}$/;

export default async ({ req, res, log, error }) => {
  if (req.method !== "POST") {
    return res.json({ ok: true, social: "ready" });
  }

  try {
    const payload = parsePayload(req);
    if (!payload || typeof payload.action !== "string") throw new Error("missing_action");
    if (typeof payload.userID !== "string" || payload.userID.length === 0) throw new Error("missing_userID");

    const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.SOCIAL_STATIC_API_KEY;
    if (!apiKey) throw new Error("missing_api_key");
    const client = new Client().setEndpoint(APPWRITE_ENDPOINT).setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID).setKey(apiKey);
    const databases = new Databases(client);

    const result = await handleAction(databases, payload, log);
    return res.json({ ok: true, ...result });
  } catch (caught) {
    const message = caught instanceof Error ? caught.message : "unknown_error";
    error(`Rejected social request: ${message}`);
    return res.json({ ok: false, error: message }, 400);
  }
};

async function handleAction(databases, payload, log) {
  switch (payload.action) {
    case "claimUsername":
      return claimUsername(databases, payload);
    case "myUsername":
      return myUsername(databases, payload);
    case "searchUsername":
      return searchUsername(databases, payload);
    case "sendFriendRequest":
      return sendFriendRequest(databases, payload);
    case "respondFriendRequest":
      return respondFriendRequest(databases, payload);
    case "removeFriend":
      return removeFriend(databases, payload);
    case "listFriends":
      return listFriends(databases, payload);
    case "listPendingRequests":
      return listPendingRequests(databases, payload);
    case "updatePushToken":
      return updatePushToken(databases, payload);
    case "sendToFriend":
      return sendToFriend(databases, payload, log);
    default:
      throw new Error("unknown_action");
  }
}

function normalizedUsername(raw) {
  if (typeof raw !== "string") throw new Error("invalid_username");
  const value = raw.trim().toLowerCase();
  if (!USERNAME_PATTERN.test(value)) throw new Error("invalid_username");
  return value;
}

async function findProfileByUserID(databases, userID) {
  const result = await databases.listDocuments(
    process.env.SCHEDULER_DATABASE_ID,
    process.env.PROFILES_COLLECTION_ID,
    [Query.equal("userID", [userID]), Query.limit(1)]
  );
  return result.documents[0] ?? null;
}

async function claimUsername(databases, payload) {
  const username = normalizedUsername(payload.username);
  const existingMine = await findProfileByUserID(databases, payload.userID);
  if (existingMine && existingMine.$id === username) {
    return { username };
  }

  try {
    await databases.createDocument(
      process.env.SCHEDULER_DATABASE_ID,
      process.env.PROFILES_COLLECTION_ID,
      username,
      { userID: payload.userID, pushToStartToken: existingMine?.pushToStartToken ?? null }
    );
  } catch (caught) {
    if (caught?.code === 409 || caught?.response?.includes?.("already exists")) {
      throw new Error("username_taken");
    }
    throw caught;
  }

  if (existingMine && existingMine.$id !== username) {
    await databases.deleteDocument(process.env.SCHEDULER_DATABASE_ID, process.env.PROFILES_COLLECTION_ID, existingMine.$id);
  }

  return { username };
}

async function myUsername(databases, payload) {
  const profile = await findProfileByUserID(databases, payload.userID);
  return { username: profile?.$id ?? null };
}

async function searchUsername(databases, payload) {
  const username = normalizedUsername(payload.username);
  try {
    const doc = await databases.getDocument(process.env.SCHEDULER_DATABASE_ID, process.env.PROFILES_COLLECTION_ID, username);
    return { found: true, userID: doc.userID };
  } catch {
    return { found: false };
  }
}

async function existingFriendship(databases, userA, userB) {
  const [asFrom, asTo] = await Promise.all([
    databases.listDocuments(process.env.SCHEDULER_DATABASE_ID, process.env.FRIENDSHIPS_COLLECTION_ID, [
      Query.equal("fromUserID", [userA]),
      Query.equal("toUserID", [userB]),
      Query.limit(1)
    ]),
    databases.listDocuments(process.env.SCHEDULER_DATABASE_ID, process.env.FRIENDSHIPS_COLLECTION_ID, [
      Query.equal("fromUserID", [userB]),
      Query.equal("toUserID", [userA]),
      Query.limit(1)
    ])
  ]);
  return asFrom.documents[0] ?? asTo.documents[0] ?? null;
}

async function sendFriendRequest(databases, payload) {
  if (typeof payload.fromUsername !== "string") throw new Error("missing_fromUsername");
  const toUsername = normalizedUsername(payload.toUsername);
  const target = await databases.getDocument(process.env.SCHEDULER_DATABASE_ID, process.env.PROFILES_COLLECTION_ID, toUsername).catch(() => null);
  if (!target) throw new Error("user_not_found");
  if (target.userID === payload.userID) throw new Error("cannot_friend_yourself");

  const existing = await existingFriendship(databases, payload.userID, target.userID);
  if (existing) {
    if (existing.status === "accepted") return { status: "already_friends" };
    return { status: "already_pending" };
  }

  await databases.createDocument(process.env.SCHEDULER_DATABASE_ID, process.env.FRIENDSHIPS_COLLECTION_ID, ID.unique(), {
    fromUserID: payload.userID,
    toUserID: target.userID,
    fromUsername: payload.fromUsername.toLowerCase(),
    toUsername,
    status: "pending"
  });
  return { status: "requested" };
}

async function respondFriendRequest(databases, payload) {
  if (typeof payload.requestID !== "string") throw new Error("missing_requestID");
  const request = await databases.getDocument(process.env.SCHEDULER_DATABASE_ID, process.env.FRIENDSHIPS_COLLECTION_ID, payload.requestID);
  if (request.toUserID !== payload.userID) throw new Error("not_your_request");

  if (payload.accept) {
    await databases.updateDocument(process.env.SCHEDULER_DATABASE_ID, process.env.FRIENDSHIPS_COLLECTION_ID, payload.requestID, { status: "accepted" });
    return { status: "accepted" };
  }
  await databases.deleteDocument(process.env.SCHEDULER_DATABASE_ID, process.env.FRIENDSHIPS_COLLECTION_ID, payload.requestID);
  return { status: "rejected" };
}

async function removeFriend(databases, payload) {
  if (typeof payload.friendUserID !== "string" || payload.friendUserID.length === 0) throw new Error("missing_friendUserID");
  const friendship = await existingFriendship(databases, payload.userID, payload.friendUserID);
  if (!friendship || friendship.status !== "accepted") throw new Error("not_friends");
  await databases.deleteDocument(process.env.SCHEDULER_DATABASE_ID, process.env.FRIENDSHIPS_COLLECTION_ID, friendship.$id);
  return { status: "removed" };
}

async function listFriends(databases, payload) {
  const [asFrom, asTo] = await Promise.all([
    databases.listDocuments(process.env.SCHEDULER_DATABASE_ID, process.env.FRIENDSHIPS_COLLECTION_ID, [
      Query.equal("fromUserID", [payload.userID]),
      Query.equal("status", ["accepted"]),
      Query.limit(100)
    ]),
    databases.listDocuments(process.env.SCHEDULER_DATABASE_ID, process.env.FRIENDSHIPS_COLLECTION_ID, [
      Query.equal("toUserID", [payload.userID]),
      Query.equal("status", ["accepted"]),
      Query.limit(100)
    ])
  ]);

  const friends = [
    ...asFrom.documents.map((doc) => ({ userID: doc.toUserID, username: doc.toUsername })),
    ...asTo.documents.map((doc) => ({ userID: doc.fromUserID, username: doc.fromUsername }))
  ];
  return { friends };
}

async function listPendingRequests(databases, payload) {
  const incoming = await databases.listDocuments(process.env.SCHEDULER_DATABASE_ID, process.env.FRIENDSHIPS_COLLECTION_ID, [
    Query.equal("toUserID", [payload.userID]),
    Query.equal("status", ["pending"]),
    Query.limit(100)
  ]);
  return {
    requests: incoming.documents.map((doc) => ({ requestID: doc.$id, fromUsername: doc.fromUsername }))
  };
}

async function updatePushToken(databases, payload) {
  if (typeof payload.pushToStartToken !== "string") throw new Error("missing_pushToStartToken");
  const profile = await findProfileByUserID(databases, payload.userID);
  if (!profile) return { updated: false };
  await databases.updateDocument(process.env.SCHEDULER_DATABASE_ID, process.env.PROFILES_COLLECTION_ID, profile.$id, {
    pushToStartToken: payload.pushToStartToken
  });
  return { updated: true };
}

function sanitizedSnapshot(raw) {
  if (!raw || typeof raw !== "object") throw new Error("missing_snapshot");
  const string = (value, fallback, maxLength) => {
    const trimmed = typeof value === "string" ? value.trim() : "";
    return (trimmed.length > 0 ? trimmed : fallback).slice(0, maxLength);
  };
  const number = (value, fallback) => (typeof value === "number" && Number.isFinite(value) ? value : fallback);

  return {
    kind: raw.kind === "music" ? "music" : "note",
    body: string(raw.body, "", 600),
    backgroundHex: string(raw.backgroundHex, "F6F6F7", 8),
    backgroundMode: raw.backgroundMode === "gradient" ? "gradient" : "plain",
    gradientStartHex: string(raw.gradientStartHex, "F6F6F7", 8),
    gradientEndHex: string(raw.gradientEndHex, "D7E6FF", 8),
    gradientKind: ["linear", "radial", "angular"].includes(raw.gradientKind) ? raw.gradientKind : "linear",
    gradientAngle: number(raw.gradientAngle, 135),
    gradientCenterX: number(raw.gradientCenterX, 0.5),
    gradientCenterY: number(raw.gradientCenterY, 0.5),
    textHex: string(raw.textHex, "111111", 8),
    font: ["rounded", "serif", "monospaced"].includes(raw.font) ? raw.font : "rounded",
    textSize: number(raw.textSize, 40),
    alignment: ["leading", "center", "trailing"].includes(raw.alignment) ? raw.alignment : "leading",
    verticalAlignment: ["top", "center", "bottom"].includes(raw.verticalAlignment) ? raw.verticalAlignment : "center",
    borderHex: string(raw.borderHex, "FFFFFF", 8),
    borderWidth: number(raw.borderWidth, 0),
    musicTitle: string(raw.musicTitle, "", 120),
    musicArtist: string(raw.musicArtist, "", 120),
    musicAlbum: string(raw.musicAlbum, "", 120),
    musicSpotifyTrackID: string(raw.musicSpotifyTrackID, "", 64),
    musicSpotifyURL: string(raw.musicSpotifyURL, "", 300),
    musicAlbumArtURL: string(raw.musicAlbumArtURL, "", 300),
    musicLayout: ["disc", "square", "heart", "diamond", "star"].includes(raw.musicLayout) ? raw.musicLayout : "disc",
    musicBorderEnabled: raw.musicBorderEnabled === true,
    musicBorderHex: string(raw.musicBorderHex, "FFFFFF", 8),
    musicShowsTitle: raw.musicShowsTitle !== false,
    musicShowsArtist: raw.musicShowsArtist !== false,
    musicShowsAlbum: raw.musicShowsAlbum !== false
  };
}

async function sendToFriend(databases, payload, log) {
  const toUsername = normalizedUsername(payload.toUsername);
  if (typeof payload.fromUsername !== "string") throw new Error("missing_fromUsername");
  if (typeof payload.message !== "string" || payload.message.trim().length === 0) throw new Error("missing_message");
  const snapshot = sanitizedSnapshot(payload.snapshot);

  const target = await databases.getDocument(process.env.SCHEDULER_DATABASE_ID, process.env.PROFILES_COLLECTION_ID, toUsername).catch(() => null);
  if (!target) throw new Error("user_not_found");

  const friendship = await existingFriendship(databases, payload.userID, target.userID);
  if (!friendship || friendship.status !== "accepted") throw new Error("not_friends");
  if (!target.pushToStartToken) throw new Error("friend_has_no_device");

  await sendLiveActivityPing({
    deviceToken: target.pushToStartToken,
    fromUsername: payload.fromUsername.toLowerCase(),
    message: payload.message.trim().slice(0, 120),
    snapshot
  });

  log(`Sent a friend ping to ${toUsername}.`);
  return { status: "sent" };
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

// --- Raw APNs push-to-start, mirroring activity-scheduler's sendLiveActivityStart. ---

async function sendLiveActivityPing({ deviceToken, fromUsername, message, snapshot }) {
  const topic = process.env.APNS_TOPIC;
  if (!topic) throw new Error("missing_apns_topic");
  const environment = process.env.APNS_ENVIRONMENT === "production" ? "production" : "sandbox";
  const authority = environment === "production" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";
  const notificationID = `friend-${crypto.randomUUID()}`;

  const payload = JSON.stringify({
    aps: {
      timestamp: Math.floor(Date.now() / 1000),
      event: "start",
      "content-state": { phase: "active", notificationID, fromUsername, message, friendSnapshot: snapshot },
      "stale-date": Math.floor(Date.now() / 1000) + 3600,
      "attributes-type": "UnforgettyActivityAttributes",
      attributes: { notificationID },
      alert: { title: `@${fromUsername}`, body: message }
    }
  });

  const client = http2.connect(authority);
  try {
    const req = client.request({
      ":method": "POST",
      ":path": `/3/device/${deviceToken}`,
      authorization: `bearer ${buildApnsJwt()}`,
      "apns-topic": `${topic}.push-type.liveactivity`,
      "apns-push-type": "liveactivity",
      "apns-priority": "10",
      "apns-expiration": "0"
    });

    const { status, body } = await new Promise((resolve, reject) => {
      let status = 0;
      let body = "";
      req.on("response", (headers) => {
        status = headers[":status"];
      });
      req.setEncoding("utf8");
      req.on("data", (chunk) => {
        body += chunk;
      });
      req.on("end", () => resolve({ status, body }));
      req.on("error", reject);
      req.end(payload);
    });

    if (status !== 200) throw new Error(`apns_${status}:${body}`);
  } finally {
    client.close();
  }
}

function buildApnsJwt() {
  const keyID = process.env.APNS_KEY_ID;
  const teamID = process.env.APNS_TEAM_ID;
  if (!keyID || !teamID) throw new Error("missing_apns_credentials");

  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyID }));
  const claims = base64url(JSON.stringify({ iss: teamID, iat: Math.floor(Date.now() / 1000) }));
  const signingInput = `${header}.${claims}`;
  const signature = crypto.sign("sha256", Buffer.from(signingInput), {
    key: apnsPrivateKey(),
    dsaEncoding: "ieee-p1363"
  });
  return `${signingInput}.${base64url(signature)}`;
}

function apnsPrivateKey() {
  const raw = process.env.APNS_AUTH_KEY;
  if (!raw) throw new Error("missing_apns_auth_key");
  return raw.includes("\n") ? raw : raw.replace(/\\n/g, "\n");
}

function base64url(input) {
  const buffer = typeof input === "string" ? Buffer.from(input) : input;
  return buffer.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
