-- Yomy secure message media + per-user message deletion
-- Additive migration: preserves legacy public message media and all message rows.

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS media_bucket text NOT NULL DEFAULT 'messages';

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS media_path text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'messages_private_media_path_check'
  ) THEN
    ALTER TABLE public.messages
      ADD CONSTRAINT messages_private_media_path_check
      CHECK (
        media_bucket <> 'messages-private'
        OR (
          media_path IS NOT NULL
          AND media_path LIKE 'images/' || sender_id::text || '/%'
          OR media_path LIKE 'videos/' || sender_id::text || '/%'
          OR media_path LIKE 'audio/' || sender_id::text || '/%'
        )
      );
  END IF;
END $$;

INSERT INTO storage.buckets (id, name, public)
VALUES ('messages-private', 'messages-private', false)
ON CONFLICT (id) DO UPDATE SET public = false;

DROP POLICY IF EXISTS "Messages private authenticated uploads" ON storage.objects;
CREATE POLICY "Messages private authenticated uploads" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'messages-private'
  AND (storage.foldername(name))[1] IN ('images', 'videos', 'audio')
  AND (storage.foldername(name))[2] = (select auth.uid())::text
);

CREATE TABLE IF NOT EXISTS public.message_user_states (
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  hidden_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS message_user_states_user_idx
  ON public.message_user_states(user_id, hidden_at);

ALTER TABLE public.message_user_states ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS message_user_states_select_owner ON public.message_user_states;
CREATE POLICY message_user_states_select_owner ON public.message_user_states
FOR SELECT TO authenticated
USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS message_user_states_insert_owner ON public.message_user_states;
CREATE POLICY message_user_states_insert_owner ON public.message_user_states
FOR INSERT TO authenticated
WITH CHECK (
  (select auth.uid()) = user_id
  AND EXISTS (
    SELECT 1
    FROM public.messages m
    WHERE m.id = message_id
      AND (select auth.uid()) IN (m.sender_id, m.receiver_id)
  )
);

DROP POLICY IF EXISTS message_user_states_update_owner ON public.message_user_states;
CREATE POLICY message_user_states_update_owner ON public.message_user_states
FOR UPDATE TO authenticated
USING ((select auth.uid()) = user_id)
WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS message_user_states_delete_owner ON public.message_user_states;
CREATE POLICY message_user_states_delete_owner ON public.message_user_states
FOR DELETE TO authenticated
USING ((select auth.uid()) = user_id);

NOTIFY pgrst, 'reload schema';
