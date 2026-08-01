# Unforgetty Activity Scheduler

The function stores only `notificationID`, the caller's Appwrite messaging target ID (field name `deviceID` for historical reasons), the device's IANA `timeZoneIdentifier`, an opaque push-to-start token, dates, recurrence and status. It deliberately rejects note titles, bodies, checklists, tags, styles and images.

## Two invocation modes

- **POST with a JSON body** (called by the app via `AppwriteFunctionsRepository.executeScheduler`): validates and stores a job document with `status: "scheduled"`.
- **POST with no body** (Appwrite's own cron trigger): runs `runDueJobs`, which lists every `status: "scheduled"` document, checks whether `now` falls within `SCHEDULER_TOLERANCE_MINUTES` (default 15) after that job's recurrence time *in the job's own timezone*, and if so sends a `liveactivity` push-to-start request straight to APNs over raw HTTP/2 (bypassing Appwrite's generic Messaging API, which cannot express the Live Activity headers/payload). `lastTriggeredDate` is stamped on the document to avoid firing twice on the same local day; documents past `endDate` are flipped to `status: "ended"`.

The function's own cron schedule (set on the Appwrite Function itself, e.g. `*/5 * * * *`) must run at least as often as `SCHEDULER_TOLERANCE_MINUTES`, or occurrences can be missed.

## Required Function secrets

| Variable | Purpose |
| --- | --- |
| `APPWRITE_FUNCTION_API_KEY` | Server API key with database read/write, used both for the create-job path (when no session header is present) and for every cron tick. |
| `APNS_KEY_ID` | Key ID of the `.p8` APNs Auth Key. |
| `APNS_TEAM_ID` | Apple Developer Team ID. |
| `APNS_AUTH_KEY` | Full contents of the `.p8` file (PEM). Literal newlines or escaped `\n` are both accepted. |
| `APNS_TOPIC` | The app's bundle ID, e.g. `com.gabrisp.Unforgetty`. Sent as `apns-topic: <topic>.push-type.liveactivity`. |
| `APNS_ENVIRONMENT` | `sandbox` (default) or `production`. Must match the app build's `aps-environment` entitlement. |
| `SCHEDULER_TOLERANCE_MINUTES` | Optional, default `15`. |

The `timeZoneIdentifier` and `lastTriggeredDate` attributes must exist on the scheduler collection (string, matching the existing `deviceID`/`notificationID` attributes).
