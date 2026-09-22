-- Security hardening for exposed SQL functions.
-- The privileged analytics writer is kept behind a signed-in wrapper;
-- trigger-only functions are not executable by client roles.

REVOKE EXECUTE ON FUNCTION public.archive_deleted_fedo(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.record_call_chat_log() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.record_fedo_event(uuid, text, bigint, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_fedo_event(uuid, text, bigint, jsonb) TO authenticated;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.record_fedo_event_impl(
  p_fedo_id uuid,
  p_event_type text,
  p_watch_ms bigint DEFAULT 0,
  p_meta jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  v_owner uuid;
  v_viewer uuid := (select auth.uid());
  v_day date := current_date;
  v_watch_ms bigint := greatest(0, least(coalesce(p_watch_ms, 0), 86400000));
begin
  if v_viewer is null then
    raise exception 'Not authenticated';
  end if;

  if p_event_type not in ('view','complete','like','comment','share','save','subscribe') then
    return;
  end if;

  select user_id into v_owner
  from public.fedos
  where id = p_fedo_id
    and status = 'published';

  if v_owner is null then
    return;
  end if;

  insert into public.fedo_events(fedo_id, viewer_id, event_type, watch_ms, meta)
  values(p_fedo_id, v_viewer, p_event_type, v_watch_ms, coalesce(p_meta, '{}'::jsonb));

  insert into public.content_metrics_daily(
    user_id, content_type, content_id, day,
    views, unique_viewers, completions, watch_ms,
    likes, comments, shares, saves, attributed_subscriptions
  )
  values(
    v_owner, 'fedo', p_fedo_id, v_day,
    case when p_event_type='view' then 1 else 0 end,
    case when p_event_type='view' then 1 else 0 end,
    case when p_event_type='complete' then 1 else 0 end,
    v_watch_ms,
    case when p_event_type='like' then 1 else 0 end,
    case when p_event_type='comment' then 1 else 0 end,
    case when p_event_type='share' then 1 else 0 end,
    case when p_event_type='save' then 1 else 0 end,
    case when p_event_type='subscribe' then 1 else 0 end
  )
  on conflict(content_type, content_id, day) do update set
    views=public.content_metrics_daily.views+excluded.views,
    unique_viewers=public.content_metrics_daily.unique_viewers+excluded.unique_viewers,
    completions=public.content_metrics_daily.completions+excluded.completions,
    watch_ms=public.content_metrics_daily.watch_ms+excluded.watch_ms,
    likes=public.content_metrics_daily.likes+excluded.likes,
    comments=public.content_metrics_daily.comments+excluded.comments,
    shares=public.content_metrics_daily.shares+excluded.shares,
    saves=public.content_metrics_daily.saves+excluded.saves,
    attributed_subscriptions=public.content_metrics_daily.attributed_subscriptions+excluded.attributed_subscriptions;
end;
$function$;

REVOKE ALL ON FUNCTION private.record_fedo_event_impl(uuid,text,bigint,jsonb) FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.record_fedo_event_impl(uuid,text,bigint,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.record_fedo_event(
  p_fedo_id uuid,
  p_event_type text,
  p_watch_ms bigint DEFAULT 0,
  p_meta jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public'
AS $function$
begin
  perform private.record_fedo_event_impl(p_fedo_id,p_event_type,p_watch_ms,p_meta);
end;
$function$;

REVOKE ALL ON FUNCTION public.record_fedo_event(uuid,text,bigint,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_fedo_event(uuid,text,bigint,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_message_delivered(p_message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
begin
  update public.messages
     set delivered_at = coalesce(delivered_at, now())
   where id = p_message_id
     and receiver_id = (select auth.uid())
     and sender_id is distinct from receiver_id;
end;
$function$;

REVOKE ALL ON FUNCTION public.mark_message_delivered(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_message_delivered(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_presence_heartbeat()
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
declare
  v_now timestamptz := now();
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  update public.profiles
     set last_seen_at=v_now
   where id=(select auth.uid());
  return v_now;
end;
$function$;

REVOKE ALL ON FUNCTION public.set_presence_heartbeat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_presence_heartbeat() TO authenticated;

CREATE INDEX IF NOT EXISTS fedo_comments_fedo_id_idx ON public.fedo_comments(fedo_id);
CREATE INDEX IF NOT EXISTS fedo_comments_user_id_idx ON public.fedo_comments(user_id);
CREATE INDEX IF NOT EXISTS fedo_events_viewer_id_idx ON public.fedo_events(viewer_id);
CREATE INDEX IF NOT EXISTS fedo_likes_user_id_idx ON public.fedo_likes(user_id);
CREATE INDEX IF NOT EXISTS fedo_saves_user_id_idx ON public.fedo_saves(user_id);

NOTIFY pgrst, 'reload schema';
