-- FUTARI private two-person rooms
-- Run this AFTER the initial schema.sql in Supabase SQL Editor.

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  invite_code text not null unique check (invite_code ~ '^[A-F0-9]{6}$'),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

alter table public.rooms enable row level security;
alter table public.room_members enable row level security;

create or replace function public.is_room_member(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.room_members rm
    where rm.room_id = p_room_id and rm.user_id = auth.uid()
  );
$$;

drop policy if exists "Room members can read their room" on public.rooms;
create policy "Room members can read their room"
  on public.rooms for select
  to authenticated
  using (public.is_room_member(id));

drop policy if exists "Room members can read membership" on public.room_members;
create policy "Room members can read membership"
  on public.room_members for select
  to authenticated
  using (public.is_room_member(room_id));

create or replace function public.create_private_room()
returns table (room_id uuid, invite_code text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_room_id uuid;
  v_code text;
begin
  if v_user_id is null then
    raise exception 'ログインしてください';
  end if;

  if exists (select 1 from public.room_members where user_id = v_user_id) then
    raise exception 'すでにルームに参加しています';
  end if;

  loop
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.rooms where rooms.invite_code = v_code);
  end loop;

  insert into public.rooms (invite_code, created_by)
  values (v_code, v_user_id)
  returning id into v_room_id;

  insert into public.room_members (room_id, user_id)
  values (v_room_id, v_user_id);

  return query select v_room_id, v_code;
end;
$$;

create or replace function public.join_room_by_code(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_room_id uuid;
  v_count integer;
begin
  if v_user_id is null then
    raise exception 'ログインしてください';
  end if;

  if exists (select 1 from public.room_members where user_id = v_user_id) then
    raise exception 'すでに別のルームに参加しています';
  end if;

  select id into v_room_id
  from public.rooms
  where invite_code = upper(trim(p_invite_code))
  for update;

  if v_room_id is null then
    raise exception '招待コードが見つかりません';
  end if;

  select count(*) into v_count
  from public.room_members
  where room_id = v_room_id;

  if v_count >= 2 then
    raise exception 'このルームは満員です';
  end if;

  insert into public.room_members (room_id, user_id)
  values (v_room_id, v_user_id);

  return v_room_id;
end;
$$;

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
    max(p.username) filter (where rm.user_id <> auth.uid())
  from public.room_members mine
  join public.rooms r on r.id = mine.room_id
  join public.room_members rm on rm.room_id = r.id
  left join public.profiles p on p.id = rm.user_id
  where mine.user_id = auth.uid()
  group by r.id, r.invite_code;
$$;

revoke all on function public.is_room_member(uuid) from public, anon;
revoke all on function public.create_private_room() from public, anon;
revoke all on function public.join_room_by_code(text) from public, anon;
revoke all on function public.get_my_room() from public, anon;
grant execute on function public.is_room_member(uuid) to authenticated;
grant execute on function public.create_private_room() to authenticated;
grant execute on function public.join_room_by_code(text) to authenticated;
grant execute on function public.get_my_room() to authenticated;

-- Direct writes to rooms and room_members are intentionally unavailable.
-- Room creation/joining must go through the guarded RPC functions above.
