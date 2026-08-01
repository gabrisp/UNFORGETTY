export default async ({ req, res, error }) => {
  if (req.method !== "POST") {
    return res.json({ error: "method_not_allowed" }, 405);
  }

  try {
    const payload = typeof req.bodyJson === "string" ? JSON.parse(req.bodyJson) : req.bodyJson;
    validate(payload);

    const response = await fetch("https://appwrite.repzet.app/v1/account/targets/push", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Appwrite-Project": process.env.APPWRITE_FUNCTION_PROJECT_ID,
        // `sessionCookie` is the X-Fallback-Cookies JSON blob (see anonymous-session), not a raw
        // Set-Cookie header value — sending it as `Cookie:` is malformed and gets silently
        // ignored by Appwrite, which is why targets stopped registering after that format change.
        "X-Fallback-Cookies": payload.sessionCookie
      },
      body: JSON.stringify({
        targetId: payload.targetId,
        providerId: payload.providerId,
        identifier: payload.identifier,
        name: payload.name ?? "Unforgetty Device"
      })
    });

    const body = await response.json();
    return res.json(body, response.status);
  } catch (caught) {
    error(caught instanceof Error ? caught.message : "push_target_failed");
    return res.json({ error: "push_target_failed" }, 400);
  }
};

function validate(payload) {
  if (!payload || typeof payload !== "object") throw new Error("payload");
  for (const key of ["sessionCookie", "targetId", "providerId", "identifier"]) {
    if (typeof payload[key] !== "string" || payload[key].length === 0) throw new Error(key);
  }
}
