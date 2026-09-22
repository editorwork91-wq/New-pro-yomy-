# Yomy Production Recovery

## Baseline

- Source repository: `editorwork91-wq/yomy`
- Source branch: `main`
- Last verified source commit at setup: `b70c670dbe175c08afb05ff85ef34c3c83666a66`
- Target repository: `editorwork91-wq/New-pro-yomy-`
- Source `main` is never modified by the target recovery workflow.

## Application recovery

The target repository contains `.github/workflows/bootstrap-from-yomy.yml`.
Its job is to re-import the complete source tree from the production repository and commit the result to target `main`.

This protects against accidental source damage inside the new repository by rebuilding from the known production baseline instead of applying ad-hoc fixes.

## Media / Fedo architecture

The current production application keeps authentication, Fedo metadata, likes/comments/analytics, and access control in YOMY Main while video and thumbnail bytes can live on private Fedo storage shards.

Fedo playback must use the `fedo-media-url` Edge Function to mint short-lived signed URLs. The browser must not construct a public URL for a private bucket.

The current upload path is:

`fedo-upload-ticket` -> signed resumable upload -> `fedo-finalize` -> main `fedos` metadata + shard `fedo_video_objects`.

## Secret contract

Public/browser configuration can live in `.env` / `VITE_*` variables.

Server-only values must be restored as Supabase Edge Function secrets or CI secrets; do not put service-role keys into `VITE_*` variables.

Known production configuration names include:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GEMINI_API_KEY`
- `GEMINI_MODEL`
- `MEDIA_SHARDS_JSON`
- `VITE_VAPID_PUBLIC_KEY`
- `VITE_TURN_URLS`
- `VITE_TURN_USERNAME`
- `VITE_TURN_CREDENTIAL`

GitHub/Supabase secret values are not copied by this repository bootstrap because secret values are write-only once stored. Restore the same secret names and values in the target environment before production deployment.

## Android recovery

The source build preserves native call notification files and regenerates the Capacitor Android project before restoring the native bridge. The target should keep this regeneration step because it prevents native call UI from being lost on a clean build.

## Verification gate

A production release is not considered ready until:

1. TypeScript/Vite build passes.
2. Capacitor Android project regenerates successfully.
3. Debug APK assembles successfully.
4. The APK artifact is uploaded.
5. Fedo signed playback and resumable upload functions are deployed.
6. Supabase migrations/functions are applied to the intended project.
7. Native Firebase/FCM configuration is available when native call notifications are required.
