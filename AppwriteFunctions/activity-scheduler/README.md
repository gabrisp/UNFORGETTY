# Unforgetty Activity Scheduler

The function stores only `notificationID`, device ID, opaque push token, dates, recurrence and status. It deliberately rejects note titles, bodies, checklists, tags, styles and images.

To activate APNs Live Activity delivery, add the APNs auth key (`key ID`, `team ID`, `.p8`) as secret Function variables and implement the APNs HTTP/2 request in the cron branch. The Appwrite APNs provider ID alone is insufficient for a raw `liveactivity` push.
