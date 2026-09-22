# YOMY Architecture

## Main application plane

YOMY Main Supabase owns authentication, profiles, follows, posts, stories, messages, reactions, call state/signalling, notifications, creator analytics and access-control decisions.

## Messaging plane

The chat client uses Supabase Realtime for low-latency message updates and a reconciliation fallback when realtime is degraded.

Text messages stay in `public.messages`.

New media messages store:

- `media_bucket = messages-private`
- `media_path = <type>/<user-id>/...`
- no public media URL

The `message-media-url` Edge Function verifies that the caller is one of the message participants and returns a short-lived signed URL.

## Call plane

WebRTC media is peer-to-peer where possible. YOMY stores call session state and signalling in Supabase and uses native Android call UI plus push notifications for incoming calls.

A production TURN service is required for reliable NAT traversal.

## Fedo plane

`fedo-upload-ticket` selects a storage shard and creates a signed upload ticket.

The client performs a resumable upload.

`fedo-finalize` registers shard metadata and creates the main `fedos` record.

`fedo-media-url` verifies visibility and creates short-lived signed playback URLs.

This keeps the browser unaware of shard service-role credentials.

## Notification plane

Application events feed the unified notification layer. Web push is handled by VAPID and native Android delivery by Firebase Cloud Messaging.

Call notifications use data-only high-priority native messages so the native incoming-call activity can own the call screen.

## Recovery

The target repository has a manual recovery workflow that snapshots the target and restores from the source production baseline.

For a clean production reset, restore code first, then restore server secrets and validate database/function versions. Never commit service-role credentials, Firebase service-account JSON, VAPID private keys or TURN secrets.
