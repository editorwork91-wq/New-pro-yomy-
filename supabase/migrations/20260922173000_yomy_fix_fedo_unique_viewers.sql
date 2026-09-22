-- Make Fedo unique-viewer analytics genuinely unique per viewer/day.
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
  v_day_start timestamptz := date_trunc('day', now());
  v_watch_ms bigint := greatest(0, least(coalesce(p_watch_ms, 0), 86400000));
  v_unique_viewer boolean := false;
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

  if p_event_type = 'view' then
    select not exists (
      select 1
      from public.fedo_events
      where fedo_id = p_fedo_id
        and viewer_id = v_viewer
        and event_type = 'view'
        and created_at >= v_day_start
        and created_at < v_day_start + interval '1 day'
    ) into v_unique_viewer;
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
    case when v_unique_viewer then 1 else 0 end,
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

NOTIFY pgrst, 'reload schema';
