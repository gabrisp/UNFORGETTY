export default async ({ req, res, error }) => {
  if (req.method !== "POST") {
    return res.json({ error: "method_not_allowed" }, 405);
  }

  try {
    const response = await fetch("https://appwrite.repzet.app/v1/account/sessions/anonymous", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Appwrite-Project": process.env.APPWRITE_FUNCTION_PROJECT_ID
      },
      body: "{}"
    });
    const session = await response.json();
    // Native clients (no cookie jar) can't rely on Set-Cookie — Appwrite's documented workaround
    // is the `X-Fallback-Cookies` response header, a JSON blob you store and echo back verbatim
    // on later requests via the same-named request header to authenticate as this session.
    const sessionCookie = response.headers.get("x-fallback-cookies") ?? "";
    return res.json({ ...session, sessionCookie }, response.status);
  } catch (caught) {
    error(caught instanceof Error ? caught.message : "anonymous_session_failed");
    return res.json({ error: "anonymous_session_failed" }, 500);
  }
};
