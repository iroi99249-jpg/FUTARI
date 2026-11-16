-- FUTARI real-time chat
-- Run after schema.sql and rooms.sql in Supabase SQL Editor.

create table if not exists public.messages (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists messages_room_created_idx
  on public.messages (room_id, created_at);

alter table public.messages enable row level security;

drop policy if exists "Room members can read messages" on public.messages;
create policy "Room members can read messages"
  on public.messages for select
  to authenticated
  using (public.is_room_member(room_id));

drop policy if exists "Room members can send as themselves" on public.messages;
create policy "Room members can send as themselves"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_room_member(room_id)
  );

-- Enable Supabase Realtime for message inserts.
do $$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
  when undefined_object then
    raise notice 'Publication supabase_realtime was not found. Enable Realtime for public.messages in the Dashboard.';
end;
$$;

grant select, insert on public.messages to authenticated;
grant usage, select on sequence public.messages_id_seq to authenticated;
