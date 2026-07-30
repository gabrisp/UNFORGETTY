import { Client, Databases, ID } from "node-appwrite";

const allowedWeekdays = new Set([1, 2, 3, 4, 5, 6, 7]);

export default async ({ req, res, log, error }) => {
  if (req.method !== "POST") {
    // Invoked by the one-minute cron. Jobs are stored locally here without user content.
    log("Scheduler heartbeat. APNs delivery is enabled after APNS_AUTH_KEY is configured.");
    return res.json({ ok: true, scheduler: "ready" });
  }

  try {
    const payload = typeof req.bodyJson === "string" ? JSON.parse(req.bodyJson) : req.bodyJson;
    validate(payload);

    const client = new Client()
      .setEndpoint(process.env.APPWRITE_FUNCTION_API_ENDPOINT)
      .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
      .setKey(process.env.APPWRITE_FUNCTION_API_KEY);
    const databases = new Databases(client);

    await databases.createDocument(
      process.env.SCHEDULER_DATABASE_ID,
      process.env.SCHEDULER_COLLECTION_ID,
      ID.unique(),
      {
        notificationID: payload.notificationID,
        deviceID: payload.deviceID,
        pushToStartToken: payload.pushToStartToken ?? null,
        startDate: payload.startDate,
        endDate: payload.endDate ?? null,
        recurrence: payload.recurrence,
        status: "scheduled"
      }
    );

    // Never log payload values: they may contain opaque device tokens.
    log("Scheduled an opaque Live Activity job.");
    return res.json({ accepted: true });
  } catch (caught) {
    error("Rejected scheduler request.");
    return res.json({ accepted: false, error: "invalid_schedule" }, 400);
  }
};

function validate(payload) {
  if (!payload || typeof payload !== "object") throw new Error("payload");
  if (typeof payload.notificationID !== "string" || payload.notificationID.length > 36) throw new Error("notificationID");
  if (typeof payload.deviceID !== "string" || payload.deviceID.length > 128) throw new Error("deviceID");
  if (payload.pushToStartToken != null && (typeof payload.pushToStartToken !== "string" || payload.pushToStartToken.length > 4096)) throw new Error("token");
  if (!Date.parse(payload.startDate) || (payload.endDate && !Date.parse(payload.endDate))) throw new Error("date");
  if (!Array.isArray(payload.recurrence) || !payload.recurrence.every((day) => allowedWeekdays.has(day))) throw new Error("recurrence");
}
