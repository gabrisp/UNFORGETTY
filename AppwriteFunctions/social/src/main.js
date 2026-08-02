import { Client, Databases, ID, Query, Users } from "node-appwrite";
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
    const users = new Users(client);

    const result = await handleAction(databases, users, payload, log);
    return res.json({ ok: true, ...result });
  } catch (caught) {
    const message = caught instanceof Error ? caught.message : "unknown_error";
    error(`Rejected social request: ${message}`);
    return res.json({ ok: false, error: message }, 400);
  }
};

async function handleAction(databases, users, payload, log) {
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
      return sendToFriend(databases, users, payload, log);
    case "registerActivityUpdateToken":
      return registerActivityUpdateToken(databases, payload);
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
    // FriendActivitySnapshot's synthesized Decodable requires every non-optional key to be
    // present — a Swift `= 0.15` default only applies to the memberwise initializer, it is NOT a
    // fallback for a missing JSON key, so omitting this made the system's own content-state
    // decode throw silently on the recipient's device (push accepted, activity never appears).
    lineSpacingMultiplier: number(raw.lineSpacingMultiplier, 0.15),
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
    musicShowsAlbum: raw.musicShowsAlbum !== false,
    musicArtPosition: raw.musicArtPosition === "leading" ? "leading" : "trailing"
  };
}

async function findActivityUpdateToken(databases, notificationID, recipientUserID) {
  const result = await databases.listDocuments(
    process.env.SCHEDULER_DATABASE_ID,
    process.env.LIVE_ACTIVITY_TOKENS_COLLECTION_ID,
    [Query.equal("notificationID", [notificationID]), Query.equal("recipientUserID", [recipientUserID]), Query.limit(1)]
  );
  return result.documents[0] ?? null;
}

async function registerActivityUpdateToken(databases, payload) {
  if (typeof payload.notificationID !== "string" || payload.notificationID.length === 0) throw new Error("missing_notificationID");
  if (typeof payload.activityUpdateToken !== "string" || payload.activityUpdateToken.length === 0) throw new Error("missing_activityUpdateToken");
  const lastMessage = typeof payload.message === "string" ? payload.message.trim().slice(0, 120) : "";

  const existing = await findActivityUpdateToken(databases, payload.notificationID, payload.userID);
  if (existing) {
    await databases.updateDocument(process.env.SCHEDULER_DATABASE_ID, process.env.LIVE_ACTIVITY_TOKENS_COLLECTION_ID, existing.$id, {
      activityUpdateToken: payload.activityUpdateToken,
      lastMessage,
      updatedAt: new Date().toISOString()
    });
    return { registered: true };
  }

  await databases.createDocument(process.env.SCHEDULER_DATABASE_ID, process.env.LIVE_ACTIVITY_TOKENS_COLLECTION_ID, ID.unique(), {
    notificationID: payload.notificationID,
    recipientUserID: payload.userID,
    activityUpdateToken: payload.activityUpdateToken,
    lastMessage,
    updatedAt: new Date().toISOString()
  });
  return { registered: true };
}

async function sendToFriend(databases, users, payload, log) {
  const toUsername = normalizedUsername(payload.toUsername);
  if (typeof payload.fromUsername !== "string") throw new Error("missing_fromUsername");
  if (typeof payload.message !== "string" || payload.message.trim().length === 0) throw new Error("missing_message");
  if (typeof payload.notificationID !== "string" || payload.notificationID.length === 0) throw new Error("missing_notificationID");
  const snapshot = sanitizedSnapshot(payload.snapshot);
  const message = payload.message.trim().slice(0, 120);

  const target = await databases.getDocument(process.env.SCHEDULER_DATABASE_ID, process.env.PROFILES_COLLECTION_ID, toUsername).catch(() => null);
  if (!target) throw new Error("user_not_found");

  const friendship = await existingFriendship(databases, payload.userID, target.userID);
  if (!friendship || friendship.status !== "accepted") throw new Error("not_friends");

  const updateRecord = await findActivityUpdateToken(databases, payload.notificationID, target.userID);

  if (updateRecord) {
    const messageChanged = updateRecord.lastMessage !== message;
    await sendLiveActivityUpdate({
      activityUpdateToken: updateRecord.activityUpdateToken,
      notificationID: payload.notificationID,
      fromUsername: payload.fromUsername.toLowerCase(),
      message,
      messageChanged,
      snapshot
    });
    await databases.updateDocument(process.env.SCHEDULER_DATABASE_ID, process.env.LIVE_ACTIVITY_TOKENS_COLLECTION_ID, updateRecord.$id, {
      lastMessage: message,
      updatedAt: new Date().toISOString()
    });

    log(`Updated existing friend ping live activity for ${toUsername}.`);
    return { status: "updated" };
  }

  if (target.pushToStartToken) {
    await sendLiveActivityPing({
      deviceToken: target.pushToStartToken,
      notificationID: payload.notificationID,
      fromUsername: payload.fromUsername.toLowerCase(),
      message,
      snapshot
    });

    log(`Sent a new friend ping to ${toUsername} via push-to-start.`);
    return { status: "sent" };
  }

  // pushToStartToken is the only way to start a Live Activity truly remotely (no app process
  // involved) — but it's finicky to get registered (see updatePushToken's doc comment) and
  // requires the recipient to have the separate, easy-to-miss "Live Activities" toggle enabled,
  // not just Notifications. A regular push target (registered the moment notifications are
  // granted, at account/targets/push — see register-push-target) is far more reliably present.
  // Fall back to it: a silent background push wakes the app, which starts the Live Activity
  // itself, in-process — no push-to-start token required for that path at all.
  const pushTarget = await findPushTarget(users, target.userID);
  if (!pushTarget) throw new Error("friend_has_no_device");

  await sendFriendPingWakePush({
    deviceToken: pushTarget,
    notificationID: payload.notificationID,
    fromUsername: payload.fromUsername.toLowerCase(),
    message,
    snapshot
  });

  log(`Sent a new friend ping to ${toUsername} via background wake push.`);
  return { status: "sent" };
}

