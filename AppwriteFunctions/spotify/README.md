# Unforgetty Spotify

Proxies every Spotify API call the client needs — the client never talks to Spotify directly and
the client secret never leaves this function. Two auth tiers:

- **Search** uses Spotify's Client Credentials flow (app-only, no user login) — one token cached
  in module scope, refreshed on expiry. Any user can search without connecting an account.
- **"Currently playing" and account connection** require full user OAuth (Authorization Code +
  PKCE, run client-side via `ASWebAuthenticationSession`). This function exchanges the resulting
  `code` for tokens and stores them per-user in the `spotify_accounts` collection (doc ID =
  userID), refreshing them on demand. Tokens are never returned to the client.

## Actions

| Action | Payload | Response |
| --- | --- | --- |
| `spotifyStatus` | `{userID}` | `{connected: bool}` |
| `exchangeSpotifyCode` | `{userID, code, codeVerifier, redirectURI}` | `{connected: true}` |
| `disconnectSpotify` | `{userID}` | `{disconnected: true}` |
| `searchTracks` | `{userID, query}` | `{tracks: [{id,name,artist,album,albumArtURL,spotifyURL}]}` |
| `currentlyPlaying` | `{userID}` | `{playing: bool, track?: {...same shape...}}` |

## Required Function secrets

| Variable | Purpose |
| --- | --- |
| `APPWRITE_FUNCTION_API_KEY` (or `SPOTIFY_STATIC_API_KEY` fallback) | Server API key with database read/write for `spotify_accounts`. |
| `APPWRITE_FUNCTION_PROJECT_ID` | Passed to `Client().setProject(...)`. |
| `SCHEDULER_DATABASE_ID` | Reuses the same database as `social`/`activity-scheduler` (`unforgetty_scheduler`). |
| `SPOTIFY_ACCOUNTS_COLLECTION_ID` | `spotify_accounts`. |
| `SPOTIFY_CLIENT_ID` | Spotify Developer Dashboard Client ID. |
| `SPOTIFY_CLIENT_SECRET` | Spotify Developer Dashboard Client Secret — never sent to the client. |
| `SPOTIFY_REDIRECT_URI` | Must exactly match the redirect URI registered in the Spotify Developer Dashboard and the value the client sends (`unforgetty-spotify://callback`). |

`APPWRITE_FUNCTION_API_ENDPOINT` is misconfigured on this self-hosted instance (same issue as
`activity-scheduler`/`social`), so the endpoint is hardcoded in `src/main.js`.
