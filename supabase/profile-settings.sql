-- FUTARI v0.8.0: profile settings
-- Run this entire file in Supabase SQL Editor.

alter table public.profiles
  add column if not exists avatar_emoji text not null default '🐻';

grant select on public.profiles to authenticated;\nrevoke update on public.profiles from authenticated;\ngrant update (display_name, avatar_emoji) on public.profiles to authenticated;

-- Return the partner's display name instead of their login username.
create or replace function public.get_my_room()
returns table (
  room_id uuid,
  invite_code text,
  member_count integer,
  partner_username text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.id,
    r.invite_code,
    count(rm.user_id)::integer,
    max(coalesce(p.display_name, p.username)) filter (where rm.user_id <> auth.uid())
  from public.room_members mine
  join public.rooms r on r.id = mine.room_id
  join public.room_members rm on rm.room_id = r.id
  left join public.profiles p on p.id = rm.user_id
  where mine.user_id = auth.uid()
  group by r.id, r.invite_code;
$$;

revoke all on function public.get_my_room() from public, anon;
grant execute on function public.get_my_room() to authenticated;