/// The `Users` API lists every target (push/email/sms) ever registered for an account — filters
/// down to a still-valid APNs push target, preferring the most recently created if there's more
/// than one (e.g. a reinstall left a stale one behind).
async function findPushTarget(users, userID) {
  const result = await users.listTargets(userID, [Query.equal("providerType", ["push"])]).catch(() => null);
  const valid = (result?.targets ?? []).filter((t) => !t.expired && typeof t.identifier === "string" && t.identifier.length > 0);
  if (valid.length === 0) return null;
  valid.sort((a, b) => new Date(b.$createdAt).getTime() - new Date(a.$createdAt).getTime());
  return valid[0].identifier;
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

async function sendLiveActivityPing({ deviceToken, notificationID, fromUsername, message, snapshot }) {
  const topic = process.env.APNS_TOPIC;
  if (!topic) throw new Error("missing_apns_topic");

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

  const { status, body } = await postApnsRequest(deviceToken, payload);
  if (status !== 200) throw new Error(`apns_${status}:${body}`);
}

// Targets a specific already-running Live Activity via its per-activity update push token
// (distinct from the device-wide pushToStartToken used above to create new activities). Reuses
// the same notificationID the activity was originally created with, since that's what
// live_activity_tokens is keyed on. When the message hasn't changed since last send, the alert
// is omitted so this lands as a silent background content update instead of a fresh banner.
async function sendLiveActivityUpdate({ activityUpdateToken, notificationID, fromUsername, message, messageChanged, snapshot }) {
  const topic = process.env.APNS_TOPIC;
  if (!topic) throw new Error("missing_apns_topic");

  const aps = {
    timestamp: Math.floor(Date.now() / 1000),
    event: "update",
    "content-state": { phase: "active", notificationID, fromUsername, message, friendSnapshot: snapshot },
    "stale-date": Math.floor(Date.now() / 1000) + 3600
  };
  if (messageChanged) {
    aps.alert = { title: `@${fromUsername}`, body: message };
  }

  const { status, body } = await postApnsRequest(activityUpdateToken, JSON.stringify({ aps }));
  if (status !== 200) throw new Error(`apns_${status}:${body}`);
}

// Wakes the recipient's app via a plain silent push (their already-registered general push
// target, not a Live-Activity-specific one) and hands it everything it needs to start the
// activity itself, in-process — see UnforgettyAppDelegate's
// application(_:didReceiveRemoteNotification:fetchCompletionHandler:) for the client side.
// content-available pushes are lower-priority/best-effort at the OS level (can be delayed or
// dropped, e.g. under Low Power Mode or if the app was force-quit), unlike push-to-start which
// Apple treats as higher-priority specifically for this use case — this is the fallback for when
// push-to-start isn't available, not a full replacement for it.
async function sendFriendPingWakePush({ deviceToken, notificationID, fromUsername, message, snapshot }) {
  const payload = JSON.stringify({
    aps: { "content-available": 1 },
    startFriendPing: { notificationID, fromUsername, message, snapshot }
  });

  const { status, body } = await postApnsRequest(deviceToken, payload, { pushType: "background" });
  if (status !== 200) throw new Error(`apns_${status}:${body}`);
}

async function postApnsRequest(deviceToken, payload, { pushType = "liveactivity" } = {}) {
  const topic = process.env.APNS_TOPIC;
  const environment = process.env.APNS_ENVIRONMENT === "production" ? "production" : "sandbox";
  const authority = environment === "production" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";
  // A background push's topic is the bare bundle ID — only Live Activity pushes use the
  // `.push-type.liveactivity` suffixed topic.
  const apnsTopic = pushType === "liveactivity" ? `${topic}.push-type.liveactivity` : topic;

  const client = http2.connect(authority);
  try {
    const req = client.request({
      ":method": "POST",
      ":path": `/3/device/${deviceToken}`,
      authorization: `bearer ${buildApnsJwt()}`,
      "apns-topic": apnsTopic,
      "apns-push-type": pushType,
      "apns-priority": pushType === "background" ? "5" : "10",
      "apns-expiration": "0"
    });

    return await new Promise((resolve, reject) => {
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
