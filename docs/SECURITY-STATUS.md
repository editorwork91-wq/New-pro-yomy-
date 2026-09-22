# YOMY Security Status

## Implemented

### Messaging media
New message media uses the private `messages-private` bucket. The client requests short-lived signed URLs from `message-media-url`; it does not turn private objects into public URLs.

### Per-user deletion
Delete-for-me is represented by `message_user_states`, so one participant can hide a message without deleting it for the other participant.

### SQL function exposure
Privileged SQL functions have their default `PUBLIC` execute privileges removed. The Fedo analytics API uses a signed-in public wrapper and an unexposed privileged helper.

### Fedo storage
Fedo video and thumbnail bytes can remain on private storage nodes. Main YOMY keeps auth, metadata, access control, social interactions and analytics while playback is authorized through signed URLs.

## Known external configuration requirements

The following values are intentionally not committed as secrets:

- `SUPABASE_SERVICE_ROLE_KEY`
- `GEMINI_API_KEY`
- `MEDIA_SHARDS_JSON`
- `VAPID_PRIVATE_KEY`
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- TURN credentials

The browser-facing Supabase publishable configuration is already present in `.env`.

## Current hardening notes

Supabase currently reports three non-error security advisories that are environment/configuration related:

1. `pg_net` is installed in `public`; moving it safely requires auditing every dependent SQL call before changing schemas.
2. Password leak protection is disabled in Supabase Auth; enable it from the Supabase Auth security settings before public launch.
3. `push_delivery_diagnostics` is intentionally service-role-only with RLS enabled and no client policies; this is not an application read/write surface.

## Important privacy note

The current messaging implementation is **not true end-to-end encryption**. The previous UI incorrectly labelled messages as encrypted; the new target no longer makes that claim.

WhatsApp-grade E2EE requires a real key-management protocol, per-device keys, secure key verification, encrypted message payloads, encrypted media keys, multi-device recovery, and careful forward-secrecy/replay handling. Those pieces are not claimed as complete here.

## Release gate

Do not call a public release complete until:

- web typecheck/build passes;
- Android debug APK builds;
- native incoming-call flow is tested on physical Android devices;
- FCM and Web Push secrets are configured;
- TURN is configured and calls are tested behind restrictive NAT;
- Fedo upload/playback is tested against the private node;
- Supabase Auth password leak protection is enabled;
- a real-device regression pass covers chat, profile, stories, posts, calls and Fedo.
