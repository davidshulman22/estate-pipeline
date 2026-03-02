-- Estate Planning Pipeline - Supabase Schema
-- Run this in the Supabase SQL Editor after creating your project.

-- 1. Matters table
create table public.matters (
  id uuid primary key default gen_random_uuid(),
  client_name text not null,
  stage text not null default 'new_lead',
  notes text default '',
  checklist jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  archived boolean default false,
  user_id uuid not null references auth.users(id) on delete cascade
);

-- 2. Index for fast lookups
create index idx_matters_user_stage on public.matters(user_id, stage);
create index idx_matters_archived on public.matters(user_id, archived);

-- 3. Auto-update updated_at on row change
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger matters_updated_at
  before update on public.matters
  for each row execute function public.set_updated_at();

-- 4. Row Level Security — restrict to single authorized user
alter table public.matters enable row level security;

-- Allow only the authorized user (set YOUR email below)
-- Replace 'davidshulman@gmail.com' if different
create policy "User can read own matters"
  on public.matters for select
  using (
    auth.uid() = user_id
    and (select email from auth.users where id = auth.uid()) = 'davidshulman@gmail.com'
  );

create policy "User can insert own matters"
  on public.matters for insert
  with check (
    auth.uid() = user_id
    and (select email from auth.users where id = auth.uid()) = 'davidshulman@gmail.com'
  );

create policy "User can update own matters"
  on public.matters for update
  using (
    auth.uid() = user_id
    and (select email from auth.users where id = auth.uid()) = 'davidshulman@gmail.com'
  );

create policy "User can delete own matters"
  on public.matters for delete
  using (
    auth.uid() = user_id
    and (select email from auth.users where id = auth.uid()) = 'davidshulman@gmail.com'
  );

-- 5. Stage checklists template table (for future use)
-- Stores default checklist items per stage
create table public.stage_checklists (
  id uuid primary key default gen_random_uuid(),
  stage text not null unique,
  items jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Seed with empty checklists for each stage
insert into public.stage_checklists (stage, items) values
  ('new_lead', '[]'::jsonb),
  ('consultation_scheduled', '[]'::jsonb),
  ('consultation_complete', '[]'::jsonb),
  ('engagement_sent', '[]'::jsonb),
  ('retainer_received', '[]'::jsonb),
  ('drafts_sent', '[]'::jsonb),
  ('revisions_in_progress', '[]'::jsonb),
  ('signing_scheduled', '[]'::jsonb),
  ('signing_complete', '[]'::jsonb),
  ('matter_closed', '[]'::jsonb);

alter table public.stage_checklists enable row level security;

create policy "Authenticated users can read stage checklists"
  on public.stage_checklists for select
  using (auth.role() = 'authenticated');
