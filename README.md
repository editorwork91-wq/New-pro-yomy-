# YOMY

YOMY is a mobile-first social platform combining social feed, stories, private messaging, voice/video calls, notifications, creator analytics, and the Fedo short-video surface.

## Production baseline

This repository was bootstrapped from:

- Source: `editorwork91-wq/yomy`
- Source baseline: `b70c670dbe175c08afb05ff85ef34c3c83666a66`
- Target: `editorwork91-wq/New-pro-yomy-`

The source repository is treated as the protected production baseline. Target recovery can restore from the source without editing source `main`.

## Core surfaces

- Feed: followed accounts, posts, likes, comments, saves, stories and discovery entry points.
- Profile: followers/following, private profiles, QR sharing, published posts, Fedo reels and saved posts.
- Messaging: text, photos, video, voice recording, reactions, replies, edit, delete-for-me, delete-for-everyone, view-once media, delivery/seen states, mute and block.
- Calls: voice/video WebRTC, ringing/answer/decline/end states, native Android incoming-call UI, call chat log and push delivery.
- Fedo: resumable video uploads, private media nodes, signed playback URLs, thumbnails and analytics events.
- Notifications: web push + native FCM bridge + unified notification/event handling.

## Environment

See `.env.example` for the complete configuration contract.

Browser-safe `VITE_*` settings may be present in the repository. Server-only secrets must be supplied to Supabase Edge Functions and CI secrets and must not be committed.

## Development

```bash
npm ci
npm run typecheck
npm run build
npx cap sync android
cd android
./gradlew assembleDebug
```

## Recovery

See `docs/RECOVERY.md`.

## Architecture

See `docs/ARCHITECTURE.md`.

## Security

See `docs/SECURITY-STATUS.md`.
