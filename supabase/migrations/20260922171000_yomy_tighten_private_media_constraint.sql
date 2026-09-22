-- Tighten the private message media path constraint.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'messages_private_media_path_check'
  ) THEN
    ALTER TABLE public.messages DROP CONSTRAINT messages_private_media_path_check;
  END IF;

  ALTER TABLE public.messages
    ADD CONSTRAINT messages_private_media_path_check
    CHECK (
      media_bucket <> 'messages-private'
      OR (
        media_path IS NOT NULL
        AND (
          media_path LIKE 'images/' || sender_id::text || '/%'
          OR media_path LIKE 'videos/' || sender_id::text || '/%'
          OR media_path LIKE 'audio/' || sender_id::text || '/%'
        )
      )
    );
END $$;

NOTIFY pgrst, 'reload schema';
