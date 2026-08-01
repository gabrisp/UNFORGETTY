import { Client, Databases, ID, Query } from "node-appwrite";
import crypto from "node:crypto";
import http2 from "node:http2";

const allowedWeekdays = new Set([1, 2, 3, 4, 5, 6, 7]);
const weekdayNumbers = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
const toleranceMinutes = Number(process.env.SCHEDULER_TOLERANCE_MINUTES ?? 15);
// APPWRITE_FUNCTION_API_ENDPOINT is misconfigured on this self-hosted instance (points at a
// realtime path, not the REST API), so the SDK client is pointed at the real endpoint directly,
// same as the other functions' raw fetch calls.
const APPWRITE_ENDPOINT = "https://appwrite.repzet.app/v1";

export default async ({ req, res, log, error }) => {
  if (req.method !== "POST") {
    log("Scheduler heartbeat.");
    return res.json({ ok: true, scheduler: "ready" });
  }

  try {
    const payload = parsePayload(req);
    if (!payload || Object.keys(payload).length === 0) {
      // Appwrite's scheduled invocations are POST requests without an HTTP body: this is the cron tick.
      const processed = await runDueJobs(log, error);
      return res.json({ ok: true, scheduler: "ready", processed });
    }
    validate(payload);

    const client = new Client()
      .setEndpoint(APPWRITE_ENDPOINT)
      .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID);
    const session = req.headers?.["x-appwrite-session"];
    const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.SCHEDULER_STATIC_API_KEY;
    // The dynamic per-execution API key (from the function's scopes) isn't injected for plain
    // anonymous HTTP-triggered calls on this Appwrite version, only for scheduled/cron triggers,
    // so a static fallback key is required for the client's job-creation calls to work at all.
    if (session) {
      client.setSession(session);
    } else if (apiKey) {
      client.setKey(apiKey);
    } else {
      throw new Error("missing_appwrite_session");
    }
    const databases = new Databases(client);

    // Rescheduling (a new startDate/recurrence for the same activity) must replace, not stack:
    // otherwise every re-send leaves the previous job behind and the cron fires both.
    const previous = await databases.listDocuments(
      process.env.SCHEDULER_DATABASE_ID,
      process.env.SCHEDULER_COLLECTION_ID,
      [Query.equal("notificationID", [payload.notificationID]), Query.limit(100)]
    );
    for (const doc of previous.documents) {
      await databases.deleteDocument(process.env.SCHEDULER_DATABASE_ID, process.env.SCHEDULER_COLLECTION_ID, doc.$id);
    }

    const documentData = {
      notificationID: payload.notificationID,
      deviceID: payload.deviceID,
      timeZoneIdentifier: payload.timeZoneIdentifier,
      startDate: payload.startDate,
      recurrence: payload.recurrence,
      status: "scheduled",
      ...(payload.pushToStartToken ? { pushToStartToken: payload.pushToStartToken } : {}),
      ...(payload.endDate ? { endDate: payload.endDate } : {}),
      ...(payload.autoEndDuration ? { autoEndDuration: payload.autoEndDuration } : {})
    };

    await databases.createDocument(
      process.env.SCHEDULER_DATABASE_ID,
      process.env.SCHEDULER_COLLECTION_ID,
      ID.unique(),
      documentData
    );

    // Never log payload values: they may contain opaque device tokens.
    log("Scheduled an opaque Live Activity job.");
    return res.json({ accepted: true });
  } catch (caught) {
    error(`Rejected scheduler request: ${caught instanceof Error ? caught.message : "unknown_error"}`);
    return res.json({ accepted: false, error: "invalid_schedule" }, 400);
  }
};

function parsePayload(req) {
  // `bodyJson` is a lazy getter that runs JSON.parse internally, and throws on Appwrite's real
  // scheduled cron ticks (which carry a genuinely empty body) before any of our own try/catch
  // can help. Every candidate access below must therefore be defensive, not just the JSON.parse calls.
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

    // Some Appwrite versions expose the execution envelope as the parsed body.
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

function validate(payload) {
  if (!payload || typeof payload !== "object") throw new Error("payload");
  if (typeof payload.notificationID !== "string" || payload.notificationID.length > 36) throw new Error("notificationID");
  if (typeof payload.deviceID !== "string" || payload.deviceID.length > 128) throw new Error("deviceID");
  if (typeof payload.timeZoneIdentifier !== "string" || payload.timeZoneIdentifier.length === 0 || payload.timeZoneIdentifier.length > 64) throw new Error("timeZoneIdentifier");
  if (payload.pushToStartToken != null && (typeof payload.pushToStartToken !== "string" || payload.pushToStartToken.length > 4096)) throw new Error("token");
  if (!Date.parse(payload.startDate) || (payload.endDate && !Date.parse(payload.endDate))) throw new Error("date");
  if (!Array.isArray(payload.recurrence) || !payload.recurrence.every((day) => allowedWeekdays.has(day))) throw new Error("recurrence");
  if (payload.autoEndDuration != null && (typeof payload.autoEndDuration !== "number" || payload.autoEndDuration <= 0)) throw new Error("autoEndDuration");
}

async function runDueJobs(log, error) {
  const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.SCHEDULER_STATIC_API_KEY;
  if (!apiKey) {
    error("Cron tick skipped: missing an API key.");
    return 0;
  }

  const client = new Client()
    .setEndpoint(APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(apiKey);
  const databases = new Databases(client);
  const now = new Date();
  const toleranceMs = toleranceMinutes * 60_000;

  let processed = 0;
  let offset = 0;
  const pageSize = 100;

  while (true) {
    const page = await databases.listDocuments(
      process.env.SCHEDULER_DATABASE_ID,
      process.env.SCHEDULER_COLLECTION_ID,
      [Query.equal("status", "scheduled"), Query.limit(pageSize), Query.offset(offset)]
    );

    for (const job of page.documents) {
      try {
        if (await handleJob(databases, job, now, toleranceMs)) processed += 1;
      } catch (caught) {
        error(`Job ${job.$id} failed: ${caught instanceof Error ? caught.message : "unknown_error"}`);
      }
    }

    offset += page.documents.length;
    if (page.documents.length < pageSize || offset >= page.total) break;
  }

  log(`Cron tick processed ${processed} due job(s).`);
  return processed;
}

async function handleJob(databases, job, now, toleranceMs) {
  if (job.endDate && now.getTime() > Date.parse(job.endDate)) {
    await databases.updateDocument(process.env.SCHEDULER_DATABASE_ID, process.env.SCHEDULER_COLLECTION_ID, job.$id, { status: "ended" });
    return false;
  }
  if (!job.pushToStartToken) return false;

  const due = isDue(job, now, toleranceMs);
  if (!due) return false;

  await sendLiveActivityStart({
    deviceToken: job.pushToStartToken,
    notificationID: job.notificationID,
    autoEndDuration: job.autoEndDuration
  });

  await databases.updateDocument(process.env.SCHEDULER_DATABASE_ID, process.env.SCHEDULER_COLLECTION_ID, job.$id, {
    lastTriggeredDate: due.todayKey
  });
  return true;
}

function isDue(job, now, toleranceMs) {
  const timeZone = job.timeZoneIdentifier || "UTC";
  const nowParts = zonedParts(now, timeZone);
  if (!job.recurrence.includes(nowParts.weekday)) return null;

  const todayKey = dateKey(nowParts);
  if (job.lastTriggeredDate === todayKey) return null;

  const startParts = zonedParts(new Date(job.startDate), timeZone);
  const scheduledInstant = zonedTimeToUtc(
    { year: nowParts.year, month: nowParts.month, day: nowParts.day, hour: startParts.hour, minute: startParts.minute },
    timeZone
  );

  const delta = now.getTime() - scheduledInstant;
  return delta >= 0 && delta < toleranceMs ? { todayKey } : null;
}

function dateKey({ year, month, day }) {
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function zonedParts(date, timeZone) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", {
      timeZone,
      hourCycle: "h23",
      weekday: "short",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit"
    })
      .formatToParts(date)
      .map((part) => [part.type, part.value])
  );
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    weekday: weekdayNumbers[parts.weekday]
  };
}

// Converts wall-clock components read in `timeZone` to the UTC instant (ms) they represent.
// Two passes are enough to converge even across a DST transition.
function zonedTimeToUtc({ year, month, day, hour, minute }, timeZone) {
  const target = Date.UTC(year, month - 1, day, hour, minute);
  let guess = target;
  for (let i = 0; i < 2; i++) {
    const seen = zonedParts(new Date(guess), timeZone);
    const seenAsUtc = Date.UTC(seen.year, seen.month - 1, seen.day, seen.hour, seen.minute);
    const diff = target - seenAsUtc;
    if (diff === 0) break;
    guess += diff;
  }
  return guess;
}

async function sendLiveActivityStart({ deviceToken, notificationID, autoEndDuration }) {
  const topic = process.env.APNS_TOPIC;
  if (!topic) throw new Error("missing_apns_topic");
  const environment = process.env.APNS_ENVIRONMENT === "production" ? "production" : "sandbox";
  const authority = environment === "production" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";
  const now = Math.floor(Date.now() / 1000);
  // Capped at the platform's own ~8h Live Activity lifetime, same as the local start path.
  const staleTimestamp = autoEndDuration ? now + Math.min(autoEndDuration, 8 * 3600) : undefined;

  const payload = JSON.stringify({
    aps: {
      timestamp: now,
      event: "start",
      "content-state": { phase: "active", notificationID },
      ...(staleTimestamp ? { "stale-date": staleTimestamp } : {}),
      "attributes-type": "UnforgettyActivityAttributes",
      attributes: { notificationID },
      // Visible banner alongside the (normally silent) start event, so delivery is
      // confirmable on-device even if ActivityKit itself fails to start the activity.
      alert: { title: "Unforgetty", body: "Live Activity programada" }
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
